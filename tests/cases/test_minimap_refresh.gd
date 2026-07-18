extends RefCounted

func run(t: Object) -> void:
	var previous_level: Variant = GameManager.current_level
	var previous_hero: Node = GameManager.hero
	var previous_heroes: Array[Node] = GameManager.heroes.duplicate()
	var previous_local_hero_index: int = GameManager.local_hero_index

	var level := Level.new()
	level.map.fill(ConstantsData.Terrain.WALL)
	level.map[42] = ConstantsData.Terrain.EMPTY
	level.visited[42] = true
	level.visible[42] = true
	GameManager.current_level = level

	var hero := Hero.new()
	hero.pos = 42
	GameManager.hero = hero
	GameManager.heroes = [hero]
	GameManager.local_hero_index = 0

	var minimap := Minimap.new()
	t.root.add_child(minimap)
	minimap.update_map([], [], [], -1)
	minimap._on_level_changed(1)

	t.check(
		minimap.get("_level_map").size() == Level.LEN,
		"minimap level_changed repopulates terrain from the active level"
	)
	t.check(
		minimap.get("_visible_cells").size() == Level.LEN and minimap.get("_visible_cells")[42],
		"minimap level_changed keeps current FOV visible"
	)
	t.check(
		int(minimap.get("_hero_pos")) == 42,
		"minimap level_changed places the focused hero"
	)

	minimap.free()
	hero.free()
	GameManager.current_level = previous_level
	GameManager.hero = previous_hero
	GameManager.heroes = previous_heroes
	GameManager.local_hero_index = previous_local_hero_index
