extends RefCounted
## Monk Meditate ability (upstream MonkEnergy.MonkAbility.Meditate). Costs
## 5 energy and 5 turns, cleanses negative buffs, and grants 8 turns of
## rapid wand recharging when the meditation ends. While abilities are
## empowered it also heals round(missing HP / 5) gradually and reduces all
## damage taken to 20% for the meditation's duration.

func run(t: Object) -> void:
	_test_meditate_spends_and_cleanses(t)
	_test_refusal_without_energy(t)
	_test_unempowered_has_no_bonuses(t)
	_test_empowered_heal_and_resistance(t)
	_test_recharging_after_meditation(t)

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 2
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	level.visible.resize(ConstantsData.LENGTH)
	level.visible.fill(true)
	return level

func _make_monk(level: Level, hero_pos: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.hero_subclass = ConstantsData.HeroSubclass.MONK
	hero.level = level
	hero.pos = hero_pos
	hero.str_val = 20
	return hero

func _test_meditate_spends_and_cleanses(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 7.0
	hero.add_buff(Weakness.new())
	hero._do_monk_ability("meditate", -1)
	t.check(hero.get_buff("MeditateTracker") != null,
			"Meditate applies the meditation tracker")
	t.check(absf(energy.energy - 2.0) < 0.001, "Meditate spent 5 energy")
	t.check(hero._ability_spend == 5.0, "Meditate costs 5 turns")
	t.check(hero.get_buff("Weakness") == null,
			"Meditate cleanses negative buffs")
	hero.free()

func _test_refusal_without_energy(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 4.0
	hero._do_monk_ability("meditate", -1)
	t.check(hero.get_buff("MeditateTracker") == null,
			"Meditate refuses below 5 energy")
	t.check(absf(energy.energy - 4.0) < 0.001, "Refusal spends no energy")
	t.check(hero._ability_spend == 0.0, "Refusal costs no time")
	hero.free()

func _test_unempowered_has_no_bonuses(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	hero.hp_max = 100
	hero.hp = 50
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 6.0
	hero._do_monk_ability("meditate", -1)
	t.check(hero.get_buff("Healing") == null,
			"Unempowered meditate grants no healing")
	t.check(hero.get_buff("MeditateResistance") == null,
			"Unempowered meditate grants no resistance")
	hero.free()

func _test_empowered_heal_and_resistance(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	hero.hp_max = 100
	hero.hp = 50
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	# Overfilled past 1.2x of the level-1 cap (10): empowered without talent.
	energy.energy = 12.0
	hero._do_monk_ability("meditate", -1)
	var healing: Healing = hero.get_buff("Healing") as Healing
	t.check(healing != null, "Empowered meditate applies Healing")
	if healing != null:
		t.check(healing.healing_left == 10,
				"Healing pool is round(missing HP / 5)")
		t.check(healing.heal_per_tick() == 1, "Meditate healing is 1 per turn")
	t.check(hero.get_buff("MeditateResistance") != null,
			"Empowered meditate applies MeditateResistance")
	var taken: int = hero.take_damage(20)
	t.check(taken == 4, "Meditate resistance reduces damage to 20%")
	hero.free()

func _test_recharging_after_meditation(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 6.0
	hero._do_monk_ability("meditate", -1)
	t.check(hero.get_buff("Recharging") == null,
			"No recharging while still meditating")
	hero.process_buffs(5.0)
	t.check(hero.get_buff("MeditateTracker") == null,
			"Meditation ends after 5 turns")
	var recharging: Recharging = hero.get_buff("Recharging") as Recharging
	t.check(recharging != null, "Meditation end grants Recharging")
	if recharging != null:
		t.check(absf(recharging.time_left - 8.0) < 0.001,
				"Recharging lasts 8 turns")
	hero.free()
