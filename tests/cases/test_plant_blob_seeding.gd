extends RefCounted
## Firebloom and Icecap plant parity with Shattered Pixel Dungeon.
##
## Firebloom is a PURE Fire-blob seeder: it seeds Fire at its cell and the Fire
## blob (not the plant) applies Burning / burns terrain on the shared blob
## timeline — the plant itself never applies a one-shot burn or ignites grass.
##
## Icecap is the OPPOSITE: it applies an IMMEDIATE freeze over its 3x3 footprint
## via SPD's legacy `Freezing.affect` and leaves NO lasting Freezing gas cloud.
##
## A Warden hero converts each plant into a short offensive imbue boon instead of
## being harmed (Firebloom -> FireImbue, Icecap -> FrostImbue + no self-freeze).

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
	_test_firebloom_warden(t)
	_test_icecap(t)
	_test_icecap_warden(t)
	_test_icecap_skips_solid_cells(t)

	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.current_level = original_level

func _install_hero(hero: Hero, level: Level) -> void:
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = level
	GameManager.add_hero(hero)

func _test_firebloom(t: Object) -> void:
	var level: Level = _make_level()
	var pos: int = ConstantsData.xy_to_pos(10, 10)
	var hero: Hero = _make_hero(pos, level)
	_install_hero(hero, level)

	var grass_cell: int = pos - Level.W
	level.set_terrain(grass_cell, ConstantsData.Terrain.HIGH_GRASS)

	var firebloom := Firebloom.new()
	firebloom.pos = pos
	firebloom._do_effect(hero, level)

	# Pure blob seeder: seeds Fire, applies NO immediate burn or grass ignition.
	t.check(_has_blob(level, "fire"), "Firebloom seeds a lasting Fire blob")
	t.check(not hero.has_buff("Burning"), "Firebloom does not immediately burn the triggerer (the Fire blob does)")
	t.check(
		level.terrain_at(grass_cell) == ConstantsData.Terrain.HIGH_GRASS,
		"Firebloom does not immediately ignite adjacent grass (the Fire blob does on tick)"
	)

	# The seeded Fire blob is what burns the character standing in it on its tick.
	level.tick_blobs()
	t.check(hero.has_buff("Burning"), "The seeded Fire blob burns the hero on the next blob tick")

	hero.free()

func _test_firebloom_warden(t: Object) -> void:
	var level: Level = _make_level()
	var pos: int = ConstantsData.xy_to_pos(14, 14)
	var hero: Hero = _make_hero(pos, level)
	hero.hero_subclass = ConstantsData.HeroSubclass.WARDEN
	_install_hero(hero, level)

	var firebloom := Firebloom.new()
	firebloom.pos = pos
	firebloom._do_effect(hero, level)

	t.check(hero.has_buff("FireImbue"), "Firebloom grants a Warden Fire Imbue")
	t.check(_has_blob(level, "fire"), "Firebloom still seeds Fire for a Warden")

	hero.free()

func _test_icecap(t: Object) -> void:
	var level: Level = _make_level()
	var pos: int = ConstantsData.xy_to_pos(12, 12)
	var hero: Hero = _make_hero(pos, level)
	_install_hero(hero, level)

	var icecap := Icecap.new()
	icecap.pos = pos
	icecap._do_effect(hero, level)

	# Immediate freeze, NO lasting gas cloud (SPD legacy Freezing.affect).
	t.check(hero.has_buff("Frozen"), "Icecap immediately freezes a character in range")
	t.check(not _has_blob(level, "freezing"), "Icecap leaves no lasting Freezing blob")

	hero.free()

func _test_icecap_warden(t: Object) -> void:
	var level: Level = _make_level()
	var pos: int = ConstantsData.xy_to_pos(16, 16)
	var hero: Hero = _make_hero(pos, level)
	hero.hero_subclass = ConstantsData.HeroSubclass.WARDEN
	_install_hero(hero, level)

	var icecap := Icecap.new()
	icecap.pos = pos
	icecap._do_effect(hero, level)

	t.check(hero.has_buff("FrostImbue"), "Icecap grants a Warden Frost Imbue")
	t.check(not hero.has_buff("Frozen"), "Icecap does not freeze the Warden it just imbued")

	hero.free()

func _test_icecap_skips_solid_cells(t: Object) -> void:
	var level: Level = _make_level()
	var pos: int = ConstantsData.xy_to_pos(18, 18)
	var wall_cell: int = pos + 1
	var hero: Hero = _make_hero(wall_cell, level)
	_install_hero(hero, level)
	level.set_terrain(wall_cell, ConstantsData.Terrain.WALL)

	var icecap := Icecap.new()
	icecap.pos = pos
	icecap._do_effect(null, level)

	t.check(not hero.has_buff("Frozen"), "Icecap does not freeze a character behind solid terrain")

	hero.free()
