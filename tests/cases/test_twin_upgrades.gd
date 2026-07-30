extends RefCounted
## Champion Twin Upgrades talent (upstream MeleeWeapon.buffedLvl +
## Talent.TWIN_UPGRADES): while equipped by a Champion with the talent, a
## weapon that is 2/1/0+ tiers lower than the other equipped weapon borrows
## the other weapon's buffed level when it is higher. No talent, wrong tier
## gap, or an already-higher own level leaves the level untouched.

func run(t: Object) -> void:
	_test_talent_registered_live(t)
	_test_boost_applies_with_tier_gap(t)
	_test_tier_gap_scales_with_points(t)
	_test_no_boost_without_talent(t)
	_test_no_boost_when_own_level_higher(t)
	_test_damage_range_uses_boosted_level(t)

func _make_champion(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.hero_subclass = ConstantsData.HeroSubclass.CHAMPION
	if points > 0:
		hero.talent_levels["champion_twin_upgrades"] = points
	return hero

## Registers the hero as the party so the equipped-weapon scan can find it,
## runs the callable, then restores GameManager state.
func _with_party(hero: Hero, body: Callable) -> void:
	var old_heroes: Array[Node] = GameManager.heroes
	var old_hero: Node = GameManager.hero
	GameManager.heroes = [hero] as Array[Node]
	GameManager.hero = hero
	body.call()
	GameManager.heroes = old_heroes
	GameManager.hero = old_hero

func _test_talent_registered_live(t: Object) -> void:
	var talents: Array = TalentData.get_talents_for(
			ConstantsData.HeroClass.DUELIST, ConstantsData.HeroSubclass.CHAMPION)
	var implemented := false
	for talent: TalentData.TalentInfo in talents:
		if talent.id == "champion_twin_upgrades":
			implemented = talent.implemented
	t.check(implemented, "Twin Upgrades is implemented, not inert")

func _test_boost_applies_with_tier_gap(t: Object) -> void:
	var hero := _make_champion(1)
	var greatsword := MeleeWeapon.create("greatsword")  # tier 5
	greatsword.level = 3
	var sword := MeleeWeapon.create("sword")  # tier 3
	hero.belongings.weapon = greatsword
	hero.belongings.second_wep = sword
	_with_party(hero, func() -> void:
		t.check(sword.buffed_lvl() == 3,
				"+1: tier-3 off-hand borrows the tier-5 primary's level")
		t.check(greatsword.buffed_lvl() == 3,
				"Higher weapon keeps its own level")
	)
	hero.free()

func _test_tier_gap_scales_with_points(t: Object) -> void:
	var hero := _make_champion(1)
	var greatsword := MeleeWeapon.create("greatsword")  # tier 5
	greatsword.level = 3
	var longsword := MeleeWeapon.create("longsword")  # tier 4, gap of 1
	hero.belongings.weapon = greatsword
	hero.belongings.second_wep = longsword
	_with_party(hero, func() -> void:
		t.check(longsword.buffed_lvl() == 0,
				"+1: a 1-tier gap is not enough")
		hero.talent_levels["champion_twin_upgrades"] = 2
		t.check(longsword.buffed_lvl() == 3,
				"+2: a 1-tier gap qualifies")
		var second_greatsword := MeleeWeapon.create("greatsword")
		hero.belongings.second_wep = second_greatsword
		t.check(second_greatsword.buffed_lvl() == 0,
				"+2: equal tiers do not qualify")
		hero.talent_levels["champion_twin_upgrades"] = 3
		t.check(second_greatsword.buffed_lvl() == 3,
				"+3: equal tiers qualify")
	)
	hero.free()

func _test_no_boost_without_talent(t: Object) -> void:
	var hero := _make_champion(0)
	var greatsword := MeleeWeapon.create("greatsword")
	greatsword.level = 3
	var sword := MeleeWeapon.create("sword")
	hero.belongings.weapon = greatsword
	hero.belongings.second_wep = sword
	_with_party(hero, func() -> void:
		t.check(sword.buffed_lvl() == 0,
				"No talent points means no borrowed level")
	)
	hero.free()
	# Same gear with no party registered at all: the scan finds no owner.
	t.check(sword.buffed_lvl() == 0, "Unowned weapon keeps its own level")

func _test_no_boost_when_own_level_higher(t: Object) -> void:
	var hero := _make_champion(3)
	var greatsword := MeleeWeapon.create("greatsword")
	greatsword.level = 1
	var sword := MeleeWeapon.create("sword")
	sword.level = 4
	hero.belongings.weapon = greatsword
	hero.belongings.second_wep = sword
	_with_party(hero, func() -> void:
		t.check(sword.buffed_lvl() == 4,
				"Lower-tier weapon already at a higher level keeps it")
		t.check(greatsword.buffed_lvl() == 1,
				"Higher-tier weapon never borrows upward")
	)
	hero.free()

func _test_damage_range_uses_boosted_level(t: Object) -> void:
	var hero := _make_champion(1)
	var greatsword := MeleeWeapon.create("greatsword")
	greatsword.level = 3
	var sword := MeleeWeapon.create("sword")
	hero.belongings.weapon = greatsword
	hero.belongings.second_wep = sword
	_with_party(hero, func() -> void:
		var range_boosted: Array[int] = sword.get_damage_range()
		# Tier 3 at effective level 3: min = 3 + 3, max = 5*4 + 3*4.
		t.check(range_boosted[0] == 6 and range_boosted[1] == 32,
				"Damage range reflects the borrowed level")
	)
	hero.free()
