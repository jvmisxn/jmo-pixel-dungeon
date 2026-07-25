extends RefCounted
## Freerunner Speedy Stealth (upstream Talent.SPEEDY_STEALTH, Momentum.java):
## +1 builds +2 momentum stacks per invisible turn instead of decaying,
## +2 preserves the freerun state while invisible (the port maps upstream's
## frozen freerun timer to no momentum decay while invisible), and
## +3 grants 2x movement speed while invisible regardless of momentum.

func run(t: Object) -> void:
	_test_registry(t)
	_test_invisible_gain(t)
	_test_untalented_decay(t)
	_test_level_one_decay_at_max(t)
	_test_level_two_preserves_max(t)
	_test_speed_bonus(t)

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
		ConstantsData.HeroClass.ROGUE, "freerunner_speedy_stealth",
		ConstantsData.HeroSubclass.FREERUNNER
	)
	t.check(info != null and info.implemented, "Speedy Stealth is registered and implemented")
	t.check(info != null and info.max_points == 3, "Speedy Stealth caps at 3 points")

func _test_invisible_gain(t: Object) -> void:
	var hero := _make_freerunner()
	var momentum := _momentum(hero)
	hero.talent_levels["freerunner_speedy_stealth"] = 1
	hero.invisible = 1
	momentum.momentum = 3
	momentum.on_turn()
	t.check(momentum.momentum == 5, "Invisible turn builds +2 momentum with Speedy Stealth +1")
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM - 1
	momentum.on_turn()
	t.check(momentum.momentum == FreerunnerMomentum.MAX_MOMENTUM, "Invisible gain caps at max momentum")
	hero.free()

func _test_untalented_decay(t: Object) -> void:
	var hero := _make_freerunner()
	var momentum := _momentum(hero)
	hero.invisible = 1
	momentum.momentum = 6
	momentum.on_turn()
	t.check(momentum.momentum == 3, "Without the talent, invisible idle turns still decay momentum")
	hero.free()

func _test_level_one_decay_at_max(t: Object) -> void:
	var hero := _make_freerunner()
	var momentum := _momentum(hero)
	hero.talent_levels["freerunner_speedy_stealth"] = 1
	hero.invisible = 1
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM
	momentum.on_turn()
	t.check(
		momentum.momentum == FreerunnerMomentum.MAX_MOMENTUM - 3,
		"At +1, max momentum still decays while invisible (freerun winds down)"
	)
	hero.free()

func _test_level_two_preserves_max(t: Object) -> void:
	var hero := _make_freerunner()
	var momentum := _momentum(hero)
	hero.talent_levels["freerunner_speedy_stealth"] = 2
	hero.invisible = 1
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM
	momentum.on_turn()
	t.check(
		momentum.momentum == FreerunnerMomentum.MAX_MOMENTUM,
		"At +2, invisibility preserves max momentum"
	)
	hero.invisible = 0
	momentum.on_turn()
	t.check(
		momentum.momentum == FreerunnerMomentum.MAX_MOMENTUM - 3,
		"Once visible again, momentum decays normally"
	)
	hero.free()

func _test_speed_bonus(t: Object) -> void:
	var hero := _make_freerunner()
	var momentum := _momentum(hero)
	hero.talent_levels["freerunner_speedy_stealth"] = 2
	hero.invisible = 1
	momentum.momentum = 0
	t.check(
		is_equal_approx(momentum.modify_speed(1.0), 1.0),
		"Speedy Stealth +2 gives no speed bonus while invisible"
	)
	hero.talent_levels["freerunner_speedy_stealth"] = 3
	t.check(
		is_equal_approx(momentum.modify_speed(1.0), 2.0),
		"Speedy Stealth +3 gives 2x speed while invisible with zero momentum"
	)
	hero.invisible = 0
	t.check(
		is_equal_approx(momentum.modify_speed(1.0), 1.0),
		"No Speedy Stealth speed bonus while visible"
	)
	hero.free()
