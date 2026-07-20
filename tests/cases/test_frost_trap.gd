extends RefCounted
## Coverage for FrostTrap seeding a lasting Freezing blob, mirroring Shattered
## Pixel Dungeon's FrostTrap (radius-2 Freezing flood-fill).
##
## The trap no longer deals a one-shot hit: it seeds Freezing over its radius-2
## footprint and the blob freezes characters + hardens water as it rides the
## shared blob timeline.

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
	for entry: Dictionary in level.blobs:
		var blob: Variant = entry.get("blob")
		if blob != null and str(blob.get("blob_id")) == blob_id:
			return true
	return false

func run(t: Object) -> void:
	seed(0xF305)

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

	# Water inside the radius-2 footprint should harden once the vapor lands.
	var water_cell: int = hero_pos - Level.W
	level.set_terrain(water_cell, ConstantsData.Terrain.WATER)

	var trap := FrostTrap.new()
	trap.set_pos(hero_pos)
	trap.activate(hero, level)

	t.check(_has_blob(level, "freezing"), "frost trap seeds a lasting Freezing blob")
	t.check(not hero.has_buff("Frozen"), "frost trap waits for the blob tick before freezing")
	t.check(hero.hp == 999, "frost trap deals no one-shot direct damage")
	t.check(not trap.active, "frost trap remains one-shot after activation")

	# One blob step: the hero freezes and the water tile hardens.
	level.tick_blobs()
	t.check(hero.has_buff("Frozen"), "frost trap's Freezing blob freezes the triggerer")
	t.check(
		level.terrain_at(water_cell) == ConstantsData.Terrain.EMPTY,
		"frost trap's Freezing blob hardens water in its footprint"
	)

	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.current_level = original_level
	hero.free()
