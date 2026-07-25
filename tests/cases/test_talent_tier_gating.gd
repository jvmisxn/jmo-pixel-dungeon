extends RefCounted
## Talent tiers unlock by hero level, matching upstream
## Talent.tierLevelThresholds: tiers 1/2/3/4 start at levels 2/7/13/21.

func run(t: Object) -> void:
	_test_thresholds(t)
	_test_tier1_locked_at_level_1(t)
	_test_tier2_locked_until_level_7(t)
	_test_tier3_locked_until_level_13(t)
	_test_locked_upgrade_refused_without_spending(t)

func _make_warrior(level: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.hero_level = level
	hero.talent_points_available = 5
	return hero

func _test_thresholds(t: Object) -> void:
	t.check(TalentData.tier_unlock_level(1) == 2, "Tier 1 unlocks at level 2")
	t.check(TalentData.tier_unlock_level(2) == 7, "Tier 2 unlocks at level 7")
	t.check(TalentData.tier_unlock_level(3) == 13, "Tier 3 unlocks at level 13")
	t.check(TalentData.tier_unlock_level(4) == 21, "Tier 4 unlocks at level 21")
	t.check(TalentData.tier_unlock_level(0) == 21, "Out-of-range tier falls back to the top threshold")
	t.check(TalentData.tier_unlock_level(9) == 21, "Out-of-range tier falls back to the top threshold")

func _test_tier1_locked_at_level_1(t: Object) -> void:
	var hero := _make_warrior(1)
	t.check(not hero.can_upgrade_talent("warrior_hearty_meal"), "Tier 1 talent locked at level 1")
	hero.hero_level = 2
	t.check(hero.can_upgrade_talent("warrior_hearty_meal"), "Tier 1 talent unlocked at level 2")
	hero.free()

func _test_tier2_locked_until_level_7(t: Object) -> void:
	var hero := _make_warrior(6)
	t.check(hero.can_upgrade_talent("warrior_hearty_meal"), "Tier 1 talent open at level 6")
	t.check(not hero.can_upgrade_talent("warrior_iron_will"), "Tier 2 talent locked at level 6")
	hero.hero_level = 7
	t.check(hero.can_upgrade_talent("warrior_iron_will"), "Tier 2 talent unlocked at level 7")
	hero.free()

func _test_tier3_locked_until_level_13(t: Object) -> void:
	var hero := _make_warrior(12)
	hero.hero_subclass = ConstantsData.HeroSubclass.BERSERKER
	var locked: bool = not hero.can_upgrade_talent("berserker_endless_rage")
	t.check(locked, "Tier 3 locked at level 12 with subclass")
	hero.hero_level = 13
	t.check(hero.can_upgrade_talent("berserker_endless_rage"), "Tier 3 talent unlocked at level 13")
	hero.free()

func _test_locked_upgrade_refused_without_spending(t: Object) -> void:
	var hero := _make_warrior(3)
	var before: int = hero.talent_points_available
	var refused: bool = not hero.upgrade_talent("warrior_iron_will")
	t.check(refused, "upgrade_talent refuses a locked-tier talent")
	t.check(hero.talent_points_available == before, "No point consumed by a refused locked upgrade")
	t.check(hero.get_talent_level("warrior_iron_will") == 0, "Locked talent level stays at 0")
	hero.free()
