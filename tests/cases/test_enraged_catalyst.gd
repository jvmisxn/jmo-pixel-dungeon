extends RefCounted
## Berserker Enraged Catalyst talent (upstream Talent.ENRAGED_CATALYST):
## Berserk.enchantFactor() adds min(1, power) * 0.15 per point to the weapon
## enchantment proc-chance multiplier, so enchants trigger up to 15%/30%/45%
## more often at 100% rage. Overfill rage past 100% does not raise it further.

func run(t: Object) -> void:
	_test_no_bonus_without_talent(t)
	_test_no_bonus_without_rage(t)
	_test_bonus_scales_with_rage(t)
	_test_full_rage_per_point(t)
	_test_overfill_rage_caps_at_full(t)
	_test_multiplier_without_rage_buff(t)
	_test_multiplier_with_raging_berserker(t)
	_test_multiplier_null_attacker(t)

func _make_berserker(catalyst_points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.hp_max = 100
	hero.ht = 100
	hero.hp = 100
	if catalyst_points > 0:
		hero.talent_levels["berserker_enraged_catalyst"] = catalyst_points
	hero.add_buff(BerserkerRage.new())
	return hero

func _rage(hero: Hero) -> BerserkerRage:
	return hero.get_buff("BerserkerRage") as BerserkerRage

func _test_no_bonus_without_talent(t: Object) -> void:
	var hero := _make_berserker(0)
	var rage := _rage(hero)
	rage.rage = 100.0
	t.check(rage.enchant_proc_bonus() == 0.0, "Full rage grants no bonus without the talent")
	hero.free()

func _test_no_bonus_without_rage(t: Object) -> void:
	var hero := _make_berserker(3)
	var rage := _rage(hero)
	t.check(rage.enchant_proc_bonus() == 0.0, "Zero rage grants no bonus even at +3")
	hero.free()

func _test_bonus_scales_with_rage(t: Object) -> void:
	var hero := _make_berserker(2)
	var rage := _rage(hero)
	rage.rage = 50.0
	t.check(
		absf(rage.enchant_proc_bonus() - 0.15) < 0.0001,
		"Half rage at +2 gives +0.15 (half of 0.30)"
	)
	hero.free()

func _test_full_rage_per_point(t: Object) -> void:
	var hero := _make_berserker(1)
	var rage := _rage(hero)
	rage.rage = 100.0
	t.check(absf(rage.enchant_proc_bonus() - 0.15) < 0.0001, "Full rage at +1 gives +0.15")
	hero.talent_levels["berserker_enraged_catalyst"] = 3
	t.check(absf(rage.enchant_proc_bonus() - 0.45) < 0.0001, "Full rage at +3 gives +0.45")
	hero.free()

func _test_overfill_rage_caps_at_full(t: Object) -> void:
	var hero := _make_berserker(3)
	hero.talent_levels["berserker_endless_rage"] = 3
	var rage := _rage(hero)
	rage.rage = 150.0
	t.check(
		absf(rage.enchant_proc_bonus() - 0.45) < 0.0001,
		"Overfill rage does not push the bonus past +0.45"
	)
	hero.free()

func _test_multiplier_without_rage_buff(t: Object) -> void:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	t.check(
		WeaponEnchantment.proc_chance_multiplier(hero) == 1.0,
		"Hero without rage buff has a 1.0 proc multiplier"
	)
	hero.free()

func _test_multiplier_with_raging_berserker(t: Object) -> void:
	var hero := _make_berserker(3)
	var rage := _rage(hero)
	rage.rage = 100.0
	t.check(
		absf(WeaponEnchantment.proc_chance_multiplier(hero) - 1.45) < 0.0001,
		"Full rage at +3 yields a 1.45x proc multiplier"
	)
	hero.free()

func _test_multiplier_null_attacker(t: Object) -> void:
	t.check(
		WeaponEnchantment.proc_chance_multiplier(null) == 1.0,
		"Null attacker falls back to a 1.0 multiplier"
	)
