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

	t.check(_has_blob(level, "toxic_gas"), "thrown toxic gas potion seeds toxic gas")
	t.check(not victim.has_buff("Poison"), "thrown gas waits for the blob tick before applying poison")
	level.tick_blobs()
	t.check(victim.has_buff("Poison"), "toxic gas blob poisons at the collision cell")
	t.check(potion.quantity == 1, "thrown potion consumes one item from the stack")
	t.check(hero.belongings.has_item(potion), "partially consumed thrown potion remains in backpack")
	t.check(potion.is_identified(), "thrown potion identifies itself after shattering")

	var single_potion: Potion = Potion.create("paralytic_gas")
	single_potion.quantity = 1
	t.check(hero.belongings.add_item(single_potion), "single test potion added to backpack")
	hero._do_throw_item(single_potion, target_pos)
	t.check(_has_blob(level, "paralytic_gas"), "thrown paralytic gas potion seeds paralytic gas")
	level.tick_blobs()
	t.check(victim.has_buff("Paralysis"), "paralytic gas blob paralyzes at the collision cell")
	t.check(not hero.belongings.has_item(single_potion), "last thrown potion is removed from backpack")

	var flame: Potion = Potion.create("liquid_flame")
	flame.shatter(target_pos, level)
	t.check(_has_blob(level, "fire"), "liquid flame shatter seeds fire blob")

	var frost: Potion = Potion.create("frost")
	frost.shatter(target_pos, level)
	t.check(_has_blob(level, "freezing"), "frost shatter seeds freezing blob")

	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.current_level = original_level

	hero.free()
	victim.free()

func _has_blob(level: Level, blob_id: String) -> bool:
	for entry: Dictionary in level.blobs:
		var blob: Variant = entry.get("blob")
		if blob != null and str(blob.get("blob_id")) == blob_id:
			return true
	return false
