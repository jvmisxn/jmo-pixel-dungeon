extends RefCounted
## Warrior Provoked Anger (upstream Talent.PROVOKED_ANGER, Warrior T1):
## ShieldBuff.processDamage attaches a 5-turn ProvokedAngerTracker when any
## shield buff on the Warrior is broken by damage; Talent.onAttackProc then
## adds 1 + 2*points bonus damage (3/5) to the next physical attack and
## detaches the tracker.

func run(t: Object) -> void:
	_test_shield_break_attaches_tracker(t)
	_test_partial_absorb_no_tracker(t)
	_test_no_talent_no_tracker(t)
	_test_attack_bonus_and_consume(t)
	_test_no_bonus_without_tracker(t)
	_test_tracker_duration(t)

func _make_warrior(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.hp_max = 30
	hero.ht = 30
	hero.hp = 30
	if points > 0:
		hero.talent_levels["warrior_provoked_anger"] = points
	return hero

func _give_barrier(hero: Hero, amount: int) -> void:
	var barrier: Barrier = hero.add_buff(Barrier.new()) as Barrier
	barrier.set_shield(amount)

func _test_shield_break_attaches_tracker(t: Object) -> void:
	var hero := _make_warrior(1)
	_give_barrier(hero, 5)
	hero.take_damage(8)
	t.check(hero.has_buff("ProvokedAngerTracker"),
		"Breaking a barrier with damage attaches the tracker")
	t.check(hero.hp == 30 - 3, "Barrier still absorbed its 5 shield, hp %d" % hero.hp)
	hero.free()

func _test_partial_absorb_no_tracker(t: Object) -> void:
	var hero := _make_warrior(2)
	_give_barrier(hero, 5)
	hero.take_damage(3)
	t.check(not hero.has_buff("ProvokedAngerTracker"),
		"A dented but unbroken barrier attaches nothing")
	hero.free()

func _test_no_talent_no_tracker(t: Object) -> void:
	var hero := _make_warrior(0)
	_give_barrier(hero, 5)
	hero.take_damage(8)
	t.check(not hero.has_buff("ProvokedAngerTracker"),
		"Without the talent a broken barrier attaches nothing")
	hero.free()

func _test_attack_bonus_and_consume(t: Object) -> void:
	for points in [1, 2]:
		var hero := _make_warrior(points)
		hero.add_buff(ProvokedAngerTracker.new())
		var dummy := Char.new()
		var result: int = hero.attack_proc(dummy, 10)
		var expected: int = 10 + 1 + 2 * points
		t.check(result == expected,
			"+%d attack deals %d bonus damage, got %d" % [points, 1 + 2 * points, result - 10])
		t.check(not hero.has_buff("ProvokedAngerTracker"),
			"The bonus attack consumes the tracker at +%d" % points)
		dummy.free()
		hero.free()

func _test_no_bonus_without_tracker(t: Object) -> void:
	var hero := _make_warrior(2)
	var dummy := Char.new()
	var result: int = hero.attack_proc(dummy, 10)
	t.check(result == 10, "No tracker means no bonus damage, got %d" % result)
	dummy.free()
	hero.free()

func _test_tracker_duration(t: Object) -> void:
	var tracker := ProvokedAngerTracker.new()
	t.check(tracker.duration == 5.0,
		"Tracker lasts 5 turns like the upstream FlavourBuff")
	tracker.free()
