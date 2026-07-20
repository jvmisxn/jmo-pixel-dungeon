extends RefCounted

func run(t: Object) -> void:
	_test_xp_stays_bounded_at_level_cap(t)
	_test_large_xp_grant_caps_at_max_level(t)


func _test_xp_stays_bounded_at_level_cap(t: Object) -> void:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.hero_level = ConstantsData.MAX_HERO_LEVEL
	hero.xp_to_next = ConstantsData.xp_for_level(hero.hero_level)
	hero.xp = hero.xp_to_next - 1

	hero.earn_xp(1)

	t.check(hero.hero_level == ConstantsData.MAX_HERO_LEVEL, "hero remains at max level after capped XP")
	t.check(hero.xp == 0, "XP resets instead of growing beyond the max-level threshold")
	t.check(hero.has_buff("Bless"), "level-cap XP grants Bless as the SPD cap reward")

	hero.free()


func _test_large_xp_grant_caps_at_max_level(t: Object) -> void:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.hero_level = ConstantsData.MAX_HERO_LEVEL - 1
	hero.xp_to_next = ConstantsData.xp_for_level(hero.hero_level)
	hero.xp = hero.xp_to_next - 1

	hero.earn_xp(hero.xp_to_next * 3)

	t.check(hero.hero_level == ConstantsData.MAX_HERO_LEVEL, "large XP grant cannot level past max")
	t.check(hero.xp == 0, "large XP grant does not leave overflow XP at max level")
	t.check(hero.has_buff("Bless"), "overflow at max level still grants the cap reward")

	hero.free()
