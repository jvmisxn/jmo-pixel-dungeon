extends RefCounted
## Gladiator Enhanced Combo (upstream Talent.ENHANCED_COMBO): upstream empowers
## manual combo moves used at higher counts (Clobber at 7+, Parry at 9+, leap
## range and AoE at +3). The port's combo is an auto-finisher with no manual
## moves, so each point raises the finisher threshold from 3 to 5/7/9 hits,
## letting the combo build toward the x3.0 damage multiplier cap.

func run(t: Object) -> void:
	_test_base_threshold(t)
	_test_talent_raises_threshold(t)
	_test_no_finisher_below_threshold(t)
	_test_finisher_at_raised_threshold(t)
	_test_max_combo_multiplier_reachable(t)
	_test_untalented_finisher_unchanged(t)

func _make_gladiator() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	var combo := GladiatorCombo.new()
	hero.add_buff(combo)
	return hero

func _combo(hero: Hero) -> GladiatorCombo:
	return hero.get_buff("GladiatorCombo") as GladiatorCombo

func _test_base_threshold(t: Object) -> void:
	var hero := _make_gladiator()
	var combo := _combo(hero)
	t.check(combo.finisher_threshold() == 3, "Untalented finisher threshold is 3 hits")
	hero.free()

func _test_talent_raises_threshold(t: Object) -> void:
	var hero := _make_gladiator()
	var combo := _combo(hero)
	hero.talent_levels["gladiator_enhanced_combo"] = 1
	t.check(combo.finisher_threshold() == 5, "Enhanced Combo +1 raises the threshold to 5")
	hero.talent_levels["gladiator_enhanced_combo"] = 2
	t.check(combo.finisher_threshold() == 7, "Enhanced Combo +2 raises the threshold to 7")
	hero.talent_levels["gladiator_enhanced_combo"] = 3
	t.check(combo.finisher_threshold() == 9, "Enhanced Combo +3 raises the threshold to 9")
	hero.free()

func _test_no_finisher_below_threshold(t: Object) -> void:
	var hero := _make_gladiator()
	var combo := _combo(hero)
	hero.talent_levels["gladiator_enhanced_combo"] = 1
	combo.combo_count = 4
	t.check(combo.modify_damage(10) == 10, "A 4-hit combo does not finish below the raised threshold")
	t.check(combo.combo_count == 4, "Combo keeps building below the raised threshold")
	hero.free()

func _test_finisher_at_raised_threshold(t: Object) -> void:
	var hero := _make_gladiator()
	var combo := _combo(hero)
	hero.talent_levels["gladiator_enhanced_combo"] = 1
	combo.combo_count = 5
	var expected: int = int(10 * combo.get_combo_multiplier())
	t.check(expected > 15, "A 5-hit finisher outdamages the base 3-hit x1.5 finisher")
	t.check(combo.modify_damage(10) == expected, "Finisher fires at the raised threshold with the higher-count multiplier")
	t.check(combo.combo_count == 0, "Finisher consumes the combo")
	hero.free()

func _test_max_combo_multiplier_reachable(t: Object) -> void:
	var hero := _make_gladiator()
	var combo := _combo(hero)
	hero.talent_levels["gladiator_enhanced_combo"] = 3
	combo.combo_count = GladiatorCombo.MAX_COMBO
	t.check(combo.get_combo_multiplier() == 3.0, "A 10-hit combo reaches the x3.0 multiplier cap")
	t.check(combo.modify_damage(10) == 30, "The x3.0 finisher triples the hit")
	hero.free()

func _test_untalented_finisher_unchanged(t: Object) -> void:
	var hero := _make_gladiator()
	var combo := _combo(hero)
	combo.combo_count = 3
	t.check(combo.modify_damage(10) == 15, "Untalented 3-hit finisher still deals x1.5 damage")
	t.check(combo.combo_count == 0, "Untalented finisher still consumes the combo")
	hero.free()
