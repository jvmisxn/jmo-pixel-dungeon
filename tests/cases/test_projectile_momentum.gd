extends RefCounted
## Freerunner Projectile Momentum (upstream Talent.PROJECTILE_MOMENTUM):
## in Hero.attackSkill's ranged branch, freerunning multiplies accuracy by
## 1 + points/2 (+50%/100%/150%). The port's freerunning state is momentum
## held at the cap, so the bonus applies only at max momentum.

func run(t: Object) -> void:
	_test_registry(t)
	_test_freerunning_state(t)
	_test_untalented_multiplier(t)
	_test_talent_scaling(t)
	_test_no_bonus_below_max(t)
	_test_serialize_round_trip(t)

func _make_freerunner() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	hero.hero_subclass = ConstantsData.HeroSubclass.FREERUNNER
	var momentum := FreerunnerMomentum.new()
	hero.add_buff(momentum)
	return hero

func _momentum(hero: Hero) -> FreerunnerMomentum:
	return hero.get_buff("FreerunnerMomentum") as FreerunnerMomentum

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.ROGUE, "freerunner_projectile_momentum",
		ConstantsData.HeroSubclass.FREERUNNER
	)
	t.check(info != null and info.implemented, "Projectile Momentum is registered and implemented")
	t.check(info != null and info.max_points == 3, "Projectile Momentum caps at 3 points")

func _test_freerunning_state(t: Object) -> void:
	var hero := _make_freerunner()
	var momentum := _momentum(hero)
	t.check(not momentum.is_freerunning(), "Fresh momentum buff is not freerunning")
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM - 1
	t.check(not momentum.is_freerunning(), "9/10 momentum is not freerunning")
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM
	t.check(momentum.is_freerunning(), "Max momentum counts as freerunning")
	hero.free()

func _test_untalented_multiplier(t: Object) -> void:
	var hero := _make_freerunner()
	var momentum := _momentum(hero)
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM
	t.check(
		is_equal_approx(momentum.ranged_accuracy_multiplier(), 1.0),
		"Untalented freerunning gives no ranged accuracy bonus"
	)
	hero.free()

func _test_talent_scaling(t: Object) -> void:
	var hero := _make_freerunner()
	var momentum := _momentum(hero)
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM
	hero.talent_levels["freerunner_projectile_momentum"] = 1
	t.check(
		is_equal_approx(momentum.ranged_accuracy_multiplier(), 1.5),
		"Projectile Momentum +1 gives x1.5 ranged accuracy while freerunning"
	)
	hero.talent_levels["freerunner_projectile_momentum"] = 2
	t.check(
		is_equal_approx(momentum.ranged_accuracy_multiplier(), 2.0),
		"Projectile Momentum +2 gives x2.0 ranged accuracy while freerunning"
	)
	hero.talent_levels["freerunner_projectile_momentum"] = 3
	t.check(
		is_equal_approx(momentum.ranged_accuracy_multiplier(), 2.5),
		"Projectile Momentum +3 gives x2.5 ranged accuracy while freerunning"
	)
	hero.free()

func _test_no_bonus_below_max(t: Object) -> void:
	var hero := _make_freerunner()
	var momentum := _momentum(hero)
	hero.talent_levels["freerunner_projectile_momentum"] = 3
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM - 1
	t.check(
		is_equal_approx(momentum.ranged_accuracy_multiplier(), 1.0),
		"No ranged accuracy bonus below max momentum"
	)
	momentum.momentum = 0
	t.check(
		is_equal_approx(momentum.ranged_accuracy_multiplier(), 1.0),
		"No ranged accuracy bonus with zero momentum"
	)
	hero.free()

func _test_serialize_round_trip(t: Object) -> void:
	var hero := _make_freerunner()
	var momentum := _momentum(hero)
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM
	var data: Dictionary = momentum.serialize()
	var restored := FreerunnerMomentum.new()
	restored.deserialize(data)
	restored.target = hero
	hero.talent_levels["freerunner_projectile_momentum"] = 2
	t.check(restored.is_freerunning(), "Deserialized momentum keeps freerunning state")
	t.check(
		is_equal_approx(restored.ranged_accuracy_multiplier(), 2.0),
		"Deserialized momentum applies the talent multiplier"
	)
	hero.free()
	restored.free()
