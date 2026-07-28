extends RefCounted
## Duelist weapon-ability charge pool (upstream MeleeWeapon.Charger):
## starts at 2 charges, cap scales with level (8 max, 10 as Champion),
## passive gain 1/(60-1.5*(cap-charges)) per turn (x1.5 Champion), the
## Weapon Recharging talent adds 1/(20-5*points) while Recharging is
## active, gain_charge clamps at cap, and state serializes round-trip.

func run(t: Object) -> void:
	_test_duelist_starts_with_charger(t)
	_test_charge_cap_scaling(t)
	_test_passive_gain(t)
	_test_champion_gain_multiplier(t)
	_test_partial_resets_at_cap(t)
	_test_weapon_recharging_talent(t)
	_test_gain_charge_clamps(t)
	_test_serialize_round_trip(t)
	_test_load_repair_attaches_charger(t)

func _make_duelist() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	return hero

func _charger(hero: Hero) -> WeaponCharger:
	return hero.get_buff("WeaponCharger") as WeaponCharger

func _test_duelist_starts_with_charger(t: Object) -> void:
	var duelist := _make_duelist()
	var charger := _charger(duelist)
	t.check(charger != null, "Duelist starts with a WeaponCharger buff")
	t.check(charger != null and charger.charges == 2, "Charger starts at 2 charges")
	t.check(charger != null and not charger.show_in_ui, "Charger is hidden from the buff bar")
	t.check(charger != null and charger.revive_persists, "Charger persists through revive")
	var warrior := Hero.new()
	warrior.init_class(ConstantsData.HeroClass.WARRIOR)
	t.check(warrior.get_buff("WeaponCharger") == null, "Non-Duelist classes get no charger")
	duelist.free()
	warrior.free()

func _test_charge_cap_scaling(t: Object) -> void:
	var duelist := _make_duelist()
	var charger := _charger(duelist)
	t.check(charger.charge_cap() == 2, "Cap is 2 at level 1")
	duelist.hero_level = 19
	t.check(charger.charge_cap() == 8, "Cap is 8 at level 19")
	duelist.hero_level = 30
	t.check(charger.charge_cap() == 8, "Cap stays 8 past level 19")
	duelist.hero_subclass = ConstantsData.HeroSubclass.CHAMPION
	duelist.hero_level = 1
	t.check(charger.charge_cap() == 4, "Champion cap is 4 at level 1")
	duelist.hero_level = 19
	t.check(charger.charge_cap() == 10, "Champion cap is 10 at level 19")
	duelist.free()

func _test_passive_gain(t: Object) -> void:
	var duelist := _make_duelist()
	duelist.hero_level = 4  # cap 3
	var charger := _charger(duelist)
	charger.charges = 2
	charger.partial_charge = 0.0
	charger.on_turn()
	var expected: float = 1.0 / (60.0 - 1.5 * 1.0)
	t.check(is_equal_approx(charger.partial_charge, expected), "One turn gains 1/(60-1.5*(cap-charges)) partial charge")
	charger.partial_charge = 0.999
	charger.on_turn()
	t.check(charger.charges == 3, "Accumulated partial charge converts to a full charge")
	t.check(charger.partial_charge < 1.0, "Partial charge is decremented on conversion")
	duelist.free()

func _test_champion_gain_multiplier(t: Object) -> void:
	var duelist := _make_duelist()
	duelist.hero_level = 1
	duelist.hero_subclass = ConstantsData.HeroSubclass.CHAMPION  # cap 4
	var charger := _charger(duelist)
	charger.charges = 3
	charger.partial_charge = 0.0
	charger.on_turn()
	var expected: float = 1.5 / (60.0 - 1.5 * 1.0)
	t.check(is_equal_approx(charger.partial_charge, expected), "Champion gains charge 1.5x faster")
	duelist.free()

func _test_partial_resets_at_cap(t: Object) -> void:
	var duelist := _make_duelist()
	var charger := _charger(duelist)  # level 1, cap 2, charges 2
	charger.partial_charge = 0.5
	charger.on_turn()
	t.check(charger.charges == 2, "Charges stay at cap")
	t.check(is_zero_approx(charger.partial_charge), "Partial charge zeroes while at cap")
	duelist.free()

func _test_weapon_recharging_talent(t: Object) -> void:
	var duelist := _make_duelist()
	duelist.hero_level = 4  # cap 3
	duelist.talent_levels["duelist_weapon_recharging"] = 2
	var charger := _charger(duelist)
	charger.charges = 2
	charger.partial_charge = 0.0
	charger.on_turn()
	var passive: float = 1.0 / (60.0 - 1.5 * 1.0)
	t.check(is_equal_approx(charger.partial_charge, passive), "Talent adds nothing without a Recharging buff")
	duelist.add_buff(Recharging.new())
	charger.partial_charge = 0.0
	charger.on_turn()
	t.check(is_equal_approx(charger.partial_charge, passive + 0.1), "+2 adds 1/10 per turn while Recharging is active")
	duelist.talent_levels["duelist_weapon_recharging"] = 1
	charger.partial_charge = 0.0
	charger.on_turn()
	t.check(is_equal_approx(charger.partial_charge, passive + 1.0 / 15.0), "+1 adds 1/15 per turn while Recharging is active")
	var registry: TalentData.TalentInfo = TalentData.get_talent(ConstantsData.HeroClass.DUELIST, "duelist_weapon_recharging")
	t.check(registry != null and registry.implemented, "Weapon Recharging is no longer inert")
	t.check(registry != null and registry.max_points == 2, "Weapon Recharging caps at 2 points (upstream)")
	duelist.free()

func _test_gain_charge_clamps(t: Object) -> void:
	var duelist := _make_duelist()
	duelist.hero_level = 7  # cap 4
	var charger := _charger(duelist)
	charger.charges = 2
	charger.partial_charge = 0.0
	charger.gain_charge(1.5)
	t.check(charger.charges == 3 and is_equal_approx(charger.partial_charge, 0.5), "gain_charge converts whole charges and keeps the remainder")
	charger.gain_charge(5.0)
	t.check(charger.charges == 4, "gain_charge clamps at the cap")
	t.check(is_zero_approx(charger.partial_charge), "Partial charge zeroes when clamped at cap")
	charger.gain_charge(1.0)
	t.check(charger.charges == 4, "gain_charge is a no-op at cap")
	duelist.free()

func _test_serialize_round_trip(t: Object) -> void:
	var duelist := _make_duelist()
	var charger := _charger(duelist)
	charger.charges = 5
	charger.partial_charge = 0.25
	var data: Dictionary = charger.serialize()
	var restored := WeaponCharger.new()
	restored.deserialize(data)
	t.check(restored.charges == 5, "Charges survive a serialize round-trip")
	t.check(is_equal_approx(restored.partial_charge, 0.25), "Partial charge survives a serialize round-trip")
	duelist.free()

func _test_load_repair_attaches_charger(t: Object) -> void:
	var source := _make_duelist()
	var data: Dictionary = source.serialize()
	# Simulate a save from before WeaponCharger existed.
	var stripped: Array = []
	for buff_data: Variant in data.get("buffs", []):
		if buff_data.get("buff_id", "") != "WeaponCharger":
			stripped.append(buff_data)
	data["buffs"] = stripped
	var loaded := Hero.new()
	loaded.deserialize(data)
	t.check(loaded.get_buff("WeaponCharger") != null, "Duelist load repair attaches a missing charger")
	var charger := _charger(loaded)
	t.check(charger != null and charger.charges == 2, "Repaired charger starts at the default 2 charges")
	source.free()
	loaded.free()
