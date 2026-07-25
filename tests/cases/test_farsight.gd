extends RefCounted
## Sniper Farsight (upstream Talent.FARSIGHT, Level.updateFieldOfView):
## the hero's shadowcast radius is multiplied by 1 + 0.25 * points, applied
## after any level-based vision caps, then rounded (Math.round semantics).

func run(t: Object) -> void:
	_test_registry(t)
	_test_no_talent_base(t)
	_test_scaling(t)
	_test_rounding(t)
	_test_blindness_still_zero(t)

func _make_sniper() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	hero.hero_subclass = ConstantsData.HeroSubclass.SNIPER
	return hero

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.HUNTRESS, "sniper_farsight",
		ConstantsData.HeroSubclass.SNIPER
	)
	t.check(info != null and info.implemented, "Farsight is registered and implemented")
	t.check(info != null and info.max_points == 3, "Farsight caps at 3 points")

func _test_no_talent_base(t: Object) -> void:
	var hero := _make_sniper()
	t.check(hero.get_view_distance() == 10, "Untalented Huntress view distance stays 10")
	hero.free()

func _test_scaling(t: Object) -> void:
	var hero := _make_sniper()
	hero.talent_levels["sniper_farsight"] = 2
	t.check(hero.get_view_distance() == 15, "+2 Farsight gives 10 * 1.5 = 15")
	hero.talent_levels["sniper_farsight"] = 3
	t.check(hero.get_view_distance() == 18, "+3 Farsight gives round(10 * 1.75) = 18")
	hero.free()

func _test_rounding(t: Object) -> void:
	var hero := _make_sniper()
	hero.talent_levels["sniper_farsight"] = 1
	# 10 * 1.25 = 12.5 rounds half-up to 13, matching upstream Math.round.
	t.check(hero.get_view_distance() == 13, "+1 Farsight rounds 12.5 up to 13")
	hero.free()

func _test_blindness_still_zero(t: Object) -> void:
	var hero := _make_sniper()
	hero.talent_levels["sniper_farsight"] = 3
	hero.add_buff(Blindness.new())
	t.check(hero.get_view_distance() == 0, "Blindness still disables sight with Farsight")
	hero.free()
