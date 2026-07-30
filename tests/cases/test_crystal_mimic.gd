extends RefCounted
## CrystalMimic parity (upstream CrystalMimic.java): the neutral interact bite
## deals a NORMAL damage roll (no fixed-max bonus) and steals a random
## unequipped item; reveal flees with Haste (2 turns neutral / 1 on damage);
## hostile bites fling the victim to an adjacent cell; fleeing out of sight at
## 6+ tiles escapes with all held loot; generate_prize only uncurses contents.

const MIMIC_LEVEL: int = 10


func run(t: Object) -> void:
	_test_neutral_bite_steals_no_bonus(t)
	_test_damage_reveal_haste_one(t)
	_test_hostile_bite_flings_victim(t)
	_test_flee_escape(t)
	_test_generate_prize_uncurses(t)


func _make_level() -> Level:
	var level := Level.new()
	level.depth = MIMIC_LEVEL
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	level.visible.resize(ConstantsData.LENGTH)
	level.visible.fill(true)
	return level


func _make_hero(level: Level, hero_pos: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	hero.level = level
	hero.pos = hero_pos
	return hero


func _make_mimic(level: Level, mimic_pos: int) -> CrystalMimic:
	var mimic := CrystalMimic.new()
	mimic.set_mimic_level(MIMIC_LEVEL)
	mimic.armor_value = 0
	mimic.level = level
	mimic.pos = mimic_pos
	level.mobs.append(mimic)
	return mimic


func _test_neutral_bite_steals_no_bonus(t: Object) -> void:
	var level := _make_level()
	var hero := _make_hero(level, ConstantsData.xy_to_pos(5, 5))
	var mimic := _make_mimic(level, ConstantsData.xy_to_pos(6, 5))

	# One stealable backpack potion; equipped gear must never be taken.
	hero.belongings.backpack.clear()
	var potion: Item = Generator.create_item("healing")
	hero.belongings.backpack.append(potion)

	hero.belongings.armor = null
	hero.armor_value = 0
	hero.ht = 500
	hero.hp_max = 500
	hero.hp = 500

	t.check(mimic.can_interact(hero),
		"Adjacent hero can open a disguised crystal mimic")
	t.check(mimic.mob_name == "Crystal chest",
		"Disguised crystal mimic reads as a crystal chest")

	mimic.interact(hero)

	t.check(not mimic.disguised, "Opening reveals the crystal mimic")
	t.check(mimic.state == Mob.AIState.FLEEING,
		"Crystal mimic flees instead of hunting after reveal")
	t.check(mimic.mob_name == "Crystal mimic", "Name flips on reveal")
	var haste: Node = mimic.get_buff_node("Haste")
	t.check(haste != null and haste.time_left == 2.0,
		"Neutral interact reveal grants a 2-turn Haste")
	t.check(mimic.stored_items.has(potion),
		"The neutral bite stole the backpack potion")
	t.check(not hero.belongings.backpack.has(potion),
		"Stolen potion left the hero's backpack")

	# No fixed-max neutral bonus: over many rolls the neutral-path roll must
	# dip below the fixed 2+2*level (=damage_roll_max) a plain Mimic returns.
	mimic._neutral_bite = true
	var saw_below_max: bool = false
	for _i in range(60):
		if mimic.damage_roll() < mimic.damage_roll_max:
			saw_below_max = true
			break
	mimic._neutral_bite = false
	t.check(saw_below_max,
		"Crystal mimic neutral bite uses a normal roll, not fixed max")


func _test_damage_reveal_haste_one(t: Object) -> void:
	var level := _make_level()
	var hero := _make_hero(level, ConstantsData.xy_to_pos(5, 5))
	var mimic := _make_mimic(level, ConstantsData.xy_to_pos(6, 5))
	mimic.target = hero

	mimic.take_damage(3)

	t.check(not mimic.disguised, "Damage reveals the crystal mimic")
	t.check(mimic.state == Mob.AIState.FLEEING, "Damage reveal also flees")
	var haste: Node = mimic.get_buff_node("Haste")
	t.check(haste != null and haste.time_left == 1.0,
		"Damage reveal grants only a 1-turn Haste")


func _test_hostile_bite_flings_victim(t: Object) -> void:
	var level := _make_level()
	var hero := _make_hero(level, ConstantsData.xy_to_pos(5, 5))
	var mimic := _make_mimic(level, ConstantsData.xy_to_pos(6, 5))
	mimic.reveal()
	mimic._set_state(Mob.AIState.HUNTING)
	var pos_before: int = hero.pos

	mimic.attack_proc(hero, 5)

	t.check(hero.pos != pos_before,
		"Hostile bite teleports the victim off its cell")
	t.check(level.adjacent(mimic.pos, hero.pos),
		"Victim lands adjacent to the mimic")
	t.check(mimic.state == Mob.AIState.FLEEING,
		"Crystal mimic flees again after a hostile bite")


func _test_flee_escape(t: Object) -> void:
	var level := _make_level()
	var hero := _make_hero(level, ConstantsData.xy_to_pos(20, 20))
	var mimic := _make_mimic(level, ConstantsData.xy_to_pos(3, 3))
	mimic.reveal()
	mimic.target = hero
	# Hero far away and out of sight: a full wall column blocks LOS.
	for y in range(0, ConstantsData.HEIGHT):
		level.map[ConstantsData.xy_to_pos(10, y)] = ConstantsData.Terrain.WALL
	level.build_flag_maps()

	t.check(mimic.distance_to(hero.pos) >= 6, "Escape distance precondition")
	mimic._act_fleeing()

	t.check(not level.mobs.has(mimic),
		"Out of sight at 6+ tiles the crystal mimic escapes the level")
	t.check(not mimic.is_alive, "Escaped mimic is gone, not killable loot")


func _test_generate_prize_uncurses(t: Object) -> void:
	var level := _make_level()
	var mimic := _make_mimic(level, ConstantsData.xy_to_pos(6, 5))
	var cursed_item: Item = Generator.create_item("healing")
	cursed_item.cursed = true
	cursed_item.cursed_known = false
	mimic.stored_items.append(cursed_item)
	var count_before: int = mimic.stored_items.size()

	mimic.generate_prize(MIMIC_LEVEL)

	t.check(mimic.stored_items.size() == count_before,
		"generate_prize adds no extra reward for crystal mimics")
	t.check(not cursed_item.cursed and cursed_item.cursed_known,
		"Chest contents are guaranteed uncursed")
