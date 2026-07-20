extends RefCounted
## Firebloom and Icecap should leave a lasting blob on the shared timeline in
## addition to their immediate effect, mirroring Shattered Pixel Dungeon (which
## seeds Fire / Freezing blobs). The immediate AoE is preserved for parity with
## the existing plant behaviour and the edge-wrap regression guard.

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
	hero.hp = 999
	hero.hp_max = 999
	hero.ht = 999
	return hero

func _has_blob(level: Level, blob_id: String) -> bool:
	for entry: Dictionary in level.blobs:
		var blob: Variant = entry.get("blob")
		if blob != null and str(blob.get("blob_id")) == blob_id:
			return true
	return false

func run(t: Object) -> void:
	var original_hero: Node = GameManager.hero
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_level: Level = GameManager.current_level

	_test_firebloom(t)
	_test_icecap(t)

	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.current_level = original_level

func _test_firebloom(t: Object) -> void:
	var level: Level = _make_level()
	var pos: int = ConstantsData.xy_to_pos(10, 10)
	var hero: Hero = _make_hero(pos, level)
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = level
	GameManager.add_hero(hero)

	var grass_cell: int = pos - Level.W
	level.set_terrain(grass_cell, ConstantsData.Terrain.HIGH_GRASS)

	var firebloom := Firebloom.new()
	firebloom.pos = pos
	firebloom._do_effect(hero, level)

	t.check(_has_blob(level, "fire"), "Firebloom seeds a lasting Fire blob")
	t.check(hero.has_buff("Burning"), "Firebloom still burns the triggerer immediately")
	t.check(
		level.terrain_at(grass_cell) == ConstantsData.Terrain.EMBERS,
		"Firebloom still ignites adjacent high grass"
	)

	hero.free()

func _test_icecap(t: Object) -> void:
	var level: Level = _make_level()
	var pos: int = ConstantsData.xy_to_pos(12, 12)
	var hero: Hero = _make_hero(pos, level)
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = level
	GameManager.add_hero(hero)

	var icecap := Icecap.new()
	icecap.pos = pos
	icecap._do_effect(hero, level)

	t.check(_has_blob(level, "freezing"), "Icecap seeds a lasting Freezing blob")
	t.check(hero.has_buff("Frozen"), "Icecap still freezes a character in range immediately")

	hero.free()
