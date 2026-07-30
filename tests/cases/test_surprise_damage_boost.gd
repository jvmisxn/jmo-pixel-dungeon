extends RefCounted
## Sneak-blade surprise damage boost (upstream Dagger/Dirk/AssassinsBlade/
## Kunai damageRoll overrides): on a surprise attack the roll's minimum
## shifts toward max by 75%/67%/50%/60% of the min..max span.
## Covers:
##   - surprise_toward_max per-weapon factors, 0 for non-sneak weapons
##   - boosted rolls never fall below min + round(span * factor)
##   - non-surprise rolls still reach below the boosted minimum
##   - owners without the surprise flag (mobs/statues) get plain rolls


class StubOwner:
	extends RefCounted
	var str_val: int = 10
	var _pending_surprise_attack: bool = false


func run(t: Object) -> void:
	_test_factors(t)
	_test_boosted_roll_floor(t)
	_test_unsurprised_roll_unboosted(t)
	_test_flagless_owner_unboosted(t)


func _test_factors(t: Object) -> void:
	t.check(
		MeleeWeapon.create("dagger").surprise_toward_max() == 0.75,
		"dagger surprise factor is 0.75"
	)
	t.check(
		MeleeWeapon.create("dirk").surprise_toward_max() == 0.67,
		"dirk surprise factor is 0.67"
	)
	t.check(
		MeleeWeapon.create("assassins_blade").surprise_toward_max() == 0.50,
		"assassins blade surprise factor is 0.50"
	)
	t.check(
		MissileWeapon.create("kunai").surprise_toward_max() == 0.6,
		"kunai surprise factor is 0.6"
	)
	t.check(
		MeleeWeapon.create("sword").surprise_toward_max() == 0.0,
		"non-sneak melee weapon has no surprise factor"
	)
	t.check(
		MissileWeapon.create("shuriken").surprise_toward_max() == 0.0,
		"non-sneak missile has no surprise factor"
	)


func _test_boosted_roll_floor(t: Object) -> void:
	for weapon_id: String in ["dagger", "dirk", "assassins_blade", "kunai"]:
		var w: Weapon
		if weapon_id == "kunai":
			w = MissileWeapon.create(weapon_id)
		else:
			w = MeleeWeapon.create(weapon_id)
		var owner := StubOwner.new()
		owner.str_val = w.get_str_requirement()
		owner._pending_surprise_attack = true
		var r: Array[int] = w.get_damage_range()
		var floor_min: int = r[0] + roundi(float(r[1] - r[0]) * w.surprise_toward_max())
		var lowest: int = 999
		for i: int in range(200):
			lowest = mini(lowest, w.damage_roll(owner))
		t.check(
			lowest >= floor_min,
			"%s surprise rolls never fall below %d (got %d)"
				% [weapon_id, floor_min, lowest]
		)


func _test_unsurprised_roll_unboosted(t: Object) -> void:
	var dagger: MeleeWeapon = MeleeWeapon.create("dagger")
	var owner := StubOwner.new()
	owner.str_val = dagger.get_str_requirement()
	var r: Array[int] = dagger.get_damage_range()
	var floor_min: int = r[0] + roundi(float(r[1] - r[0]) * 0.75)
	var lowest: int = 999
	for i: int in range(200):
		lowest = mini(lowest, dagger.damage_roll(owner))
	t.check(
		lowest < floor_min,
		"unsurprised dagger rolls reach below the boosted floor (got %d)" % lowest
	)


func _test_flagless_owner_unboosted(t: Object) -> void:
	# Owners without the hero surprise flag (mobs, animated statues) roll the
	# plain range: get("_pending_surprise_attack") is null, never true.
	var dagger: MeleeWeapon = MeleeWeapon.create("dagger")
	var statue := Char.new()
	statue.str_val = dagger.get_str_requirement()
	var r: Array[int] = dagger.get_damage_range()
	var floor_min: int = r[0] + roundi(float(r[1] - r[0]) * 0.75)
	var lowest: int = 999
	for i: int in range(200):
		lowest = mini(lowest, dagger.damage_roll(statue))
	t.check(
		lowest < floor_min,
		"flagless owners roll the plain unboosted range (got %d)" % lowest
	)
	statue.free()
