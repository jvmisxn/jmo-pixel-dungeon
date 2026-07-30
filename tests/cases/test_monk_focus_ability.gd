extends RefCounted
## Monk Focus ability (upstream MonkEnergy.MonkAbility.Focus). Costs 2
## energy and 1 turn (instant while abilities are empowered), applies
## FocusBuff: infinite evasion that beats even surprise attacks (upstream
## Char.hit INFINITE_EVASION ordering) and is consumed by the first parry
## (upstream Hero.defenseVerb).

func run(t: Object) -> void:
	_test_focus_applies_and_spends(t)
	_test_focus_parries_one_attack(t)
	_test_focus_beats_surprise_attack(t)
	_test_refusals(t)
	_test_empowered_focus_is_instant(t)

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

func _make_enemy(level: Level, mob_pos: int, hp: int) -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = maxi(hp, 1)
	mob.hp = hp
	mob.pos = mob_pos
	mob.level = level
	mob.attack_skill = 100
	mob.damage_roll_min = 5
	mob.damage_roll_max = 5
	level.add_mob(mob)
	return mob

func _test_focus_applies_and_spends(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 5.0
	hero._do_monk_ability("focus", -1)
	t.check(hero.get_buff("FocusBuff") != null, "Focus applies FocusBuff")
	t.check(absf(energy.energy - 3.0) < 0.001, "Focus spent 2 energy")
	t.check(hero._ability_spend == 1.0, "Unempowered focus costs 1 turn")
	hero.free()

func _test_focus_parries_one_attack(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	hero.hp = 100
	hero.hp_max = 100
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 5.0
	hero._do_monk_ability("focus", -1)
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 50)
	var landed: bool = enemy.attack(hero)
	t.check(not landed, "Focused hero parries the attack")
	t.check(hero.hp == 100, "Parried attack deals no damage")
	t.check(hero.get_buff("FocusBuff") == null, "Parry consumes the focus buff")
	hero.free()

func _test_focus_beats_surprise_attack(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 5.0
	hero._do_monk_ability("focus", -1)
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 50)
	enemy.invisible = 1
	t.check(not Char.hit(enemy, hero), "Infinite evasion beats a surprise attack")
	hero.free()

func _test_refusals(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 1.5
	hero._do_monk_ability("focus", -1)
	t.check(hero.get_buff("FocusBuff") == null, "Below 2 energy: focus refused")
	t.check(hero._ability_spend == 0.0, "Refused focus costs no time")
	energy.energy = 5.0
	hero._do_monk_ability("focus", -1)
	hero._do_monk_ability("focus", -1)
	t.check(absf(energy.energy - 3.0) < 0.001,
			"Second focus while already focused is refused for free")
	hero.free()

func _test_empowered_focus_is_instant(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	# Overfilled past 1.2x of the level-1 cap (10): empowered without talent.
	energy.energy = 12.0
	hero._do_monk_ability("focus", -1)
	t.check(hero.get_buff("FocusBuff") != null, "Empowered focus still applies")
	t.check(hero._ability_spend == 0.0, "Empowered focus is instant")
	t.check(absf(energy.energy - 10.0) < 0.001,
			"Spend clamps overfilled energy back to the cap")
	hero.free()
