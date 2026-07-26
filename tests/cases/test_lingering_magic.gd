extends RefCounted
## Mage Lingering Magic (upstream Talent.LINGERING_MAGIC, Mage T1):
## Wand.wandUsed prolongs a 5-turn LingeringMagicTracker whenever the Mage
## zaps a wand or staff; Talent.onAttackProc then adds IntRange(points, 2)
## bonus damage to the next physical attack and detaches the tracker.

func run(t: Object) -> void:
	_test_zap_proc_attaches_tracker(t)
	_test_no_talent_no_tracker(t)
	_test_attack_bonus_plus_two(t)
	_test_attack_bonus_plus_one_range(t)
	_test_no_bonus_without_tracker(t)
	_test_no_stacking(t)
	_test_tracker_duration(t)
	_test_talent_registered(t)

func _make_mage(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	if points > 0:
		hero.talent_levels["mage_lingering_magic"] = points
	return hero

func _test_zap_proc_attaches_tracker(t: Object) -> void:
	var hero := _make_mage(1)
	var wand := Wand.new()
	wand._lingering_magic_proc(hero)
	t.check(hero.has_buff("LingeringMagicTracker"),
		"Zap proc attaches the tracker with the talent")
	hero.free()

func _test_no_talent_no_tracker(t: Object) -> void:
	var hero := _make_mage(0)
	var wand := Wand.new()
	wand._lingering_magic_proc(hero)
	t.check(not hero.has_buff("LingeringMagicTracker"),
		"Zap proc attaches nothing without the talent")
	hero.free()

func _test_attack_bonus_plus_two(t: Object) -> void:
	var hero := _make_mage(2)
	hero.add_buff(LingeringMagicTracker.new())
	var dummy := Char.new()
	var result: int = hero.attack_proc(dummy, 10)
	t.check(result == 12,
		"+2 attack deals exactly 2 bonus damage (IntRange(2,2)), got %d" % (result - 10))
	t.check(not hero.has_buff("LingeringMagicTracker"),
		"The bonus attack consumes the tracker")
	dummy.free()
	hero.free()

func _test_attack_bonus_plus_one_range(t: Object) -> void:
	for _i in range(8):
		var hero := _make_mage(1)
		hero.add_buff(LingeringMagicTracker.new())
		var dummy := Char.new()
		var bonus: int = hero.attack_proc(dummy, 10) - 10
		t.check(bonus >= 1 and bonus <= 2,
			"+1 bonus is IntRange(1,2), got %d" % bonus)
		dummy.free()
		hero.free()

func _test_no_bonus_without_tracker(t: Object) -> void:
	var hero := _make_mage(2)
	var dummy := Char.new()
	var result: int = hero.attack_proc(dummy, 10)
	t.check(result == 10, "No tracker means no bonus damage, got %d" % result)
	dummy.free()
	hero.free()

func _test_no_stacking(t: Object) -> void:
	var hero := _make_mage(1)
	var wand := Wand.new()
	wand._lingering_magic_proc(hero)
	wand._lingering_magic_proc(hero)
	var count: int = 0
	for b: Node in hero.get_buffs():
		if b is LingeringMagicTracker:
			count += 1
	t.check(count == 1, "Repeated zaps refresh one tracker, found %d" % count)
	hero.free()

func _test_tracker_duration(t: Object) -> void:
	var tracker := LingeringMagicTracker.new()
	t.check(tracker.duration == 5.0,
		"Tracker lasts 5 turns like the upstream FlavourBuff")
	tracker.free()

func _test_talent_registered(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.MAGE, "mage_lingering_magic")
	t.check(info != null and info.tier == 1 and info.max_points == 2 and info.implemented,
		"Lingering Magic is a live tier-1 Mage talent")
