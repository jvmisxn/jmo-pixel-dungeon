extends RefCounted
## Monk tier-3 talents going live (upstream Talent.MONASTIC_VIGOR +
## Talent.COMBINED_ENERGY). Monastic Vigor lowers the abilitiesEmpowered
## energy threshold to 100%/80%/60% of cap. Combined Energy refunds 1
## energy when a qualifying monk ability (cost >= 5 - points) and a weapon
## ability are used within 5 turns of each other, in either order, via the
## shared CombinedEnergyAbilityTracker.

func run(t: Object) -> void:
	_test_talents_registered(t)
	_test_monastic_vigor_thresholds(t)
	_test_monk_then_weapon_refunds(t)
	_test_weapon_then_monk_refunds(t)
	_test_cheap_monk_ability_does_not_qualify(t)
	_test_no_talent_no_tracker(t)
	_test_tracker_serialize_roundtrip(t)

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

func _make_monk(level: Level, combined_points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.hero_subclass = ConstantsData.HeroSubclass.MONK
	if combined_points > 0:
		hero.talent_levels["monk_combined_energy"] = combined_points
	hero.level = level
	hero.pos = ConstantsData.xy_to_pos(5, 5)
	return hero

func _energy_of(hero: Hero, amount: float) -> MonkEnergy:
	var energy: MonkEnergy = hero.get_buff("MonkEnergy") as MonkEnergy
	if energy == null:
		energy = hero.add_buff(MonkEnergy.new()) as MonkEnergy
	energy.energy = amount
	return energy

func _test_talents_registered(t: Object) -> void:
	var talents: Array = TalentData.get_talents_for(
			ConstantsData.HeroClass.DUELIST, ConstantsData.HeroSubclass.MONK)
	var vigor_implemented := false
	var combined_implemented := false
	for talent: TalentData.TalentInfo in talents:
		if talent.id == "monk_monastic_vigor":
			vigor_implemented = talent.implemented
		elif talent.id == "monk_combined_energy":
			combined_implemented = talent.implemented
	t.check(vigor_implemented, "Monastic Vigor is implemented, not inert")
	t.check(combined_implemented, "Combined Energy is implemented, not inert")

func _test_monastic_vigor_thresholds(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, 0)
	hero.hero_level = 10  # cap = 10
	var energy := _energy_of(hero, 10.0)
	t.check(not energy.abilities_empowered(),
			"Full energy is not empowered without Monastic Vigor")
	hero.talent_levels["monk_monastic_vigor"] = 1
	t.check(energy.abilities_empowered(), "+1: 100% of cap empowers")
	energy.energy = 9.9
	t.check(not energy.abilities_empowered(), "+1: below 100% does not")
	hero.talent_levels["monk_monastic_vigor"] = 2
	energy.energy = 8.0
	t.check(energy.abilities_empowered(), "+2: 80% of cap empowers")
	hero.talent_levels["monk_monastic_vigor"] = 3
	energy.energy = 6.0
	t.check(energy.abilities_empowered(), "+3: 60% of cap empowers")
	energy.energy = 5.9
	t.check(not energy.abilities_empowered(), "+3: below 60% does not")
	hero.free()

func _test_monk_then_weapon_refunds(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, 3)
	var energy := _energy_of(hero, 10.0)
	energy.ability_used(3.0)  # Dash; qualifies at +3 (cost >= 2)
	t.check(absf(energy.energy - 7.0) < 0.001, "Monk ability spends its cost")
	var tracker := hero.get_buff("CombinedEnergyAbilityTracker") as CombinedEnergyAbilityTracker
	t.check(tracker != null and tracker.monk_abil_used and not tracker.wep_abil_used,
			"Qualifying monk ability arms the tracker")
	var weapon: MeleeWeapon = MeleeWeapon.create("scimitar")
	weapon.before_ability_used(hero, 1.0)
	t.check(absf(energy.energy - 8.0) < 0.001,
			"Weapon ability after monk ability refunds 1 energy")
	t.check(hero.get_buff("CombinedEnergyAbilityTracker") == null,
			"Refund consumes the tracker")
	hero.free()

func _test_weapon_then_monk_refunds(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, 3)
	var energy := _energy_of(hero, 10.0)
	var weapon: MeleeWeapon = MeleeWeapon.create("scimitar")
	weapon.before_ability_used(hero, 1.0)
	var tracker := hero.get_buff("CombinedEnergyAbilityTracker") as CombinedEnergyAbilityTracker
	t.check(tracker != null and tracker.wep_abil_used and not tracker.monk_abil_used,
			"Weapon ability arms the tracker")
	energy.ability_used(4.0)  # Dragon Kick
	t.check(absf(energy.energy - 7.0) < 0.001,
			"Monk ability after weapon ability nets cost minus 1 refund")
	t.check(hero.get_buff("CombinedEnergyAbilityTracker") == null,
			"Refund consumes the tracker")
	hero.free()

func _test_cheap_monk_ability_does_not_qualify(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, 1)  # threshold: cost >= 4
	var energy := _energy_of(hero, 10.0)
	energy.ability_used(3.0)
	t.check(hero.get_buff("CombinedEnergyAbilityTracker") == null,
			"+1: a 3-cost monk ability does not arm the tracker")
	var weapon: MeleeWeapon = MeleeWeapon.create("scimitar")
	weapon.before_ability_used(hero, 1.0)
	energy.ability_used(3.0)
	t.check(absf(energy.energy - 4.0) < 0.001,
			"+1: a 3-cost monk ability earns no refund from a pending weapon ability")
	hero.free()

func _test_no_talent_no_tracker(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, 0)
	var energy := _energy_of(hero, 10.0)
	energy.ability_used(5.0)
	var weapon: MeleeWeapon = MeleeWeapon.create("scimitar")
	weapon.before_ability_used(hero, 1.0)
	t.check(hero.get_buff("CombinedEnergyAbilityTracker") == null,
			"No tracker without the talent")
	t.check(absf(energy.energy - 5.0) < 0.001, "No refund without the talent")
	hero.free()

func _test_tracker_serialize_roundtrip(t: Object) -> void:
	var tracker := CombinedEnergyAbilityTracker.new()
	tracker.monk_abil_used = true
	var data: Dictionary = tracker.serialize()
	var restored := CombinedEnergyAbilityTracker.new()
	restored.deserialize(data)
	t.check(restored.monk_abil_used and not restored.wep_abil_used,
			"Tracker flags survive serialize/deserialize")
	tracker.free()
	restored.free()
