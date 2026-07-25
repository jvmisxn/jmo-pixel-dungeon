extends RefCounted
## Berserker Deathless Fury talent (upstream Talent.DEATHLESS_FURY): only with
## the talent can a lethal hit at full rage be survived (upstream berserking).
## The port grants a Barrier per upstream Berserk.currentShieldBoost()
## (base 8 + 2*armor level, 3x at 0 HP, times overfill power) and starts a
## turn-based recovery of (4 - points) * 25 turns during which no rage builds.

func run(t: Object) -> void:
	_test_no_talent_no_prevention(t)
	_test_prevention_grants_upstream_shield(t)
	_test_overfill_multiplies_shield(t)
	_test_recovery_blocks_retrigger_and_rage(t)
	_test_more_points_shorten_recovery(t)
	_test_serialize_round_trip(t)
	_test_legacy_rage_used_migrates(t)

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

func _test_no_talent_no_prevention(t: Object) -> void:
	var hero := _make_berserker()
	var rage := _rage(hero)
	rage.rage = 100.0
	hero.hp = 0
	var prevented := rage.try_prevent_death()
	t.check(not prevented, "Without Deathless Fury a lethal hit is not prevented at full rage")
	hero.free()

func _test_prevention_grants_upstream_shield(t: Object) -> void:
	var hero := _make_berserker()
	hero.talent_levels["berserker_deathless_fury"] = 1
	var rage := _rage(hero)
	rage.rage = 100.0
	hero.hp = 0
	t.check(rage.try_prevent_death(), "Deathless Fury +1 prevents death at full rage")
	t.check(hero.hp == 1, "The Berserker survives at 1 HP")
	var barrier := hero.get_buff("Barrier") as Barrier
	var armor_lvl: int = 0
	var armor: Variant = hero.belongings.get_equipped_armor()
	if armor != null and armor.has_method("buffed_lvl"):
		armor_lvl = armor.buffed_lvl()
	var expected: int = roundi((8.0 + 2.0 * float(armor_lvl)) * 3.0)
	var got: int = barrier.get_shielding() if barrier else -1
	var msg := "Fury shield matches upstream base*3 at 0 HP (got %d, want %d)" % [got, expected]
	t.check(barrier != null and got == expected, msg)
	t.check(rage.rage == 0.0, "Rage resets to 0 after deathless fury triggers")
	hero.free()

func _test_overfill_multiplies_shield(t: Object) -> void:
	var hero := _make_berserker()
	hero.talent_levels["berserker_deathless_fury"] = 1
	hero.talent_levels["berserker_endless_rage"] = 3
	var rage := _rage(hero)
	rage.rage = 150.0
	hero.hp = 0
	var base_shield: float = 8.0
	var armor: Variant = hero.belongings.get_equipped_armor()
	if armor != null and armor.has_method("buffed_lvl"):
		base_shield += 2.0 * float(armor.buffed_lvl())
	var expected: int = roundi(base_shield * 3.0 * 1.5)
	var shield := rage.deathless_shield_amount()
	t.check(shield == expected, "Overfill rage (150%) multiplies the fury shield by 1.5")
	t.check(rage.try_prevent_death(), "Deathless fury triggers with overfilled rage")
	hero.free()

func _test_recovery_blocks_retrigger_and_rage(t: Object) -> void:
	var hero := _make_berserker()
	hero.talent_levels["berserker_deathless_fury"] = 1
	var rage := _rage(hero)
	rage.rage = 100.0
	hero.hp = 0
	t.check(rage.try_prevent_death(), "First deathless fury triggers")
	t.check(absf(rage.recovery_left - 75.0) < 0.01, "Deathless Fury +1 starts a 75-turn recovery")
	rage.on_damage_taken(500, null)
	t.check(rage.rage == 0.0, "No rage builds while recovering")
	rage.rage = 100.0
	hero.hp = 0
	t.check(not rage.try_prevent_death(), "Deathless fury cannot retrigger during recovery")
	rage.rage = 0.0
	rage.recovery_left = 1.0
	rage.on_turn()
	t.check(rage.recovery_left == 0.0, "Recovery counts down each turn")
	rage.on_damage_taken(50, null)
	t.check(rage.rage > 0.0, "Rage builds again once recovery ends")
	hero.free()

func _test_more_points_shorten_recovery(t: Object) -> void:
	var hero := _make_berserker()
	hero.talent_levels["berserker_deathless_fury"] = 3
	var rage := _rage(hero)
	rage.rage = 100.0
	hero.hp = 0
	t.check(rage.try_prevent_death(), "Deathless fury triggers at +3")
	t.check(absf(rage.recovery_left - 25.0) < 0.01, "Deathless Fury +3 shortens recovery to 25 turns")
	hero.free()

func _test_serialize_round_trip(t: Object) -> void:
	var rage := BerserkerRage.new()
	rage.rage = 40.0
	rage.recovery_left = 42.0
	var data: Dictionary = rage.serialize()
	var restored := BerserkerRage.new()
	restored.deserialize(data)
	var ok := absf(restored.recovery_left - 42.0) < 0.01
	t.check(ok, "Serialize round trip preserves recovery turns")

func _test_legacy_rage_used_migrates(t: Object) -> void:
	var rage := BerserkerRage.new()
	var data: Dictionary = rage.serialize()
	data.erase("recovery_left")
	data["rage_used"] = true
	var restored := BerserkerRage.new()
	restored.deserialize(data)
	var migrated := absf(restored.recovery_left - 75.0) < 0.01
	t.check(migrated, "Legacy rage_used saves migrate to a 75-turn recovery")
