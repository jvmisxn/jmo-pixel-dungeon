extends RefCounted
## Mage Desperate Power (upstream Talent.DESPERATE_POWER, Mage T3):
## Wand.buffedLvl adds the talent points to the wand's effective level when
## curCharges == 1 at zap time. Port: zap() spends the charge before on_zap,
## so charges == 0 at damage-roll time is the last-charge condition, and the
## bonus is applied to the level passed into get_damage() by roll_zap_damage.

## Deterministic damage wand: min == max == 10 * lvl, so a roll exposes the
## exact effective level used.
class _ProbeWand extends Wand:
	func get_damage(lvl: int) -> Array[int]:
		return [10 * lvl, 10 * lvl] as Array[int]

func run(t: Object) -> void:
	_test_registry(t)
	_test_bonus_on_last_charge(t)
	_test_no_bonus_with_charges_left(t)
	_test_no_bonus_without_talent(t)
	_test_no_bonus_null_hero(t)
	_test_damage_roll_uses_bonus(t)
	_test_spend_order_matches_zap(t)

func _make_mage(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	if points > 0:
		hero.talent_levels["mage_desperate_power"] = points
	return hero

func _make_wand(charges: int) -> _ProbeWand:
	var wand := _ProbeWand.new()
	wand.charges = charges
	return wand

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.MAGE, "mage_desperate_power")
	t.check(info != null, "mage_desperate_power is registered")
	if info != null:
		t.check(info.tier == 3 and info.max_points == 3 and info.implemented,
			"Desperate Power is an implemented 3-point T3 talent")
	var warp: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.MAGE, "mage_ally_warp")
	t.check(warp != null and not warp.implemented and warp.tier == 3,
		"Ally Warp is an inert T3 groundwork slot")

func _test_bonus_on_last_charge(t: Object) -> void:
	var hero := _make_mage(3)
	var wand := _make_wand(0)
	t.check(wand._desperate_power_bonus(hero) == 3,
		"+3 grants a 3-level bonus when the last charge was just spent")
	hero.talent_levels["mage_desperate_power"] = 1
	t.check(wand._desperate_power_bonus(hero) == 1,
		"+1 grants a 1-level bonus")
	hero.free()

func _test_no_bonus_with_charges_left(t: Object) -> void:
	var hero := _make_mage(3)
	var wand := _make_wand(1)
	t.check(wand._desperate_power_bonus(hero) == 0,
		"No bonus while charges remain after the zap")
	hero.free()

func _test_no_bonus_without_talent(t: Object) -> void:
	var hero := _make_mage(0)
	var wand := _make_wand(0)
	t.check(wand._desperate_power_bonus(hero) == 0,
		"No bonus without the talent")
	hero.free()

func _test_no_bonus_null_hero(t: Object) -> void:
	var wand := _make_wand(0)
	t.check(wand._desperate_power_bonus(null) == 0,
		"Null hero yields no bonus")

func _test_damage_roll_uses_bonus(t: Object) -> void:
	var hero := _make_mage(2)
	var wand := _make_wand(0)
	wand.level = 1
	t.check(wand.roll_zap_damage(hero) == 30,
		"Last-charge roll at level 1 with +2 rolls as level 3 (30 damage)")
	t.check(wand.roll_zap_damage(null) == 10,
		"Hero-less roll ignores the talent (10 damage)")
	hero.free()

func _test_spend_order_matches_zap(t: Object) -> void:
	# zap() spends the charge before on_zap; replicate that ordering from a
	# 1-charge wand and confirm the roll sees the last-charge bonus.
	var hero := _make_mage(1)
	var wand := _make_wand(1)
	wand.level = 1
	wand.spend_charge()
	t.check(wand.roll_zap_damage(hero) == 20,
		"Spending the final charge then rolling applies the bonus (level 2)")
	hero.free()
