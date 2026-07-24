extends RefCounted
## Huntress Nature's Aid talent: any plant triggering within a hero's sight
## grants Barkskin level 2 for 3/5 turns (upstream Plant.trigger() +
## Barkskin.conditionallyAppend(hero, 2, 1 + 2*points)).

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 3
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func _make_huntress(points: int, pos: int, level: Level) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	hero.pos = pos
	hero.level = level
	hero.hp = 30
	hero.hp_max = 30
	hero.ht = 30
	if points > 0:
		hero.talent_levels["huntress_natures_aid"] = points
	return hero

func _trigger_plant(level: Level, plant_pos: int, triggering_char: Variant = null) -> void:
	var plant := Plant.new()
	plant.pos = plant_pos
	level.plants[plant_pos] = plant
	plant.activate(triggering_char, level)

func _hero_barkskin(hero: Hero) -> Barkskin:
	return hero.get_buff("Barkskin") as Barkskin

func run(t: Object) -> void:
	var original_hero: Node = GameManager.hero
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_level: Level = GameManager.current_level

	var level: Level = _make_level()
	var plant_pos: int = ConstantsData.xy_to_pos(10, 10)
	var hero: Hero = _make_huntress(2, ConstantsData.xy_to_pos(11, 10), level)
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = level
	GameManager.add_hero(hero)

	# Visible plant + 2 talent points -> barkskin 2 with interval 5.
	level.visible[plant_pos] = true
	_trigger_plant(level, plant_pos)
	var bark: Barkskin = _hero_barkskin(hero)
	t.check(bark != null, "visible plant trigger grants barkskin with the talent")
	t.check(bark != null and bark.level == 2, "Nature's Aid barkskin is level 2")
	t.check(bark != null and bark.interval == 5, "two points give a 5-turn interval")

	# One talent point -> interval 3, and a mob-triggered plant still counts.
	var one_point: Hero = _make_huntress(1, ConstantsData.xy_to_pos(12, 10), level)
	GameManager.add_hero(one_point)
	var mob := Char.new()
	mob.pos = plant_pos
	_trigger_plant(level, plant_pos, mob)
	var one_bark: Barkskin = _hero_barkskin(one_point)
	t.check(one_bark != null and one_bark.interval == 3, "one point gives a 3-turn interval")
	mob.free()

	# Plant outside the visible set grants nothing.
	var hidden_hero: Hero = _make_huntress(2, ConstantsData.xy_to_pos(13, 10), level)
	GameManager.heroes.clear()
	GameManager.add_hero(hidden_hero)
	var hidden_pos: int = ConstantsData.xy_to_pos(30, 30)
	level.visible[hidden_pos] = false
	_trigger_plant(level, hidden_pos)
	t.check(_hero_barkskin(hidden_hero) == null, "unseen plant trigger grants no barkskin")

	# No talent points -> no barkskin even when visible.
	var untalented: Hero = _make_huntress(0, ConstantsData.xy_to_pos(14, 10), level)
	GameManager.heroes.clear()
	GameManager.add_hero(untalented)
	level.visible[plant_pos] = true
	_trigger_plant(level, plant_pos)
	t.check(_hero_barkskin(untalented) == null, "no talent points means no barkskin")

	hero.free()
	one_point.free()
	hidden_hero.free()
	untalented.free()
	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.current_level = original_level
