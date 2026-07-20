extends RefCounted
## SmokeScreen blob coverage (SPD parity slice).
##
## Proves the three faithful halves of the ported SmokeScreen:
##   1. It is a bare Blob subclass -- a character standing in smoke and ticked
##      gains NO buffs, mirroring SPD SmokeScreen having no evolve()/effect.
##   2. Its cells block line of sight through Level.update_fov()'s smoke branch,
##      and the WHOLE spread footprint (every active cell) blocks -- not just the
##      blob entry's representative pos -- matching SPD's `cur[i] > 0` scan.
##   3. It round-trips through the structured Level blob persistence path,
##      rebuilding as a live SmokeScreen with its densities intact.

## Minimal Level stand-in for the no-effect check: every cell passable, one char.
class StubLevel:
	extends RefCounted
	var _char: Char = null
	var _char_cell: int = -1
	func is_passable(_pos: int) -> bool:
		return true
	func find_char_at(cell: int) -> Variant:
		return _char if cell == _char_cell else null

func _make_level() -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.build_flag_maps()
	# update_fov() consults GameManager.hero for Shadows/Warden LOS tweaks. A hero
	# left over from another test could carry Shadows (blinding the FOV) or WARDEN
	# (see-through-grass), skewing these open-ground assertions -- clear it so the
	# only LOS modifier in play is the smoke under test.
	if GameManager:
		GameManager.hero = null
	return level

func run(t: Object) -> void:
	_test_no_character_effects(t)
	_test_smoke_blocks_los(t)
	_test_full_footprint_blocks_los(t)
	_test_level_round_trip(t)

## SmokeScreen applies nothing to a character standing in it (LOS-only blob).
func _test_no_character_effects(t: Object) -> void:
	var cell: int = ConstantsData.xy_to_pos(16, 16)
	var victim := Char.new()
	victim.pos = cell
	var stub: StubLevel = StubLevel.new()
	stub._char = victim
	stub._char_cell = cell

	var smoke := SmokeScreen.new()
	smoke.level = stub
	smoke.seed(cell, 5.0)
	smoke.tick()

	t.check(smoke.blob_id == "smoke_screen", "SmokeScreen carries blob_id smoke_screen")
	t.check(victim.get_buffs().is_empty(),
			"SmokeScreen applies no buffs to a character standing in it")
	victim.free()

## A smoke cell hides a cell directly behind it from the hero's FOV.
func _test_smoke_blocks_los(t: Object) -> void:
	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(16, 16)
	var behind: int = ConstantsData.xy_to_pos(16, 10)   # 6 north, inside view
	var smoke_cell: int = ConstantsData.xy_to_pos(16, 13)  # between hero + behind

	level.update_fov(hero_pos)
	t.check(level.visible[behind],
			"cell 6 tiles north is visible across open ground before smoke")

	level.add_blob(SmokeScreen.new(), smoke_cell, 5.0)
	level.update_fov(hero_pos)
	t.check(not level.visible[behind],
			"smoke cell blocks LOS to the cell directly behind it")
	t.check(level.visible[smoke_cell],
			"the smoke cell itself is still visible (blocker is seen, not hidden)")

## The blob's entire spread footprint blocks, not just its stored `pos` cell.
## Seeding a second, non-first cell and confirming the cell behind IT is hidden
## proves update_fov walks active_cells rather than the entry's representative
## pos (which stays pinned to the first-seeded cell).
func _test_full_footprint_blocks_los(t: Object) -> void:
	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(16, 16)
	var behind_west: int = ConstantsData.xy_to_pos(10, 16)   # 6 west, inside view
	var first_cell: int = ConstantsData.xy_to_pos(16, 13)    # becomes entry.pos
	var second_cell: int = ConstantsData.xy_to_pos(13, 16)   # west blocker

	level.update_fov(hero_pos)
	t.check(level.visible[behind_west],
			"cell 6 tiles west is visible across open ground before smoke")

	# Both seeds merge into ONE smoke blob (Level.add_blob merges by blob_id);
	# entry["pos"] is pinned to first_cell, so second_cell only blocks if the FOV
	# pass iterates the blob's whole active_cells footprint.
	var smoke := SmokeScreen.new()
	level.add_blob(smoke, first_cell, 5.0)
	level.add_blob(smoke, second_cell, 5.0)
	level.update_fov(hero_pos)
	t.check(not level.visible[behind_west],
			"a non-first active smoke cell also blocks LOS (whole footprint shrouds)")

## Structured Level persistence rebuilds the smoke blob as a live SmokeScreen.
func _test_level_round_trip(t: Object) -> void:
	var level: Level = _make_level()
	var smoke_cell: int = ConstantsData.xy_to_pos(20, 20)
	level.add_blob(SmokeScreen.new(), smoke_cell, 4.0)

	var data: Dictionary = level.serialize()
	var restored := Level.new()
	restored.deserialize(data)

	var found: SmokeScreen = null
	for entry: Dictionary in restored.blobs:
		var b: Variant = entry.get("blob")
		if b is SmokeScreen:
			found = b as SmokeScreen
			break
	t.check(found != null, "smoke_screen blob survives Level serialize/deserialize as a SmokeScreen")
	if found != null:
		t.check(found.blob_id == "smoke_screen", "restored blob keeps blob_id smoke_screen")
		t.check(found.get_density(smoke_cell) > 0.0, "restored smoke retains density at its seeded cell")
