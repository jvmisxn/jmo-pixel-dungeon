extends RefCounted

func _make_level() -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.build_flag_maps()
	return level

func _make_hero(pos: int, level: Level) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.pos = pos
	hero.level = level
	return hero

func run(t: Object) -> void:
	var original_hero: Node = GameManager.hero
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_level: Level = GameManager.current_level

	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(10, 10)
	var target_pos: int = ConstantsData.xy_to_pos(12, 10)
	var hero: Hero = _make_hero(hero_pos, level)
	var victim := Char.new()
	victim.pos = target_pos
	victim.level = level
	level.add_mob(victim)

	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = level
	GameManager.add_hero(hero)

	var potion: Potion = Potion.create("toxic_gas")
	potion.quantity = 2
	potion.identified = false
	potion.level_known = false
	potion.cursed_known = false
	t.check(hero.belongings.add_item(potion), "test potion added to backpack")

	hero._do_throw_item(potion, target_pos)

	t.check(victim.has_buff("Poison"), "thrown potion calls shatter effect at the collision cell")
	t.check(potion.quantity == 1, "thrown potion consumes one item from the stack")
	t.check(hero.belongings.has_item(potion), "partially consumed thrown potion remains in backpack")
	t.check(potion.is_identified(), "thrown potion identifies itself after shattering")

	var single_potion: Potion = Potion.create("paralytic_gas")
	single_potion.quantity = 1
	t.check(hero.belongings.add_item(single_potion), "single test potion added to backpack")
	hero._do_throw_item(single_potion, target_pos)
	t.check(not hero.belongings.has_item(single_potion), "last thrown potion is removed from backpack")

	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.current_level = original_level

	hero.free()
	victim.free()
