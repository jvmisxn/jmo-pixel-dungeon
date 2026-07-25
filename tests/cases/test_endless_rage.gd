extends RefCounted
## Berserker Endless Rage talent (upstream Talent.ENDLESS_RAGE): the rage cap
## is raised by 16.67% per point (to 150% at +3), and rage above 100%
## multiplies the Berserker's damage — the port's adaptation of upstream
## Berserk, where power above 1.0 empowers berserking.

func run(t: Object) -> void:
	_test_base_cap_without_talent(t)
	_test_raised_cap_with_talent(t)
	_test_overfill_damage_multiplier(t)
	_test_no_multiplier_at_or_below_base(t)
	_test_death_prevention_still_triggers_at_base(t)
	_test_serialize_round_trip_keeps_overfill(t)

func _make_berserker() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.hp_max = 100
	hero.ht = 100
	hero.hp = 100
	var rage := BerserkerRage.new()
	hero.add_buff(rage)
	return hero

func _rage(hero: Hero) -> BerserkerRage:
	return hero.get_buff("BerserkerRage") as BerserkerRage

func _test_base_cap_without_talent(t: Object) -> void:
	var hero := _make_berserker()
	var rage := _rage(hero)
	rage.on_damage_taken(500, null)
	t.check(rage.rage == 100.0, "Without Endless Rage the rage cap stays at 100")
	hero.free()

func _test_raised_cap_with_talent(t: Object) -> void:
	var hero := _make_berserker()
	hero.talent_levels["berserker_endless_rage"] = 3
	var rage := _rage(hero)
	rage.on_damage_taken(500, null)
	t.check(absf(rage.rage - 150.01) < 0.1, "Endless Rage +3 raises the rage cap to ~150%")
	hero.talent_levels["berserker_endless_rage"] = 1
	rage.rage = 0.0
	rage.on_damage_taken(500, null)
	t.check(absf(rage.rage - 116.67) < 0.1, "Endless Rage +1 raises the rage cap to ~116.7%")
	hero.free()

func _test_overfill_damage_multiplier(t: Object) -> void:
	var hero := _make_berserker()
	hero.talent_levels["berserker_endless_rage"] = 3
	var rage := _rage(hero)
	rage.rage = 150.0
	t.check(rage.modify_damage(100) == 150, "150% rage multiplies damage by 1.5 at full HP")
	hero.free()

func _test_no_multiplier_at_or_below_base(t: Object) -> void:
	var hero := _make_berserker()
	var rage := _rage(hero)
	rage.rage = 100.0
	t.check(rage.modify_damage(100) == 100, "Rage at exactly 100% grants no overfill damage bonus")
	rage.rage = 40.0
	t.check(rage.modify_damage(100) == 100, "Rage below 100% grants no overfill damage bonus")
	hero.free()

func _test_death_prevention_still_triggers_at_base(t: Object) -> void:
	var hero := _make_berserker()
	hero.talent_levels["berserker_endless_rage"] = 3
	var rage := _rage(hero)
	rage.rage = 100.0
	hero.hp = 0
	t.check(rage.try_prevent_death(), "Death prevention still triggers at 100% rage even with a raised cap")
	t.check(hero.hp == 1, "Death prevention leaves the Berserker at 1 HP")
	hero.free()

func _test_serialize_round_trip_keeps_overfill(t: Object) -> void:
	var hero := _make_berserker()
	hero.talent_levels["berserker_endless_rage"] = 3
	var rage := _rage(hero)
	rage.rage = 133.0
	var data: Dictionary = rage.serialize()
	var restored := BerserkerRage.new()
	restored.deserialize(data)
	t.check(absf(restored.rage - 133.0) < 0.01, "Serialize round trip preserves overfilled rage")
	hero.free()
