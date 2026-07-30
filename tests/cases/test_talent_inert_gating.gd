extends RefCounted
## Inert "groundwork slot" talents are flagged unimplemented so points cannot
## be spent on effects that do not exist yet. Implemented talents keep working.

func run(t: Object) -> void:
	_test_registry_flags(t)
	_test_cannot_upgrade_inert_talent(t)
	_test_implemented_talent_still_upgrades(t)
	_test_subclass_inert_talents_blocked(t)

func _make_warrior() -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.hero_level = 13
	return hero

func _test_registry_flags(t: Object) -> void:
	var runic: TalentData.TalentInfo = TalentData.get_talent(ConstantsData.HeroClass.WARRIOR, "warrior_runic_transference")
	t.check(runic != null and runic.implemented, "Runic Transference is flagged implemented")
	var iron_will: TalentData.TalentInfo = TalentData.get_talent(ConstantsData.HeroClass.WARRIOR, "warrior_iron_will")
	t.check(iron_will != null and iron_will.implemented, "Iron Will is flagged implemented")
	var duelist_barrier: TalentData.TalentInfo = TalentData.get_talent(ConstantsData.HeroClass.DUELIST, "duelist_aggressive_barrier")
	t.check(duelist_barrier != null and duelist_barrier.implemented, "Aggressive Barrier is flagged implemented")
	var implemented_subclass_talents: Array[String] = [
		"berserker_endless_rage",
		"berserker_deathless_fury",
		"berserker_enraged_catalyst",
		"gladiator_cleave",
		"gladiator_lethal_defense",
		"gladiator_enhanced_combo",
		"monk_unencumbered_spirit",
	]
	for subclass: int in [ConstantsData.HeroSubclass.BERSERKER, ConstantsData.HeroSubclass.GLADIATOR, ConstantsData.HeroSubclass.MONK]:
		for talent: TalentData.TalentInfo in TalentData._subclass_talents(subclass):
			if talent.id in implemented_subclass_talents:
				t.check(talent.implemented, "Subclass talent %s is flagged implemented" % talent.id)
			else:
				t.check(not talent.implemented, "Subclass talent %s is flagged unimplemented" % talent.id)

func _test_cannot_upgrade_inert_talent(t: Object) -> void:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.hero_subclass = ConstantsData.HeroSubclass.CHAMPION
	hero.hero_level = 13
	t.check(not hero.can_upgrade_talent("champion_dual_mastery"), "Inert talent cannot be upgraded even with points available")
	var before: int = hero.total_talent_points_available()
	t.check(not hero.upgrade_talent("champion_dual_mastery"), "upgrade_talent refuses inert talents")
	t.check(hero.total_talent_points_available() == before, "No point is consumed by a refused inert upgrade")
	t.check(hero.get_talent_level("champion_dual_mastery") == 0, "Inert talent level stays at 0")
	hero.free()

func _test_implemented_talent_still_upgrades(t: Object) -> void:
	var hero := _make_warrior()
	var before: int = hero.talent_points_available_for(2)
	t.check(hero.can_upgrade_talent("warrior_iron_will"), "Implemented talent remains upgradable")
	t.check(hero.upgrade_talent("warrior_iron_will"), "upgrade_talent succeeds for implemented talents")
	t.check(hero.get_talent_level("warrior_iron_will") == 1, "Implemented talent level increments")
	t.check(hero.talent_points_available_for(2) == before - 1, "Point is spent from the tier-2 bucket")
	hero.free()

func _test_subclass_inert_talents_blocked(t: Object) -> void:
	var hero := _make_warrior()
	hero.hero_subclass = ConstantsData.HeroSubclass.MONK
	t.check(
		not hero.can_upgrade_talent("monk_monastic_vigor"),
		"Inert subclass talent cannot be upgraded"
	)
	hero.hero_subclass = ConstantsData.HeroSubclass.GLADIATOR
	t.check(
		hero.can_upgrade_talent("gladiator_lethal_defense"),
		"Lethal Defense is now upgradable"
	)
	t.check(
		hero.can_upgrade_talent("gladiator_enhanced_combo"),
		"Enhanced Combo is now upgradable"
	)
	hero.hero_subclass = ConstantsData.HeroSubclass.BERSERKER
	t.check(
		hero.can_upgrade_talent("berserker_endless_rage"),
		"Implemented subclass talent (Endless Rage) is upgradable"
	)
	t.check(
		hero.can_upgrade_talent("berserker_enraged_catalyst"),
		"Enraged Catalyst is now upgradable"
	)
	hero.hero_subclass = ConstantsData.HeroSubclass.FREERUNNER
	t.check(
		hero.can_upgrade_talent("freerunner_projectile_momentum"),
		"Projectile Momentum is now upgradable"
	)
	t.check(
		hero.can_upgrade_talent("freerunner_speedy_stealth"),
		"Speedy Stealth is now upgradable"
	)
	t.check(
		hero.can_upgrade_talent("freerunner_evasive_armor"),
		"Evasive Armor is now upgradable"
	)
	hero.free()
