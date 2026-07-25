extends RefCounted
## Assassin Bounty Hunter talent (upstream Mob.lootChance drop bonus):
## killing an enemy with a preparation-empowered attack boosts its loot
## drop chance by 2/4/8/16% per preparation level, multiplied by talent
## points. Verified through AssassinPreparation.bounty_hunter_bonus and
## Mob._loot_chance_multiplier so results stay deterministic.

func run(t: Object) -> void:
	_test_bonus_scales_with_prep_level(t)
	_test_bonus_scales_with_points(t)
	_test_no_talent_no_bonus(t)
	_test_mob_multiplier_uses_killer_prep(t)
	_test_mob_multiplier_ignores_unprepared_killers(t)

func _make_assassin(points: int, turns_invis: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	hero.hero_subclass = ConstantsData.HeroSubclass.ASSASSIN
	if points > 0:
		hero.talent_levels["assassin_bounty_hunter"] = points
	var prep := AssassinPreparation.new()
	prep.turns_invis = turns_invis
	hero.add_buff(prep)
	return hero

func _prep(hero: Hero) -> AssassinPreparation:
	return hero.get_buff("AssassinPreparation") as AssassinPreparation

func _test_bonus_scales_with_prep_level(t: Object) -> void:
	var hero := _make_assassin(1, 1)
	var prep := _prep(hero)
	t.check(is_equal_approx(prep.bounty_hunter_bonus(), 0.02),
		"Prep level 1 with 1 point gives a 2% bonus")
	prep.turns_invis = 3
	t.check(is_equal_approx(prep.bounty_hunter_bonus(), 0.04),
		"Prep level 2 gives a 4% bonus")
	prep.turns_invis = 5
	t.check(is_equal_approx(prep.bounty_hunter_bonus(), 0.08),
		"Prep level 3 gives an 8% bonus")
	prep.turns_invis = 9
	t.check(is_equal_approx(prep.bounty_hunter_bonus(), 0.16),
		"Prep level 4 gives a 16% bonus")
	hero.free()

func _test_bonus_scales_with_points(t: Object) -> void:
	var hero := _make_assassin(3, 9)
	var prep := _prep(hero)
	t.check(is_equal_approx(prep.bounty_hunter_bonus(), 0.48),
		"3 points at full preparation give a 48% bonus (16% x 3)")
	hero.free()

func _test_no_talent_no_bonus(t: Object) -> void:
	var hero := _make_assassin(0, 9)
	var prep := _prep(hero)
	t.check(is_equal_approx(prep.bounty_hunter_bonus(), 0.0),
		"No talent points means no bonus even at full preparation")
	hero.free()

func _test_mob_multiplier_uses_killer_prep(t: Object) -> void:
	var hero := _make_assassin(2, 5)
	var mob := Mob.new()
	t.check(is_equal_approx(mob._loot_chance_multiplier(hero), 1.16),
		"Prepared Bounty Hunter killer multiplies loot chance (1 + 8% x 2)")
	mob.free()
	hero.free()

func _test_mob_multiplier_ignores_unprepared_killers(t: Object) -> void:
	var mob := Mob.new()
	t.check(is_equal_approx(mob._loot_chance_multiplier(null), 1.0),
		"No killer means no bonus")
	var plain := Hero.new()
	plain.init_class(ConstantsData.HeroClass.ROGUE)
	t.check(is_equal_approx(mob._loot_chance_multiplier(plain), 1.0),
		"A hero without Preparation gets no bonus")
	var attacker := Mob.new()
	t.check(is_equal_approx(mob._loot_chance_multiplier(attacker), 1.0),
		"Mob killers get no bonus")
	attacker.free()
	plain.free()
	mob.free()
