extends RefCounted
## Per-tier talent point buckets, matching upstream Hero.talentPointsAvailable /
## talentPointsSpent: each tier earns one point per hero level inside its own
## band (tier 1: levels 2-6, tier 2: 7-12, tier 3: 13-20), minus points spent in
## that tier. Tier 3 requires a subclass; tier 4 (armor abilities) is not ported.

func run(t: Object) -> void:
	_test_earned_per_band(t)
	_test_band_caps(t)
	_test_spent_subtracts_within_tier_only(t)
	_test_tier3_requires_subclass(t)
	_test_upgrade_refused_when_tier_bucket_empty(t)
	_test_overspent_tier_clamps_to_zero(t)
	_test_total_sums_tiers(t)

func _make_warrior(level: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.hero_level = level
	return hero

func _test_earned_per_band(t: Object) -> void:
	var hero := _make_warrior(1)
	t.check(hero.talent_points_available_for(1) == 0, "No tier-1 points at level 1")
	hero.hero_level = 2
	t.check(hero.talent_points_available_for(1) == 1, "One tier-1 point at level 2")
	t.check(hero.talent_points_available_for(2) == 0, "No tier-2 points at level 2")
	hero.hero_level = 4
	t.check(hero.talent_points_available_for(1) == 3, "Three tier-1 points at level 4")
	hero.hero_level = 7
	t.check(hero.talent_points_available_for(2) == 1, "One tier-2 point at level 7")
	hero.free()

func _test_band_caps(t: Object) -> void:
	var hero := _make_warrior(30)
	t.check(hero.talent_points_available_for(1) == 5, "Tier 1 caps at 5 points (levels 2-6)")
	t.check(hero.talent_points_available_for(2) == 6, "Tier 2 caps at 6 points (levels 7-12)")
	hero.hero_subclass = ConstantsData.HeroSubclass.BERSERKER
	t.check(hero.talent_points_available_for(3) == 8, "Tier 3 caps at 8 points (levels 13-20)")
	t.check(hero.talent_points_available_for(4) == 0, "Tier 4 yields no points (armor abilities not ported)")
	hero.free()

func _test_spent_subtracts_within_tier_only(t: Object) -> void:
	var hero := _make_warrior(10)
	var t1_before: int = hero.talent_points_available_for(1)
	t.check(hero.upgrade_talent("warrior_iron_will"), "Tier-2 upgrade succeeds with tier-2 points")
	t.check(hero.talent_points_spent(2) == 1, "Spent count tracks the tier-2 point")
	t.check(hero.talent_points_available_for(2) == 3, "Tier-2 bucket at level 10 is 4 minus 1 spent")
	t.check(hero.talent_points_available_for(1) == t1_before, "Tier-1 bucket is untouched by tier-2 spending")
	hero.free()

func _test_tier3_requires_subclass(t: Object) -> void:
	var hero := _make_warrior(15)
	t.check(hero.talent_points_available_for(3) == 0, "No tier-3 points without a subclass")
	hero.hero_subclass = ConstantsData.HeroSubclass.BERSERKER
	t.check(hero.talent_points_available_for(3) == 3, "Tier-3 points appear once subclassed (level 15 = 3)")
	hero.free()

func _test_upgrade_refused_when_tier_bucket_empty(t: Object) -> void:
	var hero := _make_warrior(7)
	t.check(hero.upgrade_talent("warrior_iron_will"), "First tier-2 upgrade spends the only tier-2 point")
	t.check(hero.talent_points_available_for(1) > 0, "Tier-1 points remain available")
	t.check(not hero.can_upgrade_talent("warrior_iron_will"), "Empty tier-2 bucket blocks upgrades despite tier-1 points")
	hero.free()

func _test_overspent_tier_clamps_to_zero(t: Object) -> void:
	# A pre-bucket save could hold more points in one tier than its band earns.
	var hero := _make_warrior(3)
	hero.talent_levels["warrior_hearty_meal"] = 2
	hero.talent_levels["warrior_tested_hypothesis"] = 2
	t.check(hero.talent_points_spent(1) == 4, "Spent counts both tier-1 talents")
	t.check(hero.talent_points_available_for(1) == 0, "Overspent tier clamps to zero, never negative")
	hero.free()

func _test_total_sums_tiers(t: Object) -> void:
	var hero := _make_warrior(8)
	var expected: int = hero.talent_points_available_for(1) + hero.talent_points_available_for(2)
	t.check(hero.total_talent_points_available() == expected, "Total is the sum of per-tier buckets")
	t.check(expected == 7, "Level 8 warrior has 5 tier-1 + 2 tier-2 points")
	hero.free()
