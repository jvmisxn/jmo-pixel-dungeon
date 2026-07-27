extends RefCounted
## Huntress Durable Projectiles (upstream MissileWeapon.durabilityPerUse:
## usages *= 1.25 + 0.25*points -> x1.5/x1.75 durability). Port adaptation:
## the port consumes one whole missile from the stack per throw, so the stack
## accrues 1/multiplier wear per throw and only loses a weapon when a full
## point of wear accumulates — 3 throws cost 2 weapons at +1, 7 throws cost
## 4 weapons at +2. Stacks with Warden Durable Tips: preserved tipped-dart
## throws add no wear (upstream multiplies both durability factors).

func run(t: Object) -> void:
	_test_registry(t)
	_test_no_talent_always_consumes(t)
	_test_plus_one_ratio(t)
	_test_plus_two_ratio(t)
	_test_stacks_with_durable_tips(t)
	_test_wear_serializes(t)

func _make_huntress(points: int) -> Hero:
	var hero := Hero.new()
	hero.pos = 0
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	if points > 0:
		hero.talent_levels["huntress_durable_projectiles"] = points
	return hero

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.HUNTRESS, "huntress_durable_projectiles")
	t.check(info != null, "huntress_durable_projectiles is registered")
	t.check(info != null and info.implemented,
		"huntress_durable_projectiles is marked implemented")
	t.check(info != null and info.tier == 2 and info.max_points == 2,
		"huntress_durable_projectiles is tier 2, max 2 points")

## Simulate `throws` throw-consumption checks; returns how many were consumed.
func _consumed_over(hero: Hero, missile: MissileWeapon, throws: int) -> int:
	var consumed: int = 0
	for _i: int in range(throws):
		if not hero._durable_projectiles_preserves(missile):
			consumed += 1
	return consumed

func _test_no_talent_always_consumes(t: Object) -> void:
	var hero := _make_huntress(0)
	var missile: MissileWeapon = MissileWeapon.create("throwing_knife")
	t.check(_consumed_over(hero, missile, 6) == 6,
		"No talent points -> every throw consumes a weapon")
	t.check(missile.durable_wear == 0.0, "No talent points -> no wear accrued")
	hero.free()

func _test_plus_one_ratio(t: Object) -> void:
	var hero := _make_huntress(1)
	var missile: MissileWeapon = MissileWeapon.create("throwing_knife")
	t.check(_consumed_over(hero, missile, 3) == 2,
		"+1: 3 throws consume exactly 2 weapons (x1.5 durability)")
	t.check(_consumed_over(hero, missile, 30) == 20,
		"+1: ratio holds over 30 more throws (20 consumed)")
	hero.free()

func _test_plus_two_ratio(t: Object) -> void:
	var hero := _make_huntress(2)
	var missile: MissileWeapon = MissileWeapon.create("shuriken")
	t.check(_consumed_over(hero, missile, 7) == 4,
		"+2: 7 throws consume exactly 4 weapons (x1.75 durability)")
	t.check(_consumed_over(hero, missile, 28) == 16,
		"+2: ratio holds over 28 more throws (16 consumed)")
	hero.free()

func _test_stacks_with_durable_tips(t: Object) -> void:
	# Warden with +1 Durable Tips (each dart survives 2 throws) and +1 Durable
	# Projectiles: tips-preserved throws add no wear, so per 6 throws only 3
	# reach the wear check and 2 darts are consumed -> 3x expected lifetime.
	var hero := _make_huntress(1)
	hero.talent_levels["warden_durable_tips"] = 1
	var dart: MissileWeapon = MissileWeapon.create("curare_dart")
	var consumed: int = 0
	for _i: int in range(6):
		if not hero._durable_tips_preserves(dart) \
				and not hero._durable_projectiles_preserves(dart):
			consumed += 1
	t.check(consumed == 2,
		"+1 tips & +1 projectiles: 6 tipped-dart throws consume 2 (got %d)" % consumed)
	hero.free()

func _test_wear_serializes(t: Object) -> void:
	var hero := _make_huntress(1)
	var missile: MissileWeapon = MissileWeapon.create("throwing_knife")
	hero._durable_projectiles_preserves(missile)
	t.check(missile.durable_wear > 0.0, "A preserved throw accrues wear")
	var copy: MissileWeapon = MissileWeapon.create("throwing_knife")
	copy.deserialize(missile.serialize())
	t.check(absf(copy.durable_wear - missile.durable_wear) < 0.0001,
		"durable_wear survives a serialize round-trip")
	var legacy: Dictionary = missile.serialize()
	legacy.erase("durable_wear")
	var old_save: MissileWeapon = MissileWeapon.create("throwing_knife")
	old_save.deserialize(legacy)
	t.check(old_save.durable_wear == 0.0,
		"Saves without durable_wear default to 0 wear")
	hero.free()
