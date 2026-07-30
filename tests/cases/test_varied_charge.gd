extends RefCounted
## Champion Varied Charge talent (upstream Talent.VARIED_CHARGE +
## MeleeWeapon.afterAbilityUsed + Talent.VariedChargeTracker). Using two
## different weapon abilities instantly refunds points/6 weapon charge;
## same-weapon abilities just keep the tracker pointed at that weapon.

func run(t: Object) -> void:
	_test_talent_registered(t)
	_test_same_weapon_no_refund(t)
	_test_different_weapon_refunds(t)
	_test_tracker_rearms_after_trigger(t)
	_test_no_talent_no_tracker(t)
	_test_save_migration(t)

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 2
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	level.visible.resize(ConstantsData.LENGTH)
	level.visible.fill(true)
	return level

func _make_champion(level: Level, points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.hero_subclass = ConstantsData.HeroSubclass.CHAMPION
	if points > 0:
		hero.talent_levels["champion_varied_charge"] = points
	hero.level = level
	hero.pos = ConstantsData.xy_to_pos(5, 5)
	hero.str_val = 22
	hero.belongings.weapon = MeleeWeapon.create("scimitar")
	return hero

func _cast(hero: Hero, weapon_id: String) -> void:
	hero.belongings.weapon = MeleeWeapon.create(weapon_id)
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)

func _test_talent_registered(t: Object) -> void:
	var talents: Array = TalentData.get_talents_for(
			ConstantsData.HeroClass.DUELIST, ConstantsData.HeroSubclass.CHAMPION)
	var ids: Array[String] = []
	var varied_implemented := false
	for talent: TalentData.TalentInfo in talents:
		ids.append(talent.id)
		if talent.id == "champion_varied_charge":
			varied_implemented = talent.implemented
	t.check(ids.has("champion_varied_charge"), "Champion has Varied Charge talent")
	t.check(varied_implemented, "Varied Charge is implemented, not inert")
	t.check(ids.has("champion_twin_upgrades"), "Champion has Twin Upgrades slot")
	t.check(ids.has("champion_combined_lethality"), "Champion has Combined Lethality slot")
	t.check(not ids.has("champion_dual_mastery"), "Old Dual Mastery slot is gone")

func _test_same_weapon_no_refund(t: Object) -> void:
	var level := _make_level()
	var hero := _make_champion(level, 3)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 3
	charger.partial_charge = 0.0
	_cast(hero, "scimitar")
	var tracker := hero.get_buff("VariedChargeTracker") as VariedChargeTracker
	t.check(tracker != null, "First ability use arms the tracker")
	t.check(tracker.weapon_id == "scimitar", "Tracker records the scimitar")
	_cast(hero, "scimitar")
	tracker = hero.get_buff("VariedChargeTracker") as VariedChargeTracker
	t.check(tracker != null and tracker.weapon_id == "scimitar",
			"Same-weapon ability keeps the tracker on the scimitar")
	t.check(charger.charges == 1 and absf(charger.partial_charge) < 0.001,
			"Same-weapon abilities refund nothing (2 casts spent 2 charges)")
	hero.free()

func _test_different_weapon_refunds(t: Object) -> void:
	var level := _make_level()
	var hero := _make_champion(level, 3)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 3
	charger.partial_charge = 0.0
	_cast(hero, "scimitar")
	_cast(hero, "quarterstaff")
	t.check(hero.get_buff("VariedChargeTracker") == null,
			"Different-weapon ability consumes the tracker")
	t.check(charger.charges == 1 and absf(charger.partial_charge - 0.5) < 0.001,
			"Varied Charge +3 refunds 0.5 charge (got %d + %.3f)"
			% [charger.charges, charger.partial_charge])
	hero.free()

func _test_tracker_rearms_after_trigger(t: Object) -> void:
	var level := _make_level()
	var hero := _make_champion(level, 1)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 4
	charger.partial_charge = 0.0
	_cast(hero, "scimitar")
	_cast(hero, "quarterstaff")
	t.check(hero.get_buff("VariedChargeTracker") == null,
			"Trigger leaves no tracker behind")
	_cast(hero, "quarterstaff")
	var tracker := hero.get_buff("VariedChargeTracker") as VariedChargeTracker
	t.check(tracker != null and tracker.weapon_id == "quarterstaff",
			"Next ability after a trigger re-arms the tracker fresh")
	t.check(absf(charger.partial_charge - 1.0 / 6.0) < 0.001,
			"Varied Charge +1 refunded 1/6 charge exactly once")
	hero.free()

func _test_no_talent_no_tracker(t: Object) -> void:
	var level := _make_level()
	var hero := _make_champion(level, 0)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 3
	charger.partial_charge = 0.0
	_cast(hero, "scimitar")
	_cast(hero, "quarterstaff")
	t.check(hero.get_buff("VariedChargeTracker") == null,
			"Without talent points no tracker is ever attached")
	t.check(charger.charges == 1 and absf(charger.partial_charge) < 0.001,
			"Without talent points nothing is refunded")
	hero.free()

func _test_save_migration(t: Object) -> void:
	var level := _make_level()
	var hero := _make_champion(level, 0)
	var data: Dictionary = hero.serialize()
	data["talent_levels"] = {"champion_dual_mastery": 2, "champion_guarded_offense": 1}
	var loaded := Hero.new()
	loaded.deserialize(data)
	t.check(loaded.get_talent_level("champion_varied_charge") == 2,
			"Old Dual Mastery points migrate to Varied Charge")
	t.check(loaded.get_talent_level("champion_twin_upgrades") == 1,
			"Old Guarded Offense points migrate to Twin Upgrades")
	t.check(not loaded.talent_levels.has("champion_dual_mastery"),
			"Retired Champion talent ids are removed on load")
	hero.free()
	loaded.free()
