extends RefCounted
## Smoke Bomb seeder coverage (SPD parity slice).
##
## Wires the already-ported SmokeScreen blob to its canonical source, SPD's
## alchemical SmokeBomb. Proves the four halves of that source path:
##   1. Bomb.create("smoke_bomb") / Generator.create_item("smoke_bomb") build a
##      radius-2 SMOKE bomb -- SPD SmokeBomb overrides explosionRange() -> 2.
##   2. Detonation seeds a single smoke_screen blob across the radius-2 footprint
##      at 40 volume/cell, mirroring SPD SmokeBomb.explode()'s
##      `Blob.seed(i, 40, SmokeScreen.class)` over buildDistanceMap(cell, ..., 2).
##   3. That seeded smoke blocks line of sight through Level.update_fov()'s smoke
##      branch (the LOS path the blob already owns).
##   4. The bomb subtype (SMOKE + radius 2) survives a serialize/deserialize
##      round-trip.
##
## Source fidelity note: SPD SmokeBomb.explode() calls super.explode() before
## seeding smoke, so the standard bomb blast damage + terrain destruction is
## RETAINED here (damage_min/max 10/30, matching the port's normal bomb). The
## smoke is additive, not a harmless replacement.

func _make_level() -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.build_flag_maps()
	# update_fov() consults GameManager.hero for Shadows/Warden LOS tweaks; clear
	# any leftover hero so the only LOS modifier is the smoke seeded here.
	if GameManager:
		GameManager.hero = null
	return level

func run(t: Object) -> void:
	_test_factory_builds_smoke_bomb(t)
	_test_generator_dispatches_smoke_bomb(t)
	_test_detonation_seeds_smoke_footprint(t)
	_test_seeded_smoke_blocks_los(t)
	_test_serialization_round_trip(t)

## Bomb.create returns a radius-2 SMOKE bomb.
func _test_factory_builds_smoke_bomb(t: Object) -> void:
	var bomb: Bomb = Bomb.create("smoke_bomb")
	t.check(bomb != null, "Bomb.create('smoke_bomb') returns a Bomb")
	t.check(bomb.item_id == "smoke_bomb", "smoke bomb keeps item_id smoke_bomb")
	t.check(bomb.bomb_type == Bomb.BombType.SMOKE, "smoke bomb has BombType.SMOKE")
	t.check(bomb.radius == 2, "smoke bomb blasts at radius 2 (SPD explosionRange)")

## Generator's known-ID dispatch routes smoke_bomb to Bomb.create.
func _test_generator_dispatches_smoke_bomb(t: Object) -> void:
	var item: Item = Generator.create_item("smoke_bomb")
	t.check(item is Bomb, "Generator.create_item('smoke_bomb') builds a Bomb")
	if item is Bomb:
		t.check((item as Bomb).bomb_type == Bomb.BombType.SMOKE,
				"generator-built smoke bomb is BombType.SMOKE")

## Detonation seeds one smoke_screen blob over the radius-2 footprint at 40/cell.
func _test_detonation_seeds_smoke_footprint(t: Object) -> void:
	var level: Level = _make_level()
	var center: int = ConstantsData.xy_to_pos(16, 16)   # well inside bounds -> full 5x5
	var bomb: Bomb = Bomb.create("smoke_bomb")
	bomb.detonate(center, level)

	var smoke: SmokeScreen = _find_smoke(level)
	t.check(smoke != null, "detonation seeds a smoke_screen blob")
	if smoke == null:
		return
	# add_blob merges by blob_id, so the whole radius-2 blast is ONE blob.
	var smoke_blobs: int = 0
	for entry: Dictionary in level.blobs:
		if entry.get("blob") is SmokeScreen:
			smoke_blobs += 1
	t.check(smoke_blobs == 1, "all seeded cells merge into a single smoke_screen blob")
	# Chebyshev radius 2 over open ground = 5x5 = 25 cells (SPD's 40*25 budget).
	t.check(smoke.active_cells.size() == 25,
			"smoke covers the full 25-cell radius-2 footprint (got %d)" % smoke.active_cells.size())
	t.check(is_equal_approx(smoke.get_density(center), Bomb.SMOKE_SEED_VOLUME),
			"center cell seeded at the caller-intended 40 volume (got %f)" % smoke.get_density(center))
	var edge: int = ConstantsData.xy_to_pos(18, 18)  # corner of the 5x5 blast
	t.check(is_equal_approx(smoke.get_density(edge), Bomb.SMOKE_SEED_VOLUME),
			"footprint edge cell also seeded at 40 volume (got %f)" % smoke.get_density(edge))

## The smoke seeded by a detonation blocks LOS through the SmokeScreen FOV path.
func _test_seeded_smoke_blocks_los(t: Object) -> void:
	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(16, 16)
	var behind: int = ConstantsData.xy_to_pos(16, 9)     # 7 north, inside view
	var blast_center: int = ConstantsData.xy_to_pos(16, 12)  # smoke spans y 10..14

	level.update_fov(hero_pos)
	t.check(level.visible[behind],
			"cell 7 tiles north is visible across open ground before the bomb")

	var bomb: Bomb = Bomb.create("smoke_bomb")
	bomb.detonate(blast_center, level)
	level.update_fov(hero_pos)
	t.check(not level.visible[behind],
			"detonated smoke blocks LOS to the cell behind the cloud")

## The SMOKE subtype + radius survive a bomb serialize/deserialize round-trip.
func _test_serialization_round_trip(t: Object) -> void:
	var bomb: Bomb = Bomb.create("smoke_bomb")
	var data: Dictionary = bomb.serialize()
	var restored := Bomb.new()
	restored.deserialize(data)
	t.check(restored.bomb_type == Bomb.BombType.SMOKE,
			"restored bomb keeps BombType.SMOKE")
	t.check(restored.radius == 2, "restored smoke bomb keeps radius 2")

func _find_smoke(level: Level) -> SmokeScreen:
	for entry: Dictionary in level.blobs:
		var b: Variant = entry.get("blob")
		if b is SmokeScreen:
			return b as SmokeScreen
	return null
