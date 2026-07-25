extends RefCounted
## Warlock Soul Eater on-kill trigger (upstream Mob loot roll):
## killing a soul marked mob has a points-in-10 chance to fire the hero's
## on-eat talent effects (Talent.onFoodEaten with no actual food). Verified
## through Mob._soul_eater_on_kill with a forced roll so results stay
## deterministic; the on-eat effect is observed via Empowering Meal's
## Recharging buff (the Warlock is a Mage).

func run(t: Object) -> void:
	_test_kill_triggers_on_eat_effects(t)
	_test_roll_at_or_above_points_fails(t)
	_test_zero_points_never_triggers(t)
	_test_unmarked_mob_never_triggers(t)
	_test_non_warlock_never_triggers(t)

func _make_warlock(eater_points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	hero.hero_subclass = ConstantsData.HeroSubclass.WARLOCK
	if eater_points > 0:
		hero.talent_levels["warlock_soul_eater"] = eater_points
	hero.talent_levels["mage_empowering_meal"] = 1
	return hero

func _make_mob(marked: bool) -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = 10
	mob.hp = 10
	if marked:
		mob.add_buff(SoulMark.new())
	return mob

func _with_hero(hero: Hero, body: Callable) -> void:
	var prev: Variant = GameManager.hero
	GameManager.hero = hero
	body.call()
	GameManager.hero = prev

func _test_kill_triggers_on_eat_effects(t: Object) -> void:
	var hero := _make_warlock(2)
	var mob := _make_mob(true)
	_with_hero(hero, func() -> void:
		var fired: bool = mob._soul_eater_on_kill(1)
		t.check(fired, "Roll 1 < 2 points triggers the on-kill effect")
		t.check(hero.has_buff("Recharging"),
			"Trigger fires on-eat talent effects (Empowering Meal Recharging)")
	)
	mob.free()
	hero.free()

func _test_roll_at_or_above_points_fails(t: Object) -> void:
	var hero := _make_warlock(2)
	var mob := _make_mob(true)
	_with_hero(hero, func() -> void:
		t.check(not mob._soul_eater_on_kill(2), "Roll 2 with 2 points does not trigger (points-in-10)")
		t.check(not mob._soul_eater_on_kill(9), "Roll 9 with 2 points does not trigger")
		t.check(not hero.has_buff("Recharging"), "Failed rolls grant no on-eat effects")
	)
	mob.free()
	hero.free()

func _test_zero_points_never_triggers(t: Object) -> void:
	var hero := _make_warlock(0)
	var mob := _make_mob(true)
	_with_hero(hero, func() -> void:
		t.check(not mob._soul_eater_on_kill(0), "Zero Soul Eater points never trigger")
	)
	mob.free()
	hero.free()

func _test_unmarked_mob_never_triggers(t: Object) -> void:
	var hero := _make_warlock(3)
	var mob := _make_mob(false)
	_with_hero(hero, func() -> void:
		t.check(not mob._soul_eater_on_kill(0), "Unmarked mob kills never trigger")
	)
	mob.free()
	hero.free()

func _test_non_warlock_never_triggers(t: Object) -> void:
	var hero := _make_warlock(3)
	hero.hero_subclass = ConstantsData.HeroSubclass.BATTLEMAGE
	var mob := _make_mob(true)
	_with_hero(hero, func() -> void:
		t.check(not mob._soul_eater_on_kill(0), "Non-Warlock subclass never triggers")
	)
	mob.free()
	hero.free()
