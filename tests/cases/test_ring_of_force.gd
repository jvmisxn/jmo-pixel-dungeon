extends RefCounted
## Ring of Force source fidelity: when the hero has no weapon equipped, Force
## replaces the unarmed damage roll with its STR/tier-scaled curve instead of
## letting the hero use bare-hand class damage plus the armed flat bonus.

func run(t: Object) -> void:
	_check_force_replaces_unarmed_damage(t)
	_check_armed_force_still_adds_flat_bonus(t)
	_check_missile_force_gets_no_flat_bonus(t)

class FixedDamageWeapon:
	extends Weapon

	func damage_roll(_owner: Variant = null) -> int:
		return 5

class FixedDamageMissile:
	extends MissileWeapon

	func damage_roll(_owner: Variant = null) -> int:
		return 6

func _make_hero() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.str_val = 18
	hero.damage_roll_min = 1
	hero.damage_roll_max = 8
	return hero

func _make_force_ring(level: int) -> Ring:
	var ring: Ring = Ring.create("ring_of_force")
	ring.level = level
	ring.cursed = false
	return ring

func _check_force_replaces_unarmed_damage(t: Object) -> void:
	seed(91357)
	var hero: Hero = _make_hero()
	hero.belongings.unequip("weapon")
	hero.belongings.equip_ring(_make_force_ring(2), true)

	var lowest: int = 999
	var highest: int = 0
	for _i: int in range(80):
		var dmg: int = hero.damage_roll()
		lowest = mini(lowest, dmg)
		highest = maxi(highest, dmg)

	t.check(lowest >= 7, "unarmed Force uses the ring's STR-scaled minimum damage")
	t.check(highest > 10, "unarmed Force reaches beyond bare-hand damage plus flat bonus")
	t.check(highest <= 42, "unarmed Force stays within the level/tier-scaled maximum")
	hero.free()

func _check_armed_force_still_adds_flat_bonus(t: Object) -> void:
	seed(2468)
	var hero: Hero = _make_hero()
	var weapon := FixedDamageWeapon.new()
	hero.belongings.equip_weapon(weapon)
	hero.belongings.equip_ring(_make_force_ring(3), true)

	t.check(hero.damage_roll() == 8, "armed Force keeps the flat weapon damage bonus")
	hero.free()

func _check_missile_force_gets_no_flat_bonus(t: Object) -> void:
	seed(13579)
	var hero: Hero = _make_hero()
	var target := Char.new()
	var missile := FixedDamageMissile.new()
	hero.attack_skill = 1000000
	target.defense_skill = 0
	target.hp_max = 20
	target.ht = 20
	target.hp = 20
	hero.belongings.equip_ring(_make_force_ring(3), true)

	t.check(hero._resolve_ranged_attack(target, missile), "test missile attack lands")
	t.check(target.hp == target.hp_max - 6, "missile Force does not add the armed flat bonus")
	hero.free()
	target.free()
