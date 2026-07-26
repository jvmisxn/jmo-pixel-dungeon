extends RefCounted
## Warrior Lethal Momentum (upstream Talent.LETHAL_MOMENTUM, Warrior T2):
## when a hero's killing blow lands, Mob.die rolls 0.34 + 0.33*points
## (67%/100% at +1/+2) to attach a LethalMomentumTracker; Hero.attackDelay
## then detaches it and returns 0 so the blow costs no time. Verified through
## Mob._lethal_momentum_on_kill with forced rolls plus Hero._get_attack_delay
## consumption.

func run(t: Object) -> void:
	_test_roll_thresholds(t)
	_test_zero_points_never_triggers(t)
	_test_non_hero_source_never_triggers(t)
	_test_attack_delay_consumes_tracker(t)
	_test_die_with_two_points_always_attaches(t)

func _make_warrior(points: int) -> Hero:
	var hero := Hero.new()
	hero.pos = 0
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	if points > 0:
		hero.talent_levels["warrior_lethal_momentum"] = points
	return hero

func _make_mob() -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = 10
	mob.hp = 10
	mob.pos = ConstantsData.xy_to_pos(5, 5)
	return mob

func _test_roll_thresholds(t: Object) -> void:
	var hero := _make_warrior(1)
	var mob := _make_mob()
	t.check(mob._lethal_momentum_on_kill(hero, 0.66),
		"Roll 0.66 with 1 point succeeds (chance 0.67)")
	hero.remove_buff_by_id("LethalMomentumTracker")
	t.check(not mob._lethal_momentum_on_kill(hero, 0.67),
		"Roll 0.67 with 1 point fails")
	t.check(not hero.has_buff("LethalMomentumTracker"),
		"Failed roll attaches no tracker")
	var hero2 := _make_warrior(2)
	t.check(mob._lethal_momentum_on_kill(hero2, 0.99),
		"Roll 0.99 with 2 points succeeds (chance 1.0)")
	t.check(hero2.has_buff("LethalMomentumTracker"),
		"Successful roll attaches the tracker")
	mob.free()
	hero.free()
	hero2.free()

func _test_zero_points_never_triggers(t: Object) -> void:
	var hero := _make_warrior(0)
	var mob := _make_mob()
	t.check(not mob._lethal_momentum_on_kill(hero, 0.0),
		"No talent points: even roll 0.0 attaches nothing")
	mob.free()
	hero.free()

func _test_non_hero_source_never_triggers(t: Object) -> void:
	var mob := _make_mob()
	var killer := _make_mob()
	t.check(not mob._lethal_momentum_on_kill(null, 0.0),
		"Null kill source attaches nothing")
	t.check(not mob._lethal_momentum_on_kill(killer, 0.0),
		"A mob kill source attaches nothing")
	mob.free()
	killer.free()

func _test_attack_delay_consumes_tracker(t: Object) -> void:
	var hero := _make_warrior(2)
	hero.add_buff(LethalMomentumTracker.new())
	var delay: float = hero._get_attack_delay()
	t.check(is_zero_approx(delay),
		"A pending tracker makes the attack cost no time, got %f" % delay)
	t.check(not hero.has_buff("LethalMomentumTracker"),
		"The zero-time attack consumes the tracker")
	var second: float = hero._get_attack_delay()
	t.check(is_equal_approx(second, 1.0),
		"The next attack costs normal time again, got %f" % second)
	hero.free()

func _test_die_with_two_points_always_attaches(t: Object) -> void:
	var hero := _make_warrior(2)
	var mob := _make_mob()
	mob._lethal_momentum_on_kill(hero)
	t.check(hero.has_buff("LethalMomentumTracker"),
		"2 points: the live randf() roll always succeeds (chance 1.0)")
	mob.free()
	hero.free()
