extends RefCounted
## Rogue Sucker Punch (upstream Talent.SUCKER_PUNCH, Rogue T1):
## Talent.onAttackProc adds Random.IntRange(points, 2) bonus damage the first
## time the Rogue surprise attacks each enemy, marking the enemy with a
## permanent SuckerPunchTracker so the bonus never repeats on that target.
## Also covers the T1 roster move (upstream has sucker_punch and
## protective_shadows in tier 1, not tier 2).

func run(t: Object) -> void:
	_test_first_surprise_attack_bonus(t)
	_test_two_points_always_two(t)
	_test_once_per_enemy(t)
	_test_no_surprise_no_bonus(t)
	_test_no_talent_no_tracker(t)
	_test_non_mob_target_unaffected(t)
	_test_tracker_permanent(t)
	_test_rogue_t1_roster(t)

func _make_rogue(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	if points > 0:
		hero.talent_levels["rogue_sucker_punch"] = points
	return hero

func _test_first_surprise_attack_bonus(t: Object) -> void:
	var hero := _make_rogue(1)
	var mob := Mob.new()
	hero._pending_surprise_attack = true
	var result: int = hero.attack_proc(mob, 10)
	t.check(result >= 11 and result <= 12,
		"+1 first surprise attack adds 1-2 bonus damage, got %d" % (result - 10))
	t.check(mob.has_buff("SuckerPunchTracker"),
		"The first sucker punch marks the enemy with the tracker")
	mob.free()
	hero.free()

func _test_two_points_always_two(t: Object) -> void:
	var hero := _make_rogue(2)
	for i in range(5):
		var mob := Mob.new()
		hero._pending_surprise_attack = true
		var result: int = hero.attack_proc(mob, 10)
		t.check(result == 12,
			"+2 sucker punch always adds exactly 2, got %d" % (result - 10))
		mob.free()
	hero.free()

func _test_once_per_enemy(t: Object) -> void:
	var hero := _make_rogue(2)
	var mob := Mob.new()
	hero._pending_surprise_attack = true
	hero.attack_proc(mob, 10)
	hero._pending_surprise_attack = true
	var second: int = hero.attack_proc(mob, 10)
	t.check(second == 10,
		"A second surprise attack on the same enemy adds nothing, got %d" % (second - 10))
	mob.free()
	hero.free()

func _test_no_surprise_no_bonus(t: Object) -> void:
	var hero := _make_rogue(2)
	var mob := Mob.new()
	hero._pending_surprise_attack = false
	var result: int = hero.attack_proc(mob, 10)
	t.check(result == 10, "A non-surprise attack adds nothing, got %d" % (result - 10))
	t.check(not mob.has_buff("SuckerPunchTracker"),
		"A non-surprise attack does not mark the enemy")
	mob.free()
	hero.free()

func _test_no_talent_no_tracker(t: Object) -> void:
	var hero := _make_rogue(0)
	var mob := Mob.new()
	hero._pending_surprise_attack = true
	var result: int = hero.attack_proc(mob, 10)
	t.check(result == 10, "Without the talent there is no bonus, got %d" % (result - 10))
	t.check(not mob.has_buff("SuckerPunchTracker"),
		"Without the talent the enemy is not marked")
	mob.free()
	hero.free()

func _test_non_mob_target_unaffected(t: Object) -> void:
	var hero := _make_rogue(2)
	var dummy := Char.new()
	hero._pending_surprise_attack = true
	var result: int = hero.attack_proc(dummy, 10)
	t.check(result == 10,
		"Non-mob targets get no sucker punch bonus, got %d" % (result - 10))
	t.check(not dummy.has_buff("SuckerPunchTracker"),
		"Non-mob targets are not marked")
	dummy.free()
	hero.free()

func _test_tracker_permanent(t: Object) -> void:
	var tracker := SuckerPunchTracker.new()
	t.check(tracker.duration < 0.0, "The tracker is permanent like upstream's Buff")
	tracker.act()
	t.check(not tracker.is_expired(), "The tracker never expires from turn ticks")
	tracker.free()

func _test_rogue_t1_roster(t: Object) -> void:
	var sucker: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.ROGUE, "rogue_sucker_punch")
	var shadows: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.ROGUE, "rogue_protective_shadows")
	t.check(sucker != null and sucker.tier == 1,
		"Sucker Punch sits at tier 1 like upstream")
	t.check(shadows != null and shadows.tier == 1,
		"Protective Shadows sits at tier 1 like upstream")
