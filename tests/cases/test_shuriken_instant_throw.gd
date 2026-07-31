extends RefCounted
## Shuriken instant first throw (upstream Shuriken.castDelay + onThrow +
## ShurikenInstantTracker): a shuriken thrown with no tracker costs 0 time
## and starts a 19-turn tracker window (DURATION 20 - 1 for the instant
## throw); throws inside the window cost normal missile time. Covers:
##   - first throw delay is 0 and attaches the tracker at 19 turns
##   - tracked throws cost normal (non-zero) missile delay
##   - window expiry restores the instant throw
##   - other missiles never get the tracker or a free throw
##   - factory shurikens no longer carry the retired 0.8 delay stand-in,
##     and legacy saves with it migrate back to 1.0 on load


func _make_hero() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	return hero


func run(t: Object) -> void:
	_test_first_throw_instant(t)
	_test_tracked_throw_costs_time(t)
	_test_expiry_restores_instant(t)
	_test_other_missiles_unaffected(t)
	_test_delay_stand_in_retired(t)


func _test_first_throw_instant(t: Object) -> void:
	var hero := _make_hero()
	var shuriken: MissileWeapon = MissileWeapon.create("shuriken")
	t.check(
		hero._get_throw_delay(shuriken) == 0.0,
		"first shuriken throw costs 0 time"
	)
	var tracker: Buff = hero.get_buff("ShurikenInstantTracker")
	t.check(tracker != null, "instant throw attaches ShurikenInstantTracker")
	t.check(
		tracker != null and tracker.time_left == ShurikenInstantTracker.DURATION - 1.0,
		"tracker window is DURATION - 1 = 19 turns"
	)
	hero.free()


func _test_tracked_throw_costs_time(t: Object) -> void:
	var hero := _make_hero()
	var shuriken: MissileWeapon = MissileWeapon.create("shuriken")
	hero._get_throw_delay(shuriken)
	var tracked_delay: float = hero._get_throw_delay(shuriken)
	t.check(
		tracked_delay > 0.0,
		"shuriken throw inside the tracker window costs time (got %f)" % tracked_delay
	)
	t.check(
		is_equal_approx(tracked_delay, shuriken.speed_factor(hero) * hero.get_speed()),
		"tracked throw costs the normal missile delay"
	)
	hero.free()


func _test_expiry_restores_instant(t: Object) -> void:
	var hero := _make_hero()
	var shuriken: MissileWeapon = MissileWeapon.create("shuriken")
	hero._get_throw_delay(shuriken)
	hero.remove_buff_by_id("ShurikenInstantTracker")
	t.check(
		hero._get_throw_delay(shuriken) == 0.0,
		"shuriken throw is instant again after the window expires"
	)
	hero.free()


func _test_other_missiles_unaffected(t: Object) -> void:
	var hero := _make_hero()
	var knife: MissileWeapon = MissileWeapon.create("throwing_knife")
	t.check(
		hero._get_throw_delay(knife) > 0.0,
		"non-shuriken missiles never throw for free"
	)
	t.check(
		hero.get_buff("ShurikenInstantTracker") == null,
		"non-shuriken throws never attach the tracker"
	)
	hero.free()


func _test_delay_stand_in_retired(t: Object) -> void:
	var shuriken: MissileWeapon = MissileWeapon.create("shuriken")
	t.check(
		is_equal_approx(shuriken.delay_factor, 1.0),
		"factory shuriken has no 0.8 delay stand-in"
	)
	var legacy: Dictionary = shuriken.serialize()
	legacy["delay_factor"] = 0.8
	var loaded: MissileWeapon = MissileWeapon.create("shuriken")
	loaded.deserialize(legacy)
	t.check(
		is_equal_approx(loaded.delay_factor, 1.0),
		"legacy 0.8 shuriken delay migrates to 1.0 on load"
	)
