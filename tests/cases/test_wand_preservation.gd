extends RefCounted
## Mage Wand Preservation (T2) + MagesStaff imbue flow (upstream
## MagesStaff.imbueWand + Talent.WandPreservationCounter + Hero.earnExp):
## imbuing a new wand syncs the staff level to max(staff, wand), +1 when the
## wand overrides an upgraded staff; old staff charges carry into the new
## wand. With the talent, the replaced wand is returned to the backpack at +0
## while the counter is 0; at +2 the counter detaches on hero level-up.

func run(t: Object) -> void:
	_test_registry(t)
	_test_level_sync_rules(t)
	_test_charge_carry(t)
	_test_preservation_returns_old_wand(t)
	_test_no_talent_consumes_wand(t)
	_test_counter_blocks_second_preserve(t)
	_test_level_up_resets_counter_at_plus2_only(t)
	_test_counter_serialize_round_trip(t)

func _make_mage(points: int = 0) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	if points > 0:
		hero.talent_levels["mage_wand_preservation"] = points
	return hero

func _get_staff(hero: Hero) -> MagesStaff:
	if hero.belongings.weapon is MagesStaff:
		return hero.belongings.weapon
	for item: Item in hero.belongings.backpack:
		if item is MagesStaff:
			return item
	var staff := MagesStaff.new()
	staff.configure_default()
	return staff

func _test_registry(t: Object) -> void:
	var info: Variant = TalentData.get_talent(
		ConstantsData.HeroClass.MAGE, "mage_wand_preservation")
	t.check(info != null and info.implemented,
		"Wand Preservation is registered and implemented")
	if info != null:
		t.check(info.tier == 2 and info.max_points == 2,
			"Wand Preservation is T2 with 2 max points")

func _test_level_sync_rules(t: Object) -> void:
	var hero := _make_mage(0)
	var staff := _get_staff(hero)
	# Higher staff keeps its level.
	staff.level = 3
	var weak := Wand.create("wand_of_frost")
	weak.level = 1
	staff.imbue_new_wand(hero, weak)
	t.check(staff.level == 3,
		"Staff +3 absorbing wand +1 stays +3, got +%d" % staff.level)
	# Wand overriding an upgraded staff preserves one staff upgrade.
	var strong := Wand.create("wand_of_fire_bolt")
	strong.level = 3
	staff.imbue_new_wand(hero, strong)
	t.check(staff.level == 4,
		"Wand +3 overriding staff +3 gives +4, got +%d" % staff.level)
	# Unleveled staff takes the wand level with no bonus.
	var staff2 := MagesStaff.new()
	staff2.configure_default()
	var wand2 := Wand.create("wand_of_frost")
	wand2.level = 2
	staff2.imbue_new_wand(hero, wand2)
	t.check(staff2.level == 2,
		"Staff +0 absorbing wand +2 gives +2, got +%d" % staff2.level)
	hero.free()

func _test_charge_carry(t: Object) -> void:
	var hero := _make_mage(0)
	var staff := MagesStaff.new()
	staff.configure_default()
	staff.imbued_wand.charges = 2
	var wand := Wand.create("wand_of_frost")
	wand.charges = 1
	staff.imbue_new_wand(hero, wand)
	# _sync adds +1 max charge; carried charges = 1 + 2 = 3, capped at max.
	var expected: int = mini(staff.imbued_wand.charges_max, 3)
	t.check(staff.imbued_wand.charges == expected,
		"Old staff charges carry into the new wand (want %d, got %d)"
		% [expected, staff.imbued_wand.charges])
	hero.free()

func _test_preservation_returns_old_wand(t: Object) -> void:
	var hero := _make_mage(1)
	var staff := _get_staff(hero)
	var old_wand: Wand = staff.imbued_wand
	old_wand.level = 2
	var new_wand := Wand.create("wand_of_frost")
	staff.imbue_new_wand(hero, new_wand)
	t.check(staff.imbued_wand == new_wand,
		"New wand is imbued into the staff")
	t.check(hero.belongings.backpack.has(old_wand),
		"Talent returns the replaced wand to the backpack")
	t.check(old_wand.level == 0,
		"Preserved wand is reset to +0, got +%d" % old_wand.level)
	var counter: Variant = hero.get_buff("WandPreservationCounter")
	t.check(counter != null and counter.count == 1,
		"Preservation counts up the WandPreservationCounter")
	hero.free()

func _test_no_talent_consumes_wand(t: Object) -> void:
	var hero := _make_mage(0)
	var staff := _get_staff(hero)
	var old_wand: Wand = staff.imbued_wand
	staff.imbue_new_wand(hero, Wand.create("wand_of_frost"))
	t.check(not hero.belongings.backpack.has(old_wand),
		"Without the talent the replaced wand is consumed")
	t.check(not hero.has_buff("WandPreservationCounter"),
		"No counter buff without the talent")
	hero.free()

func _test_counter_blocks_second_preserve(t: Object) -> void:
	var hero := _make_mage(2)
	var staff := _get_staff(hero)
	staff.imbue_new_wand(hero, Wand.create("wand_of_frost"))
	var second_old: Wand = staff.imbued_wand
	staff.imbue_new_wand(hero, Wand.create("wand_of_fire_bolt"))
	t.check(not hero.belongings.backpack.has(second_old),
		"Counter at 1 blocks a second preservation before level-up")
	hero.free()

func _test_level_up_resets_counter_at_plus2_only(t: Object) -> void:
	# +2: level-up detaches the counter.
	var hero := _make_mage(2)
	var staff := _get_staff(hero)
	staff.imbue_new_wand(hero, Wand.create("wand_of_frost"))
	t.check(hero.has_buff("WandPreservationCounter"),
		"Counter exists after first preservation")
	hero.earn_xp(hero.xp_to_next)
	t.check(not hero.has_buff("WandPreservationCounter"),
		"+2 level-up detaches the counter (repeatable preservation)")
	hero.free()
	# +1: level-up keeps the counter (one preserve ever).
	var hero1 := _make_mage(1)
	var staff1 := _get_staff(hero1)
	staff1.imbue_new_wand(hero1, Wand.create("wand_of_frost"))
	hero1.earn_xp(hero1.xp_to_next)
	t.check(hero1.has_buff("WandPreservationCounter"),
		"+1 level-up keeps the counter (single preservation)")
	hero1.free()

func _test_counter_serialize_round_trip(t: Object) -> void:
	var counter := WandPreservationCounter.new()
	counter.count = 1
	var data: Dictionary = counter.serialize()
	var restored := WandPreservationCounter.new()
	restored.deserialize(data)
	t.check(restored.count == 1,
		"WandPreservationCounter count survives serialize round-trip")
	t.check(not restored.show_in_ui,
		"Counter is hidden from the buff bar")
