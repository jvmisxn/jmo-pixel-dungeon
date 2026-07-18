extends RefCounted
## Same-tier weapons must differ mechanically, not just cosmetically. This covers
## the per-weapon delay_factor / damage_multiplier / str_req_bonus differentiation
## and proves the combat-facing APIs (get_damage_range, speed_factor,
## get_str_requirement) actually expose those differences, plus a serialize
## round-trip so the new fields survive save/load.

func run(t: Object) -> void:
	_check_standard_baseline_unchanged(t)
	_check_same_tier_melee_differs(t)
	_check_damage_and_str_apis(t)
	_check_speed_factor_reflects_delay(t)
	_check_round_trip(t)
	_check_legacy_save_uses_factory_profile(t)
	_check_missile_same_tier_differs(t)

## worn_shortsword is the intended tier-1 baseline: neutral multipliers keep its
## pre-differentiation numbers identical so nothing regressed for standard weapons.
func _check_standard_baseline_unchanged(t: Object) -> void:
	var w: MeleeWeapon = MeleeWeapon.create("worn_shortsword")
	t.check(w.delay_factor == 1.0, "worn_shortsword keeps the neutral delay baseline")
	t.check(w.damage_multiplier == 1.0, "worn_shortsword keeps the neutral damage baseline")
	t.check(w.str_req_bonus == 0, "worn_shortsword keeps the neutral STR baseline")
	# tier 1, lvl 0 => min = tier = 1, max = 5*(tier+1) = 10
	t.check(w.get_damage_range() == [1, 10], "worn_shortsword damage range unchanged (1-10)")
	t.check(w.get_str_requirement() == 10, "worn_shortsword STR req unchanged (10)")

## The five tier-1 melee weapons must not all share one stat profile.
func _check_same_tier_melee_differs(t: Object) -> void:
	var ids: Array[String] = ["worn_shortsword", "cudgel", "gloves", "rapier", "dagger"]
	var delays: Array[float] = []
	var maxes: Array[int] = []
	var strs: Array[int] = []
	for id: String in ids:
		var w: MeleeWeapon = MeleeWeapon.create(id)
		delays.append(w.speed_factor(null))
		maxes.append(w.get_damage_range()[1])
		strs.append(w.get_str_requirement())

	t.check(_distinct_count(delays) >= 4,
		"tier-1 melee weapons expose at least 4 distinct attack delays")
	t.check(_distinct_count(maxes) >= 4,
		"tier-1 melee weapons expose at least 4 distinct max-damage values")
	# STR reqs cluster into fewer buckets (-1/0/+1) but must not be uniform.
	t.check(_distinct_count(strs) >= 2,
		"tier-1 melee weapons expose more than one STR requirement")

## Concrete archetype checks: the heavy cudgel and the light dagger sit on
## opposite sides of the standard worn_shortsword in every combat stat.
func _check_damage_and_str_apis(t: Object) -> void:
	var std: MeleeWeapon = MeleeWeapon.create("worn_shortsword")
	var heavy: MeleeWeapon = MeleeWeapon.create("cudgel")
	var light: MeleeWeapon = MeleeWeapon.create("dagger")

	# Damage: heavy hits hardest, light softest.
	t.check(heavy.get_damage_range()[1] > std.get_damage_range()[1],
		"heavy cudgel out-damages the standard baseline")
	t.check(light.get_damage_range()[1] < std.get_damage_range()[1],
		"light dagger under-damages the standard baseline")

	# STR requirement: heavy demands more, light demands less.
	t.check(heavy.get_str_requirement() > std.get_str_requirement(),
		"heavy cudgel needs more STR than the baseline")
	t.check(light.get_str_requirement() < std.get_str_requirement(),
		"light dagger needs less STR than the baseline")

	# str_requirement field cached by the factory matches the live computation.
	t.check(heavy.str_requirement == heavy.get_str_requirement(),
		"factory-cached STR req matches the live value for cudgel")

## speed_factor is the combat-facing delay used by the turn scheduler; a lower
## value means a faster swing. Fast weapons must report a smaller delay.
func _check_speed_factor_reflects_delay(t: Object) -> void:
	var std: MeleeWeapon = MeleeWeapon.create("worn_shortsword")
	var heavy: MeleeWeapon = MeleeWeapon.create("war_hammer")   # tier 5, delay 1.4
	var light: MeleeWeapon = MeleeWeapon.create("gloves")       # tier 1, delay 0.6

	t.check(light.speed_factor(null) < std.speed_factor(null),
		"gloves attack faster (lower delay) than the baseline")
	t.check(heavy.speed_factor(null) > std.speed_factor(null),
		"war hammer attacks slower (higher delay) than the baseline")
	t.check(is_equal_approx(light.speed_factor(null), 0.6),
		"speed_factor surfaces the raw per-weapon delay when unencumbered")

## The new fields must survive a serialize/deserialize round-trip.
func _check_round_trip(t: Object) -> void:
	var w: MeleeWeapon = MeleeWeapon.create("mace")  # delay 1.2, dmg 1.2, str +1
	var data: Dictionary = w.serialize()
	var w2: MeleeWeapon = MeleeWeapon.new()
	w2.deserialize(data)
	t.check(is_equal_approx(w2.delay_factor, 1.2), "delay_factor survives round-trip")
	t.check(is_equal_approx(w2.damage_multiplier, 1.2), "damage_multiplier survives round-trip")
	t.check(w2.str_req_bonus == 1, "str_req_bonus survives round-trip")
	t.check(w2.get_damage_range() == w.get_damage_range(),
		"restored weapon computes the same damage range")

## Older saves did not persist damage_multiplier/str_req_bonus and may contain
## the old neutral delay_factor. Loading through the generator should keep the
## current factory archetype instead of flattening the weapon back to neutral.
func _check_legacy_save_uses_factory_profile(t: Object) -> void:
	var old_data: Dictionary = {
		"item_id": "cudgel",
		"item_name": "Cudgel",
		"category": ConstantsData.ItemCategory.WEAPON,
		"tier": 1,
		"delay_factor": 1.0,
	}
	var loaded: MeleeWeapon = Generator.create_item("cudgel") as MeleeWeapon
	loaded.deserialize(old_data)
	t.check(is_equal_approx(loaded.delay_factor, 1.15),
		"legacy cudgel load keeps the factory heavy delay")
	t.check(is_equal_approx(loaded.damage_multiplier, 1.15),
		"legacy cudgel load keeps the factory heavy damage multiplier")
	t.check(loaded.str_req_bonus == 1, "legacy cudgel load keeps the factory STR bonus")

## Missile weapons share the base differentiation fields; a heavy thrown club
## must out-damage and out-slow a plain dart of the same tier.
func _check_missile_same_tier_differs(t: Object) -> void:
	var dart: MissileWeapon = MissileWeapon.create("dart")
	var club: MissileWeapon = MissileWeapon.create("throwing_club")
	t.check(club.get_damage_range()[1] > dart.get_damage_range()[1],
		"heavy throwing club out-damages a tier-1 dart")
	t.check(club.speed_factor(null) > dart.speed_factor(null),
		"heavy throwing club is slower to throw than a dart")
	t.check(club.get_str_requirement() > dart.get_str_requirement(),
		"heavy throwing club needs more STR than a dart")

func _distinct_count(values: Array) -> int:
	var seen: Array = []
	for v: Variant in values:
		if not seen.has(v):
			seen.append(v)
	return seen.size()
