extends RefCounted
## Battlemage Empowered Strike (upstream Talent.EMPOWERED_STRIKE): zapping the
## staff's imbued wand primes a 10-turn tracker; the next staff melee strike
## consumes it and deals x(1 + points/6) damage, Math.round semantics.
## Grant lives in MagesStaff.zap (upstream Wand.wandUsed staff-wand branch),
## consumption in Hero.attack_proc (upstream MagesStaff.proc).

func run(t: Object) -> void:
	_test_zap_grants_tracker(t)
	_test_no_talent_no_tracker(t)
	_test_empty_wand_no_tracker(t)
	_test_strike_bonus_and_consumption(t)
	_test_no_tracker_no_bonus(t)
	_test_non_staff_weapon_keeps_tracker(t)

func _make_battlemage(points: int) -> Hero:
	var hero := Hero.new()
	hero.pos = 0
	hero.init_class(ConstantsData.HeroClass.MAGE)
	hero.hero_subclass = ConstantsData.HeroSubclass.BATTLEMAGE
	if points > 0:
		hero.talent_levels["battlemage_empowered_strikes"] = points
	var staff := Generator.create_item("mages_staff") as MagesStaff
	hero.belongings.equip_weapon(staff)
	return hero

func _staff(hero: Hero) -> MagesStaff:
	return hero.belongings.weapon as MagesStaff

func _test_zap_grants_tracker(t: Object) -> void:
	var hero := _make_battlemage(2)
	_staff(hero).zap(hero, 50)
	t.check(hero.has_buff("EmpoweredStrikeTracker"),
		"zapping the staff with the talent grants the tracker")
	var tracker: Buff = hero.get_buff("EmpoweredStrikeTracker")
	t.check(tracker != null and is_equal_approx(tracker.get_time_left(), 10.0),
		"tracker lasts 10 turns like upstream")

func _test_no_talent_no_tracker(t: Object) -> void:
	var hero := _make_battlemage(0)
	_staff(hero).zap(hero, 50)
	t.check(not hero.has_buff("EmpoweredStrikeTracker"),
		"zapping without talent points grants no tracker")

func _test_empty_wand_no_tracker(t: Object) -> void:
	var hero := _make_battlemage(3)
	_staff(hero).get_imbued_wand().charges = 0
	_staff(hero).zap(hero, 50)
	t.check(not hero.has_buff("EmpoweredStrikeTracker"),
		"a fizzled zap (no charges) grants no tracker")

func _test_strike_bonus_and_consumption(t: Object) -> void:
	var hero := _make_battlemage(3)
	hero.add_buff(EmpoweredStrikeTracker.new())
	var mob := Mob.new()
	var result: int = hero.attack_proc(mob, 60)
	t.check(result == 90,
		"3 points: 60 damage becomes 90 (x1.5), got %d" % result)
	t.check(not hero.has_buff("EmpoweredStrikeTracker"),
		"the empowered strike consumes the tracker")
	var second: int = hero.attack_proc(mob, 60)
	t.check(second == 60, "the next strike is unempowered")
	mob.queue_free()

func _test_no_tracker_no_bonus(t: Object) -> void:
	var hero := _make_battlemage(3)
	var mob := Mob.new()
	t.check(hero.attack_proc(mob, 60) == 60,
		"talent without a tracker gives no bonus")
	mob.queue_free()

func _test_non_staff_weapon_keeps_tracker(t: Object) -> void:
	var hero := _make_battlemage(2)
	hero.add_buff(EmpoweredStrikeTracker.new())
	var sword: Variant = Generator.create_item("shortsword")
	hero.belongings.equip_weapon(sword)
	var mob := Mob.new()
	var result: int = hero.attack_proc(mob, 60)
	t.check(result == 60, "a non-staff strike gets no bonus")
	t.check(hero.has_buff("EmpoweredStrikeTracker"),
		"a non-staff strike does not consume the tracker")
	mob.queue_free()
