extends RefCounted

## Pins Potion of Experience to upstream SPD: PotionOfExperience.apply() calls
## hero.earnExp(hero.maxExp()), granting a FULL current-level's worth of XP
## (maxExp(lvl) == 5 + lvl*5) on top of any partial progress, not merely the
## remainder needed to reach the next level.

func run(t: Object) -> void:
	_test_grants_full_level_worth_preserving_partial(t)
	_test_grant_from_zero_progress_levels_once(t)
	_test_at_max_level_grants_cap_reward(t)


func _make_hero(level: int, xp: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.hero_level = level
	hero.xp_to_next = ConstantsData.xp_for_level(level)
	hero.xp = xp
	return hero


func _test_grants_full_level_worth_preserving_partial(t: Object) -> void:
	# Level 1 hero with 3 partial XP (needs 10 for level 2).
	var hero := _make_hero(1, 3)
	var potion := Potion.create("experience")

	potion.drink(hero)

	# Upstream grants maxExp(1)=10, so total becomes 3+10=13 -> level 2 (needs 15),
	# leaving the pre-existing progress + overflow intact (13-10=3), NOT reset to 0.
	t.check(hero.hero_level == 2, "experience potion levels the hero up")
	t.check(hero.xp == 3, "partial progress + overflow carries (upstream maxExp grant), not reset to 0")
	t.check(hero.xp_to_next == ConstantsData.xp_for_level(2), "xp_to_next reflects the new level")

	hero.free()


func _test_grant_from_zero_progress_levels_once(t: Object) -> void:
	# Level 3 hero, no partial XP: maxExp(3)=20 == the level-3 threshold, so it
	# grants exactly one level with no overflow.
	var hero := _make_hero(3, 0)
	var potion := Potion.create("experience")

	potion.drink(hero)

	t.check(hero.hero_level == 4, "zero-progress hero gains exactly one level")
	t.check(hero.xp == 0, "no overflow when starting from zero progress")

	hero.free()


func _test_at_max_level_grants_cap_reward(t: Object) -> void:
	var hero := _make_hero(ConstantsData.MAX_HERO_LEVEL, 0)
	var potion := Potion.create("experience")

	potion.drink(hero)

	t.check(hero.hero_level == ConstantsData.MAX_HERO_LEVEL, "hero cannot exceed the level cap")
	t.check(hero.xp == 0, "no overflow XP is retained at the level cap")
	t.check(hero.has_buff("Bless"), "a full-level XP grant at the cap triggers the SPD surge-of-power Bless")

	hero.free()
