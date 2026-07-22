extends RefCounted
## Coverage for FireTrap seeding a lasting Fire blob, mirroring Shattered Pixel
## Dungeon's BurningTrap.
##
## The trap no longer deals a one-shot hit: it seeds Fire over its 3x3 footprint
## and the blob applies Burning + converts flammable terrain as it rides the
## shared blob timeline (Level.advance_blobs / tick_blobs).

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 7
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
	hero.hp = 999
	hero.hp_max = 999
	hero.ht = 999
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
	seed(0xF17E)

	var original_hero: Node = GameManager.hero
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_level: Level = GameManager.current_level

	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(10, 10)
	var hero: Hero = _make_hero(hero_pos, level)
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = level
	GameManager.add_hero(hero)

	# A flammable neighbour the seeded Fire should later convert to embers.
	var north_cell: int = hero_pos - Level.W
	level.set_terrain(north_cell, ConstantsData.Terrain.HIGH_GRASS)

	var trap := FireTrap.new()
	trap.set_pos(hero_pos)
	trap.activate(hero, level)

	t.check(_has_blob(level, "fire"), "fire trap seeds a lasting Fire blob")
	t.check(not hero.has_buff("Burning"), "fire trap waits for the blob tick before burning")
	t.check(hero.hp == 999, "fire trap deals no one-shot direct damage")
	t.check(not trap.active, "fire trap remains one-shot after activation")

	# One blob step: the hero standing in the fire ignites, grass turns to embers.
	level.tick_blobs()
	var burning: Burning = hero.get_buff("Burning") as Burning
	t.check(burning != null, "fire trap's Fire blob sets the triggerer on fire")
	t.check(
		level.terrain_at(north_cell) == ConstantsData.Terrain.EMBERS,
		"fire trap's Fire blob converts adjacent flammable terrain to embers"
	)

	# The Burning buff then burns down on its own timer.
	hero.process_buffs()
	t.check(hero.hp < 999, "fire trap Burning deals lingering fire damage")

	var blazing_level: Level = _make_level()
	var blazing_pos: int = ConstantsData.xy_to_pos(16, 16)
	var blazing_hero: Hero = _make_hero(blazing_pos, blazing_level)
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = blazing_level
	GameManager.add_hero(blazing_hero)

	var radius_two_cell: int = blazing_pos + 2
	var water_cell: int = blazing_pos + Level.W
	var chasm_cell: int = blazing_pos + Level.W * 2
	var wall_cell: int = blazing_pos - 2
	blazing_level.set_terrain(radius_two_cell, ConstantsData.Terrain.HIGH_GRASS)
	blazing_level.set_terrain(water_cell, ConstantsData.Terrain.WATER)
	blazing_level.set_terrain(chasm_cell, ConstantsData.Terrain.CHASM)
	blazing_level.set_terrain(wall_cell, ConstantsData.Terrain.WALL)

	var blazing := BlazingTrap.new()
	blazing.set_pos(blazing_pos)
	blazing.activate(blazing_hero, blazing_level)
	var fire: FireBlob = _find_blob(blazing_level, "fire") as FireBlob

	t.check(fire != null, "blazing trap seeds a lasting Fire blob")
	t.check(is_equal_approx(fire.get_density(blazing_pos), BlazingTrap.FIRE_AMOUNT),
			"blazing trap seeds strong fire on normal cells")
	t.check(is_equal_approx(fire.get_density(water_cell), BlazingTrap.WATER_OR_PIT_FIRE_AMOUNT),
			"blazing trap seeds weak fire on water cells")
	t.check(is_equal_approx(fire.get_density(chasm_cell), BlazingTrap.WATER_OR_PIT_FIRE_AMOUNT),
			"blazing trap seeds weak fire on chasm/pit cells")
	t.check(is_equal_approx(fire.get_density(radius_two_cell), BlazingTrap.FIRE_AMOUNT),
			"blazing trap reaches the upstream radius-2 footprint")
	t.check(is_zero_approx(fire.get_density(wall_cell)),
			"blazing trap skips solid cells in its radius-2 footprint")
	t.check(not blazing_hero.has_buff("Burning"), "blazing trap waits for the blob tick before burning")
	t.check(blazing_hero.hp == 999, "blazing trap deals no one-shot direct damage")

	blazing_level.tick_blobs()
	t.check(blazing_hero.has_buff("Burning"), "blazing trap's Fire blob burns the triggerer on tick")
	t.check(blazing_level.terrain_at(radius_two_cell) == ConstantsData.Terrain.EMBERS,
			"blazing trap's Fire blob ignites flammable radius-2 terrain")

	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.current_level = original_level
	hero.free()
	blazing_hero.free()
