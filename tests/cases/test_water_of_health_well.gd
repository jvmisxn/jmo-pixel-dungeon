extends RefCounted
## WaterOfHealth well seeder + effect coverage (SPD parity slice).
##
## Proves the ported WellWater path:
##   1. MagicWellRoom.paint() seeds a `water_of_health` blob on its WELL tile, and
##      WaterOfHealth.seed_well() routes through Level.add_blob so the well joins
##      the shared blob layer (SPD rooms call Blob.seed(level, cell,
##      WaterOfHealth.class) in paint()).
##   2. Standing on the well heals the hero to full and cures the PotionOfHealing
##      ailment set through the blob's own tick/effect path -- no hard-coded
##      terrain heal -- then consumes the well (blob cleared, WELL -> EMPTY_WELL),
##      mirroring SPD WellWater.use() after affectHero() returns true.
##   3. Mobs never trigger or drain the well (SPD WellWater only affects the hero).
##   4. The seeded well blob survives Level serialize/deserialize via the
##      structured blob persistence contract.

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 3
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func _make_hero(pos: int, level: Level) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.pos = pos
	hero.level = level
	return hero

func _has_blob(level: Level, blob_id: String) -> bool:
	return _find_blob(level, blob_id) != null

func _find_blob(level: Level, blob_id: String) -> Blob:
	for entry: Dictionary in level.blobs:
		var blob: Variant = entry.get("blob")
		if blob != null and str(blob.get("blob_id")) == blob_id:
			return blob as Blob
	return null

func run(t: Object) -> void:
	_test_room_paint_seeds_well(t)
	_test_well_heals_and_consumes(t)
	_test_one_well_use_preserves_other_wells(t)
	_test_mob_does_not_drain_well(t)
	_test_well_survives_serialization(t)

## MagicWellRoom.paint() lays a WELL tile and seeds WaterOfHealth on it.
func _test_room_paint_seeds_well(t: Object) -> void:
	var level: Level = _make_level()
	var room := MagicWellRoom.new()
	room.left = 4
	room.top = 4
	room.right = 10
	room.bottom = 10
	room.paint(level)

	var well_cell: int = room.center()
	t.check(level.terrain_at(well_cell) == ConstantsData.Terrain.WELL,
			"magic well room paints a WELL tile at its centre")
	t.check(_has_blob(level, "water_of_health"),
			"magic well room seeds a water_of_health blob")
	var blob: Blob = _find_blob(level, "water_of_health")
	t.check(blob != null and blob.pos == well_cell,
			"seeded well blob is anchored on the well cell")
	t.check(blob != null and blob.is_active_at(well_cell),
			"seeded well blob holds density on the well cell")

## The blob heals the hero to full, cures ailments, and consumes the well.
func _test_well_heals_and_consumes(t: Object) -> void:
	var level: Level = _make_level()
	var well_cell: int = ConstantsData.xy_to_pos(16, 16)
	level.set_terrain(well_cell, ConstantsData.Terrain.WELL)
	WaterOfHealth.seed_well(level, well_cell)

	var hero: Hero = _make_hero(well_cell, level)
	hero.hp_max = 30
	hero.ht = 30
	hero.hp = 8
	hero.add_buff(Poison.new())
	level.add_mob(hero)

	t.check(hero.hp == 8 and hero.has_buff("Poison"),
			"seeding alone does not heal or cure the hero")

	level.tick_blobs()

	t.check(hero.hp == hero.hp_max,
			"standing in the well heals the hero to full through the blob tick")
	t.check(not hero.has_buff("Poison"),
			"the well cures the PotionOfHealing ailment set (poison)")
	t.check(level.terrain_at(well_cell) == ConstantsData.Terrain.EMPTY_WELL,
			"a used well becomes EMPTY_WELL")
	# Consuming clears the blob's cells, so the same tick drops it from the layer.
	t.check(not _has_blob(level, "water_of_health"),
			"a consumed well removes its blob from the level")

	hero.free()

## Multiple health wells share one blob type; using one cell must not drain all.
func _test_one_well_use_preserves_other_wells(t: Object) -> void:
	var level: Level = _make_level()
	var first: int = ConstantsData.xy_to_pos(14, 14)
	var second: int = ConstantsData.xy_to_pos(18, 18)
	level.set_terrain(first, ConstantsData.Terrain.WELL)
	level.set_terrain(second, ConstantsData.Terrain.WELL)
	WaterOfHealth.seed_well(level, first)
	WaterOfHealth.seed_well(level, second)

	var hero: Hero = _make_hero(first, level)
	hero.hp_max = 30
	hero.ht = 30
	hero.hp = 10
	level.add_mob(hero)

	level.tick_blobs()

	t.check(level.terrain_at(first) == ConstantsData.Terrain.EMPTY_WELL,
			"using one health well empties that well")
	t.check(level.terrain_at(second) == ConstantsData.Terrain.WELL,
			"using one health well leaves other well tiles intact")
	var blob: Blob = _find_blob(level, "water_of_health")
	t.check(blob != null and not blob.is_active_at(first),
			"used well cell is removed from the shared blob")
	t.check(blob != null and blob.is_active_at(second),
			"unused well cell remains active in the shared blob")

	hero.free()

## Mobs standing on the well neither heal nor drain it (SPD affects hero only).
func _test_mob_does_not_drain_well(t: Object) -> void:
	var level: Level = _make_level()
	var well_cell: int = ConstantsData.xy_to_pos(20, 20)
	level.set_terrain(well_cell, ConstantsData.Terrain.WELL)
	WaterOfHealth.seed_well(level, well_cell)

	var mob := Char.new()
	mob.pos = well_cell
	mob.level = level
	mob.hp_max = 20
	mob.ht = 20
	mob.hp = 5
	level.add_mob(mob)

	level.tick_blobs()

	t.check(mob.hp == 5,
			"a mob standing in the well is not healed")
	t.check(_has_blob(level, "water_of_health"),
			"a mob does not consume the well")
	t.check(level.terrain_at(well_cell) == ConstantsData.Terrain.WELL,
			"the well tile stays a WELL when only a mob stands on it")

	mob.free()

## The unused well blob round-trips through Level save/load as a live,
## correctly-typed WaterOfHealth still anchored on its cell.
func _test_well_survives_serialization(t: Object) -> void:
	var level: Level = _make_level()
	var well_cell: int = ConstantsData.xy_to_pos(12, 8)
	level.set_terrain(well_cell, ConstantsData.Terrain.WELL)
	WaterOfHealth.seed_well(level, well_cell)

	var data: Dictionary = level.serialize()
	var restored := Level.new()
	restored.deserialize(data)

	var blob: Blob = _find_blob(restored, "water_of_health")
	t.check(blob is WaterOfHealth,
			"a saved well reloads as a WaterOfHealth instance")
	t.check(blob != null and blob.pos == well_cell,
			"the reloaded well keeps its cell")
	t.check(blob != null and blob.is_active_at(well_cell),
			"the reloaded well keeps its density and stays active")
	t.check(blob != null and blob.spread_rate == 0.0 and blob.decay_rate == 0.0,
			"the reloaded well keeps its non-spreading, non-decaying tuning")
