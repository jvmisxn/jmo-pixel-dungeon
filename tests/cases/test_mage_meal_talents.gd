extends RefCounted
## Mage meal talents (upstream Talent.onFoodEaten):
## EMPOWERING_MEAL (T1) attaches a WandEmpower buff — 1+points (2/3) bonus
## damage on the next 3 damage-wand zaps, consumed per DamageWand.damageRoll
## (port: Wand.roll_zap_damage(hero)), detaching at 0 zaps left. Re-eating
## overwrites the boost but never lowers remaining zaps (set: max(left, shots)).
## ENERGIZING_MEAL (T2) grants 2+3*points (5/8) turns of Recharging.
## Previously the port's empowering_meal wrongly granted Recharging (the T2
## Energizing Meal effect) — this locks in the corrected split.

class _FixedWand extends Wand.WandOfMagicMissile:
	func get_damage(_lvl: int) -> Array[int]:
		return [10, 10] as Array[int]

func run(t: Object) -> void:
	_test_empowering_attaches_buff(t)
	_test_no_talent_no_buffs(t)
	_test_empower_boosts_and_depletes(t)
	_test_reeating_keeps_zaps_overwrites_boost(t)
	_test_no_hero_roll_ignores_empower(t)
	_test_energizing_recharging_duration(t)
	_test_empower_serialize_round_trip(t)

func _make_mage(empower: int = 0, energize: int = 0) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	if empower > 0:
		hero.talent_levels["mage_empowering_meal"] = empower
	if energize > 0:
		hero.talent_levels["mage_energizing_meal"] = energize
	return hero

func _test_empowering_attaches_buff(t: Object) -> void:
	for points: int in [1, 2]:
		var hero := _make_mage(points)
		hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
		var emp: Variant = hero.get_buff("WandEmpower")
		t.check(emp != null, "+%d Empowering Meal attaches WandEmpower" % points)
		if emp != null:
			t.check(emp.dmg_boost == 1 + points,
				"+%d boost is %d, got %d" % [points, 1 + points, emp.dmg_boost])
			t.check(emp.zaps_left == 3, "3 empowered zaps, got %d" % emp.zaps_left)
		t.check(not hero.has_buff("Recharging"),
			"Empowering Meal no longer grants Recharging")
		hero.free()

func _test_no_talent_no_buffs(t: Object) -> void:
	var hero := _make_mage(0, 0)
	hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
	t.check(not hero.has_buff("WandEmpower") and not hero.has_buff("Recharging"),
		"Eating without meal talents attaches neither buff")
	hero.free()

func _test_empower_boosts_and_depletes(t: Object) -> void:
	var hero := _make_mage(2)
	hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
	var wand := _FixedWand.new()
	for zap: int in [1, 2, 3]:
		var dmg: int = wand.roll_zap_damage(hero)
		t.check(dmg == 13, "Empowered zap %d deals 10+3, got %d" % [zap, dmg])
	t.check(not hero.has_buff("WandEmpower"),
		"WandEmpower detaches after 3 empowered zaps")
	t.check(wand.roll_zap_damage(hero) == 10,
		"Fourth zap rolls unboosted damage")
	hero.free()

func _test_reeating_keeps_zaps_overwrites_boost(t: Object) -> void:
	var hero := _make_mage(2)
	hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
	var wand := _FixedWand.new()
	wand.roll_zap_damage(hero)
	var emp: Variant = hero.get_buff("WandEmpower")
	t.check(emp != null and emp.zaps_left == 2, "One zap consumed before re-eating")
	# Drop to +1 and eat again: boost overwritten to 2, zaps back up to 3.
	hero.talent_levels["mage_empowering_meal"] = 1
	hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
	emp = hero.get_buff("WandEmpower")
	t.check(emp != null and emp.dmg_boost == 2,
		"Re-eating overwrites the boost (upstream set)")
	t.check(emp != null and emp.zaps_left == 3,
		"Re-eating restores zaps to max(left, 3)")
	hero.free()

func _test_no_hero_roll_ignores_empower(t: Object) -> void:
	var hero := _make_mage(2)
	hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
	var wand := _FixedWand.new()
	t.check(wand.roll_zap_damage() == 10,
		"Roll without a hero neither boosts nor consumes")
	var emp: Variant = hero.get_buff("WandEmpower")
	t.check(emp != null and emp.zaps_left == 3, "Zaps untouched by hero-less roll")
	hero.free()

func _test_energizing_recharging_duration(t: Object) -> void:
	for expected: Array in [[1, 5.0], [2, 8.0]]:
		var hero := _make_mage(0, int(expected[0]))
		hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
		var recharge: Variant = hero.get_buff("Recharging")
		t.check(recharge != null, "+%d Energizing Meal attaches Recharging" % int(expected[0]))
		if recharge != null:
			t.check(is_equal_approx(recharge.duration, float(expected[1])),
				"+%d Recharging lasts %.0f turns, got %.1f"
				% [int(expected[0]), float(expected[1]), recharge.duration])
		t.check(not hero.has_buff("WandEmpower"),
			"Energizing Meal alone attaches no WandEmpower")
		hero.free()

func _test_empower_serialize_round_trip(t: Object) -> void:
	var emp := WandEmpower.new()
	emp.set_boost(3, 3)
	emp.zaps_left = 2
	var data: Dictionary = emp.serialize()
	var restored := WandEmpower.new()
	restored.deserialize(data)
	t.check(restored.dmg_boost == 3 and restored.zaps_left == 2,
		"Serialize round-trips boost %d and zaps %d"
		% [restored.dmg_boost, restored.zaps_left])
