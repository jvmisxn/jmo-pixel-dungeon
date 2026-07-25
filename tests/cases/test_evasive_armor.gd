extends RefCounted
## Freerunner Evasive Armor (upstream Talent.EVASIVE_ARMOR, Momentum.java +
## Armor.evasionFactor): while freerunning, the hero gains excessArmorStr *
## points bonus evasion, where excess = max(0, STR - armor STR requirement).
## The port maps upstream's freerun state to momentum held at the cap, and
## keeps its x1.5 max-momentum multiplier as the upstream heroLvl/2 stand-in.

func run(t: Object) -> void:
	_test_registry(t)
	_test_bonus_requires_freerunning(t)
	_test_bonus_scaling(t)
	_test_no_talent_no_bonus(t)
	_test_armor_evasion_factor(t)
	_test_encumbered_no_bonus(t)

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
		ConstantsData.HeroClass.ROGUE, "freerunner_evasive_armor",
		ConstantsData.HeroSubclass.FREERUNNER
	)
	t.check(info != null and info.implemented, "Evasive Armor is registered and implemented")
	t.check(info != null and info.max_points == 3, "Evasive Armor caps at 3 points")

func _test_bonus_requires_freerunning(t: Object) -> void:
	var hero := _make_freerunner()
	var momentum := _momentum(hero)
	hero.talent_levels["freerunner_evasive_armor"] = 3
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM - 1
	t.check(momentum.evasion_bonus(4) == 0, "No evasion bonus below max momentum")
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM
	t.check(momentum.evasion_bonus(4) == 12, "Bonus applies while freerunning")
	hero.free()

func _test_bonus_scaling(t: Object) -> void:
	var hero := _make_freerunner()
	var momentum := _momentum(hero)
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM
	hero.talent_levels["freerunner_evasive_armor"] = 1
	t.check(momentum.evasion_bonus(3) == 3, "+1 grants 1 evasion per excess strength")
	hero.talent_levels["freerunner_evasive_armor"] = 2
	t.check(momentum.evasion_bonus(3) == 6, "+2 grants 2 evasion per excess strength")
	hero.talent_levels["freerunner_evasive_armor"] = 3
	t.check(momentum.evasion_bonus(3) == 9, "+3 grants 3 evasion per excess strength")
	t.check(momentum.evasion_bonus(0) == 0, "No excess strength means no bonus")
	hero.free()

func _test_no_talent_no_bonus(t: Object) -> void:
	var hero := _make_freerunner()
	var momentum := _momentum(hero)
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM
	t.check(momentum.evasion_bonus(5) == 0, "Untalented freerunning grants no armor evasion bonus")
	hero.free()

func _test_armor_evasion_factor(t: Object) -> void:
	var hero := _make_freerunner()
	var momentum := _momentum(hero)
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM
	hero.talent_levels["freerunner_evasive_armor"] = 3
	var armor := Armor.new()
	armor.tier = 1
	armor._update_str_requirement()
	hero.str_val = armor.str_requirement + 4
	var base: float = 10.0
	var with_talent: float = armor.evasion_factor(hero, base)
	hero.talent_levels["freerunner_evasive_armor"] = 0
	var without_talent: float = armor.evasion_factor(hero, base)
	t.check(
		is_equal_approx(with_talent - without_talent, 12.0),
		"Armor evasion factor adds excess * points while freerunning"
	)
	hero.free()

func _test_encumbered_no_bonus(t: Object) -> void:
	var hero := _make_freerunner()
	var momentum := _momentum(hero)
	momentum.momentum = FreerunnerMomentum.MAX_MOMENTUM
	hero.talent_levels["freerunner_evasive_armor"] = 3
	var armor := Armor.new()
	armor.tier = 3
	armor._update_str_requirement()
	hero.str_val = armor.str_requirement - 2
	var encumbered: float = armor.evasion_factor(hero, 10.0)
	hero.talent_levels["freerunner_evasive_armor"] = 0
	var encumbered_untalented: float = armor.evasion_factor(hero, 10.0)
	t.check(
		is_equal_approx(encumbered, encumbered_untalented),
		"Encumbering armor grants no Evasive Armor bonus"
	)
	hero.free()
