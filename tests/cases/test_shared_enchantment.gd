extends RefCounted
## Sniper Shared Enchantment (upstream MissileWeapon.proc): thrown-weapon
## hits have a points-in-3 chance (Random.Int(3) < points) to also proc the
## spirit bow's enchantment on the hit, on top of the missile's own
## enchantment. Verified through Hero._shared_enchantment_proc with a forced
## roll so results stay deterministic; a stub enchantment records the proc.

class StubEnchant:
	extends WeaponEnchantment
	var proc_count: int = 0
	var last_weapon: Variant = null

	func _init() -> void:
		enchant_id = "stub"
		enchant_name = "Stub"

	func proc(weapon: Variant, _attacker: Variant, _defender: Variant, damage: int) -> int:
		proc_count += 1
		last_weapon = weapon
		return damage + 5

func run(t: Object) -> void:
	_test_registry(t)
	_test_proc_applies_bow_enchant(t)
	_test_roll_at_or_above_points_fails(t)
	_test_no_points_never_procs(t)
	_test_no_bow_no_proc(t)
	_test_unenchanted_bow_no_proc(t)
	_test_magic_immune_blocks(t)

func _make_sniper(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	hero.hero_subclass = ConstantsData.HeroSubclass.SNIPER
	if points > 0:
		hero.talent_levels["sniper_shared_enchantment"] = points
	return hero

func _give_bow(hero: Hero, ench: WeaponEnchantment) -> SpiritBow:
	var bow := SpiritBow.new()
	if ench != null:
		bow.enchant(ench)
	hero.belongings.spirit_bow = bow
	return bow

func _make_target() -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = 20
	mob.hp = 20
	return mob

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.HUNTRESS, "sniper_shared_enchantment",
		ConstantsData.HeroSubclass.SNIPER)
	t.check(info != null, "sniper_shared_enchantment is registered for the Sniper")
	t.check(info != null and info.implemented,
		"sniper_shared_enchantment is marked implemented (no longer inert)")

func _test_proc_applies_bow_enchant(t: Object) -> void:
	var hero := _make_sniper(2)
	var ench := StubEnchant.new()
	_give_bow(hero, ench)
	var missile := MissileWeapon.create("dart")
	var target := _make_target()
	var out: int = hero._shared_enchantment_proc(missile, target, 10, 1)
	t.check(out == 15, "Roll 1 < 2 points procs the bow enchant (+5 stub)")
	t.check(ench.proc_count == 1, "Bow enchantment proc fired exactly once")
	t.check(ench.last_weapon == missile,
		"Bow enchant proc receives the thrown missile as the weapon (upstream passes 'this')")
	target.free()
	hero.free()

func _test_roll_at_or_above_points_fails(t: Object) -> void:
	var hero := _make_sniper(2)
	var ench := StubEnchant.new()
	_give_bow(hero, ench)
	var missile := MissileWeapon.create("dart")
	var target := _make_target()
	var out: int = hero._shared_enchantment_proc(missile, target, 10, 2)
	t.check(out == 10 and ench.proc_count == 0,
		"Roll 2 >= 2 points does not proc (33%/67%/100% chance)")
	target.free()
	hero.free()

func _test_no_points_never_procs(t: Object) -> void:
	var hero := _make_sniper(0)
	var ench := StubEnchant.new()
	_give_bow(hero, ench)
	var missile := MissileWeapon.create("dart")
	var target := _make_target()
	var out: int = hero._shared_enchantment_proc(missile, target, 10, 0)
	t.check(out == 10 and ench.proc_count == 0,
		"Without the talent the bow enchant never shares")
	target.free()
	hero.free()

func _test_no_bow_no_proc(t: Object) -> void:
	var hero := _make_sniper(3)
	var missile := MissileWeapon.create("dart")
	var target := _make_target()
	var out: int = hero._shared_enchantment_proc(missile, target, 10, 0)
	t.check(out == 10, "No spirit bow in belongings: damage unchanged")
	target.free()
	hero.free()

func _test_unenchanted_bow_no_proc(t: Object) -> void:
	var hero := _make_sniper(3)
	_give_bow(hero, null)
	var missile := MissileWeapon.create("dart")
	var target := _make_target()
	var out: int = hero._shared_enchantment_proc(missile, target, 10, 0)
	t.check(out == 10, "Unenchanted spirit bow: damage unchanged")
	target.free()
	hero.free()

func _test_magic_immune_blocks(t: Object) -> void:
	var hero := _make_sniper(3)
	var ench := StubEnchant.new()
	_give_bow(hero, ench)
	hero.add_buff(MagicImmune.new())
	var missile := MissileWeapon.create("dart")
	var target := _make_target()
	var out: int = hero._shared_enchantment_proc(missile, target, 10, 0)
	t.check(out == 10 and ench.proc_count == 0,
		"Magic Immune blocks the shared enchant proc (upstream check)")
	target.free()
	hero.free()
