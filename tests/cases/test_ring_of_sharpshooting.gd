extends RefCounted
## Ring of Sharpshooting source fidelity: upstream SPD's Ring of Sharpshooting is
## missile-only. It raises a thrown/missile weapon's effective level (widening its
## damage range) and its durability, and does NOT affect accuracy or melee weapons.
## Previously the port's SharpshootingBuff exposed generic modify_damage/
## modify_accuracy hooks, so the bonus leaked into every melee swing and inflated
## accuracy. These tests pin the missile-only, damage-only behavior.

class FixedMeleeWeapon:
	extends Weapon

	func damage_roll(_owner: Variant = null) -> int:
		return 5

func run(t: Object) -> void:
	_check_missile_damage_scales_with_ring(t)
	_check_melee_damage_unaffected(t)
	_check_accuracy_unaffected(t)
	_check_static_helper(t)

func _make_hero() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	return hero

func _make_ring(level: int) -> Ring:
	var ring: Ring = Ring.create("ring_of_sharpshooting")
	ring.level = level
	ring.cursed = false
	return ring

## A tier-1 dart at level 0 rolls in [1, 10]. With a +3 Sharpshooting ring the
## missile's effective level becomes 3, giving [4, 16]. STR is set to the dart's
## requirement so the excess-STR bonus does not blur the comparison.
func _check_missile_damage_scales_with_ring(t: Object) -> void:
	seed(778811)
	var hero: Hero = _make_hero()
	hero.str_val = 10  # dart STR req at level 0 -> no excess-STR bonus

	var dart: MissileWeapon = MissileWeapon.create("dart")
	dart.level = 0

	# Baseline: no ring equipped.
	var base_min: int = 999
	var base_max: int = 0
	for _i: int in range(200):
		var dmg: int = dart.damage_roll(hero)
		base_min = mini(base_min, dmg)
		base_max = maxi(base_max, dmg)
	t.check(base_max <= 10, "unringed dart never exceeds its level-0 max (10)")

	# Equip a +3 Sharpshooting ring.
	hero.belongings.equip_ring(_make_ring(3), true)
	var ring_min: int = 999
	var ring_max: int = 0
	for _i: int in range(200):
		var dmg: int = dart.damage_roll(hero)
		ring_min = mini(ring_min, dmg)
		ring_max = maxi(ring_max, dmg)

	t.check(ring_min >= 4, "sharpshot dart never rolls below the raised level-3 min (4)")
	t.check(ring_max > 10, "sharpshot dart reaches beyond the level-0 max, up to 16")
	hero.free()

## Melee damage must be identical with or without the ring: the bonus no longer
## leaks through the generic buff modify_damage hook.
func _check_melee_damage_unaffected(t: Object) -> void:
	seed(112233)
	var hero: Hero = _make_hero()
	var weapon := FixedMeleeWeapon.new()
	hero.belongings.equip_weapon(weapon)

	t.check(hero.damage_roll() == 5, "melee damage is the raw weapon roll before equipping the ring")

	hero.belongings.equip_ring(_make_ring(4), true)
	t.check(hero.damage_roll() == 5, "melee damage is unchanged after equipping a +4 Sharpshooting ring")
	hero.free()

## Accuracy must be identical with or without the ring: upstream Sharpshooting has
## no accuracy component.
func _check_accuracy_unaffected(t: Object) -> void:
	var hero: Hero = _make_hero()
	hero.belongings.unequip("weapon")
	hero.attack_skill = 50

	var before: int = hero.accuracy()
	hero.belongings.equip_ring(_make_ring(5), true)
	var after: int = hero.accuracy()

	t.check(after == before, "accuracy is unchanged by a +5 Sharpshooting ring")
	hero.free()

## The static lookup returns the equipped ring's bonus for missile damage code,
## and 0 for a character without the ring.
func _check_static_helper(t: Object) -> void:
	var hero: Hero = _make_hero()
	t.check(Ring.sharpshooting_level_bonus(hero) == 0, "no bonus without the ring equipped")
	hero.belongings.equip_ring(_make_ring(2), true)
	t.check(Ring.sharpshooting_level_bonus(hero) == 2, "helper returns the equipped ring bonus level")
	t.check(Ring.sharpshooting_level_bonus(null) == 0, "helper is null-safe")
	hero.free()
