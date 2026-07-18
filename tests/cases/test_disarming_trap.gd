extends RefCounted
## Coverage for DisarmingTrap actually disarming the hero.
##
## Regression: the trap read the weapon from `Hero.get_weapon()`/`hero.weapon`,
## neither of which exist — equipped weapons live on `Belongings`. The trap was
## therefore inert on the hero (always "nothing to disarm") despite being live in
## the Halls trap pool. It must now knock the equipped weapon to a nearby cell.

func _make_level() -> Level:
	var level := Level.new()
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
	hero.hp = 60
	hero.hp_max = 60
	hero.ht = 60
	return hero

func run(t: Object) -> void:
	seed(0xD15A)
	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(10, 10)
	var hero: Hero = _make_hero(hero_pos, level)

	var weapon: Item = Generator.create_item("worn_shortsword")
	t.check(weapon != null, "test can build a starting weapon")
	hero.belongings.equip_weapon(weapon)
	t.check(hero.belongings.get_equipped_weapon() == weapon, "hero starts with the weapon equipped")

	var trap := DisarmingTrap.new()
	trap.set_pos(hero_pos)
	trap.activate(hero, level)

	t.check(hero.belongings.get_equipped_weapon() == null, "disarming trap unequips the hero's weapon")

	# The weapon should now be a heap on a passable cell adjacent to the hero.
	var found_weapon: bool = false
	for dir: int in ConstantsData.DIRS_8:
		var adj: int = hero_pos + dir
		for h: Dictionary in level.heaps_at(adj):
			if h["item"] == weapon:
				found_weapon = true
	t.check(found_weapon, "disarmed weapon is dropped as a heap on a nearby cell")

	hero.free()

	# Negative case: a hero with no weapon reports nothing to disarm and drops nothing.
	var unarmed: Hero = _make_hero(hero_pos, level)
	unarmed.belongings.unequip("weapon")
	t.check(unarmed.belongings.get_equipped_weapon() == null, "unarmed hero really has no weapon")
	var heaps_before: int = level.heaps.size()
	var trap2 := DisarmingTrap.new()
	trap2.set_pos(hero_pos)
	trap2.activate(unarmed, level)
	t.check(level.heaps.size() == heaps_before, "no heap is created when there is no weapon to disarm")

	unarmed.free()
