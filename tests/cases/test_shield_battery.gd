extends RefCounted
## Mage Shield Battery talent (SPD Wand.onSelect self-target branch): zapping a
## wand at the Mage's own cell converts all of its charges into a Barrier of
## 4% max HP per charge (x1.5 at 2 points), and drains the wand to 0 charges.

func run(t: Object) -> void:
	_test_self_zap_converts_charges(t)
	_test_two_points_multiplier(t)
	_test_requires_talent_and_class(t)
	_test_no_charges_fizzles(t)
	_test_normal_zap_untouched(t)
	_test_energizing_upgrade_migration(t)

func _make_mage(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	hero.hp_max = 100
	hero.ht = 100
	hero.hp = 100
	hero.pos = 100
	if points > 0:
		hero.talent_levels["mage_shield_battery"] = points
	return hero

func _give_wand(hero: Hero, charges: int) -> Wand:
	var wand: Wand = Wand.create("wand_of_magic_missile")
	wand.charges = charges
	hero.belongings.add_item(wand)
	return wand

func _test_self_zap_converts_charges(t: Object) -> void:
	var hero := _make_mage(1)
	var wand := _give_wand(hero, 3)
	hero._do_zap_wand(wand, hero.pos)
	var barrier: Barrier = hero.get_buff("Barrier") as Barrier
	t.check(barrier != null, "Self-zap with Shield Battery grants a Barrier")
	t.check(barrier != null and barrier.get_shielding() == 12,
		"One-point barrier is 4% max HP per charge (100 HP, 3 charges -> 12)")
	t.check(wand.charges == 0, "Shield Battery drains the wand to 0 charges")
	hero.free()

func _test_two_points_multiplier(t: Object) -> void:
	var hero := _make_mage(2)
	var wand := _give_wand(hero, 3)
	hero._do_zap_wand(wand, hero.pos)
	var barrier: Barrier = hero.get_buff("Barrier") as Barrier
	t.check(barrier != null and barrier.get_shielding() == 18,
		"Two-point barrier gets the x1.5 multiplier (12 -> 18)")
	hero.free()

func _test_requires_talent_and_class(t: Object) -> void:
	var untalented := _make_mage(0)
	var wand := _give_wand(untalented, 3)
	t.check(not untalented._try_shield_battery(wand),
		"Self-zap is not intercepted without the talent")
	t.check(wand.charges == 3, "Untalented self-zap leaves charges untouched")
	untalented.free()

	var rogue := Hero.new()
	rogue.init_class(ConstantsData.HeroClass.ROGUE)
	rogue.talent_levels["mage_shield_battery"] = 2
	var rogue_wand: Wand = Wand.create("wand_of_magic_missile")
	rogue_wand.charges = 3
	rogue.belongings.add_item(rogue_wand)
	t.check(not rogue._try_shield_battery(rogue_wand),
		"Shield Battery only triggers for the Mage class")
	rogue.free()

func _test_no_charges_fizzles(t: Object) -> void:
	var hero := _make_mage(1)
	var wand := _give_wand(hero, 0)
	t.check(hero._try_shield_battery(wand),
		"Empty-wand self-zap is still handled (fizzle) so no zap fires")
	t.check(hero.get_buff("Barrier") == null,
		"Fizzled Shield Battery grants no Barrier")
	hero.free()

func _test_normal_zap_untouched(t: Object) -> void:
	var hero := _make_mage(2)
	var wand := _give_wand(hero, 3)
	hero._do_zap_wand(wand, hero.pos + 1)
	t.check(hero.get_buff("Barrier") == null,
		"Zapping a non-self cell does not trigger Shield Battery")
	hero.free()

func _test_energizing_upgrade_migration(t: Object) -> void:
	var hero := _make_mage(0)
	hero.talent_levels["mage_energizing_upgrade"] = 3
	var data: Dictionary = hero.serialize()
	var loaded := Hero.new()
	loaded.deserialize(data)
	t.check(not loaded.talent_levels.has("mage_energizing_upgrade"),
		"Retired energizing upgrade id is removed on load")
	t.check(loaded.get_talent_level("mage_shield_battery") == 2,
		"Migrated points land on Shield Battery clamped to the 2-point cap")
	hero.free()
	loaded.free()
