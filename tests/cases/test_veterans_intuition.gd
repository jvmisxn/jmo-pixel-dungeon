extends RefCounted
## Warrior Veteran's Intuition talent (upstream Talent.VETERANS_INTUITION,
## Talent.onItemEquipped + onTalentUpgraded + itemIDSpeedFactor): armor is
## identified instantly on equip at +2, and reaching +2 retroactively
## identifies the currently worn armor. Port adaptation: no gradual
## usage-based ID system exists, so +1 is a 50% identify-on-equip chance
## instead of upstream's 2x armor ID speed (the melee-weapon 1.75x/2.5x
## speed half has no port analogue and is not ported).

func run(t: Object) -> void:
	_test_registry(t)
	_test_no_points_no_identify(t)
	_test_two_points_identifies_on_equip(t)
	_test_one_point_is_chance_based(t)
	_test_upgrade_to_two_identifies_worn(t)

func _make_warrior(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	if points > 0:
		hero.talent_levels["warrior_veterans_intuition"] = points
	return hero

func _fresh_armor() -> Armor:
	return Armor.create("leather_armor")

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.WARRIOR, "warrior_veterans_intuition"
	)
	t.check(info != null and info.implemented, "Veteran's Intuition is registered and implemented")
	t.check(info != null and info.max_points == 2, "Veteran's Intuition caps at 2 points")
	t.check(info != null and info.tier == 1, "Veteran's Intuition is a tier-1 talent")

func _test_no_points_no_identify(t: Object) -> void:
	var hero := _make_warrior(0)
	var armor: Armor = _fresh_armor()
	t.check(not armor.is_identified(), "Fresh armor starts unidentified")
	hero.belongings.equip_armor(armor)
	t.check(not armor.is_identified(), "No identify on equip without the talent")

func _test_two_points_identifies_on_equip(t: Object) -> void:
	var hero := _make_warrior(2)
	var armor: Armor = _fresh_armor()
	hero.belongings.equip_armor(armor)
	t.check(armor.is_identified(), "+2 identifies armor instantly on equip")

func _test_one_point_is_chance_based(t: Object) -> void:
	var identified_count: int = 0
	for i: int in range(60):
		var hero := _make_warrior(1)
		var armor: Armor = _fresh_armor()
		hero.belongings.equip_armor(armor)
		if armor.is_identified():
			identified_count += 1
	t.check(identified_count > 10, "+1 identifies on equip sometimes (got %d/60)" % identified_count)
	t.check(identified_count < 50, "+1 does not identify on equip always (got %d/60)" % identified_count)

func _test_upgrade_to_two_identifies_worn(t: Object) -> void:
	var hero := _make_warrior(1)
	hero.hero_level = 3
	var armor: Armor = _fresh_armor()
	hero.belongings.equip_armor(armor)
	# The +1 equip roll may already have identified it; force it back to
	# unknown so the retroactive +2 path is what gets exercised.
	armor.level_known = false
	armor.cursed_known = false
	armor.identified = false
	t.check(hero.upgrade_talent("warrior_veterans_intuition"), "Upgrade to +2 succeeds at level 3")
	t.check(armor.is_identified(), "Reaching +2 retroactively identifies worn armor")
