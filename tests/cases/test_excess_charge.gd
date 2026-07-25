extends RefCounted
## Battlemage Excess Charge (upstream Talent.EXCESS_CHARGE, Wand.wandUsed
## staff-wand branch): zapping the staff while its wand is at full charges
## grants Barrier shielding = round(wand buffed level * 0.67 * points).
## setShield semantics: an existing barrier is raised to the value, never
## lowered and never stacked.

func run(t: Object) -> void:
	_test_full_charge_zap_shields(t)
	_test_point_scaling(t)
	_test_no_talent_no_shield(t)
	_test_partial_charges_no_shield(t)
	_test_fizzled_zap_no_shield(t)
	_test_level_zero_no_shield(t)
	_test_existing_barrier_not_lowered(t)
	_test_existing_barrier_raised_not_stacked(t)

func _make_battlemage(points: int, wand_level: int) -> Hero:
	var hero := Hero.new()
	hero.pos = 0
	hero.init_class(ConstantsData.HeroClass.MAGE)
	hero.hero_subclass = ConstantsData.HeroSubclass.BATTLEMAGE
	if points > 0:
		hero.talent_levels["battlemage_excess_charge"] = points
	var staff := Generator.create_item("mages_staff") as MagesStaff
	hero.belongings.equip_weapon(staff)
	staff.get_imbued_wand().level = wand_level
	return hero

func _staff(hero: Hero) -> MagesStaff:
	return hero.belongings.weapon as MagesStaff

func _test_full_charge_zap_shields(t: Object) -> void:
	var hero := _make_battlemage(3, 2)
	_staff(hero).zap(hero, 50)
	var barrier: Barrier = hero.get_buff("Barrier") as Barrier
	t.check(barrier != null, "full-charge zap with the talent grants a barrier")
	t.check(barrier != null and barrier.get_shielding() == 4,
		"+3 at wand level 2 shields round(2*0.67*3) = 4, got %d"
		% (barrier.get_shielding() if barrier != null else -1))

func _test_point_scaling(t: Object) -> void:
	var hero := _make_battlemage(1, 3)
	_staff(hero).zap(hero, 50)
	var barrier: Barrier = hero.get_buff("Barrier") as Barrier
	t.check(barrier != null and barrier.get_shielding() == 2,
		"+1 at wand level 3 shields round(3*0.67) = 2")

func _test_no_talent_no_shield(t: Object) -> void:
	var hero := _make_battlemage(0, 2)
	_staff(hero).zap(hero, 50)
	t.check(not hero.has_buff("Barrier"),
		"full-charge zap without the talent grants no barrier")

func _test_partial_charges_no_shield(t: Object) -> void:
	var hero := _make_battlemage(3, 2)
	var wand: Wand = _staff(hero).get_imbued_wand()
	wand.charges = wand.charges_max - 1
	_staff(hero).zap(hero, 50)
	t.check(not hero.has_buff("Barrier"),
		"zapping below full charges grants no barrier")

func _test_fizzled_zap_no_shield(t: Object) -> void:
	var hero := _make_battlemage(3, 2)
	_staff(hero).get_imbued_wand().charges = 0
	_staff(hero).zap(hero, 50)
	t.check(not hero.has_buff("Barrier"),
		"a fizzled zap (no charges) grants no barrier")

func _test_level_zero_no_shield(t: Object) -> void:
	var hero := _make_battlemage(3, 0)
	_staff(hero).zap(hero, 50)
	t.check(not hero.has_buff("Barrier"),
		"a level-0 staff wand rounds to zero shield, matching upstream")

func _test_existing_barrier_not_lowered(t: Object) -> void:
	var hero := _make_battlemage(3, 2)
	var existing: Barrier = hero.add_buff(Barrier.new()) as Barrier
	existing.set_shield(10)
	_staff(hero).zap(hero, 50)
	var barrier: Barrier = hero.get_buff("Barrier") as Barrier
	t.check(barrier != null and barrier.get_shielding() == 10,
		"a stronger existing barrier is not lowered or stacked (setShield)")

func _test_existing_barrier_raised_not_stacked(t: Object) -> void:
	var hero := _make_battlemage(3, 2)
	var existing: Barrier = hero.add_buff(Barrier.new()) as Barrier
	existing.set_shield(2)
	_staff(hero).zap(hero, 50)
	var barrier: Barrier = hero.get_buff("Barrier") as Barrier
	t.check(barrier != null and barrier.get_shielding() == 4,
		"a weaker existing barrier is raised to 4, not stacked to 6")
