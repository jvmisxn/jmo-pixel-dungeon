extends RefCounted
## Flail surprise-attack parity (upstream Hero.canSurpriseAttack): a hero
## wielding a Flail cannot surprise-attack unless the Flail Spin wind-up
## (SpinAbilityTracker) is active. Other weapons keep the STR-only rule.

func run(t: Object) -> void:
	_test_flail_blocks_surprise(t)
	_test_spin_allows_surprise(t)
	_test_str_check_still_applies(t)
	_test_other_weapons_unaffected(t)

func _make_hero(weapon_id: String) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.str_val = 20
	hero.belongings.weapon = MeleeWeapon.create(weapon_id)
	return hero

func _test_flail_blocks_surprise(t: Object) -> void:
	var hero := _make_hero("flail")
	t.check(not hero.can_surprise_attack(),
			"Flail-wielding hero cannot surprise-attack without Spin")

func _test_spin_allows_surprise(t: Object) -> void:
	var hero := _make_hero("flail")
	var spin := SpinAbilityTracker.new()
	spin.spins = 1
	hero.add_buff(spin)
	t.check(hero.can_surprise_attack(),
			"Flail hero can surprise-attack while SpinAbilityTracker is active")

func _test_str_check_still_applies(t: Object) -> void:
	var hero := _make_hero("flail")
	hero.add_buff(SpinAbilityTracker.new())
	hero.str_val = 10
	t.check(not hero.can_surprise_attack(),
			"Under-STR flail hero cannot surprise-attack even while spinning")

func _test_other_weapons_unaffected(t: Object) -> void:
	var hero := _make_hero("sword")
	t.check(hero.can_surprise_attack(),
			"Sword-wielding hero can still surprise-attack normally")
	hero.str_val = 10
	t.check(not hero.can_surprise_attack(),
			"Under-STR hero still cannot surprise-attack with any weapon")
