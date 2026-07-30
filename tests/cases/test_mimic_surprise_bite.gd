extends RefCounted
## Mimic hidden-interact parity (upstream Mimic.java): an adjacent hero can
## "open" the disguised mimic (can_interact), which reveals it and lands a
## free neutral bite — INFINITE_ACCURACY + fixed max damage (2 + 2*level) —
## unless the hero is invisible. Damage-based reveals get no neutral bonus.

const MIMIC_LEVEL: int = 10  # fixed bite = 2 + 2*10 = 22, pre-armor


func run(t: Object) -> void:
	_test_can_interact_gate(t)
	_test_interact_bite(t)
	_test_invisible_hero_skips_bite(t)
	_test_damage_reveal_has_no_bonus(t)


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


func _make_mimic(level: Level, mimic_pos: int) -> Mimic:
	var mimic := Mimic.new()
	mimic.set_mimic_level(MIMIC_LEVEL)
	mimic.armor_value = 0
	mimic.level = level
	mimic.pos = mimic_pos
	level.mobs.append(mimic)
	return mimic


func _test_can_interact_gate(t: Object) -> void:
	var level := _make_level()
	var hero := _make_hero(level, ConstantsData.xy_to_pos(5, 5))
	var mimic := _make_mimic(level, ConstantsData.xy_to_pos(6, 5))

	t.check(mimic.can_interact(hero), "Adjacent hero can open a disguised mimic")

	hero.pos = ConstantsData.xy_to_pos(9, 5)
	t.check(not mimic.can_interact(hero), "Non-adjacent hero cannot open it")

	hero.pos = ConstantsData.xy_to_pos(6, 6)
	mimic.reveal()
	t.check(not mimic.can_interact(hero),
		"A revealed mimic is hostile, never interactable")


func _test_interact_bite(t: Object) -> void:
	var level := _make_level()
	var hero := _make_hero(level, ConstantsData.xy_to_pos(5, 5))
	var mimic := _make_mimic(level, ConstantsData.xy_to_pos(6, 5))

	# Prove INFINITE_ACCURACY: an absurd evasion stat must not matter.
	hero.defense_skill = 100000
	# The fixed roll is pre-armor (upstream applies drRoll normally); strip the
	# starting armor so the exact bite damage is observable.
	hero.belongings.armor = null
	hero.armor_value = 0
	# A depth-10 bite (22) would kill a fresh 20-HP hero and cap the observed
	# loss; give enough HP to measure the exact roll.
	hero.ht = 100
	hero.hp_max = 100
	hero.hp = 100
	var hp_before: int = hero.hp

	t.check(mimic.accuracy() >= 1000000,
		"Hidden mimic accuracy is INFINITE_ACCURACY")
	t.check(mimic.damage_roll() == 2 + 2 * MIMIC_LEVEL,
		"Hidden mimic damage roll is the fixed max 2 + 2*level")

	mimic.interact(hero)

	t.check(not mimic.disguised, "Opening the mimic reveals it")
	t.check(mimic.state == Mob.AIState.HUNTING, "Revealed mimic is hunting")
	var expected: int = 2 + 2 * MIMIC_LEVEL
	t.check(hp_before - hero.hp == expected,
		"Free bite always hits for fixed max damage (lost %d, want %d)"
			% [hp_before - hero.hp, expected])

	# Once hostile, the neutral bonuses are gone.
	t.check(mimic.accuracy() == 6 + MIMIC_LEVEL,
		"Revealed mimic accuracy returns to 6 + level")
	var roll: int = mimic.damage_roll()
	t.check(roll >= 1 + MIMIC_LEVEL and roll <= 2 + 2 * MIMIC_LEVEL,
		"Revealed mimic damage rolls the normal 1+level..2+2*level range")


func _test_invisible_hero_skips_bite(t: Object) -> void:
	var level := _make_level()
	var hero := _make_hero(level, ConstantsData.xy_to_pos(5, 5))
	var mimic := _make_mimic(level, ConstantsData.xy_to_pos(6, 5))

	hero.invisible = 1
	var hp_before: int = hero.hp
	mimic.interact(hero)

	t.check(not mimic.disguised, "Invisible-hero interact still reveals the mimic")
	t.check(hero.hp == hp_before,
		"Invisible hero takes no free bite (upstream invisible <= 0 gate)")


func _test_damage_reveal_has_no_bonus(t: Object) -> void:
	var level := _make_level()
	var mimic := _make_mimic(level, ConstantsData.xy_to_pos(6, 5))

	mimic.take_damage(3, null)

	t.check(not mimic.disguised, "Damaging a hidden mimic reveals it")
	t.check(mimic.accuracy() == 6 + MIMIC_LEVEL,
		"Damage-based reveal grants no INFINITE_ACCURACY bonus")
	var roll: int = mimic.damage_roll()
	t.check(roll >= 1 + MIMIC_LEVEL and roll <= 2 + 2 * MIMIC_LEVEL,
		"Damage-based reveal keeps the normal damage range")
