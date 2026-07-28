extends RefCounted
## Duelist weapon abilities: Scimitar Sword Dance (upstream
## Scimitar.duelistAbility). Casting is instant, costs one charge, and
## prolongs the SwordDance stance for 3+lvl turns granting 1.5x accuracy
## and +0.6 to the attack-speed multiplier (additive with Ring of Furor).

func run(t: Object) -> void:
	_test_ability_data(t)
	_test_dance_applies_stance(t)
	_test_stance_modifiers(t)
	_test_recast_prolongs(t)
	_test_no_charge_refused(t)

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 2
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	level.visible.resize(ConstantsData.LENGTH)
	level.visible.fill(true)
	return level

func _make_duelist(level: Level, hero_pos: int, weapon_id: String) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.level = level
	hero.pos = hero_pos
	hero.str_val = 20
	var weapon := MeleeWeapon.create(weapon_id)
	hero.belongings.weapon = weapon
	return hero

func _test_ability_data(t: Object) -> void:
	var scimitar := MeleeWeapon.create("scimitar")
	t.check(scimitar.has_duelist_ability(), "Scimitar has a duelist ability")
	t.check(scimitar.ability_name() == "Sword Dance", "Scimitar ability is Sword Dance")
	t.check(scimitar.ability_kind() == "sword_dance", "Scimitar ability kind is sword_dance")
	t.check(scimitar.sword_dance_turns() == 3, "Sword dance prolongs 3 turns at +0")
	scimitar.level = 2
	t.check(scimitar.sword_dance_turns() == 5, "Sword dance prolongs 3+lvl turns (5 at +2)")

func _test_dance_applies_stance(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "scimitar")
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	var dance := hero.get_buff("SwordDance") as SwordDance
	t.check(dance != null, "Sword dance applies the SwordDance stance")
	if dance != null:
		t.check(dance.get_time_left() == 3.0, "Sword dance stance lasts 3 turns at +0")
	t.check(charger.charges == 1, "Sword dance spent one charge")
	t.check(hero._ability_spend == 0.0, "Sword dance is instant")
	hero.free()

func _test_stance_modifiers(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "scimitar")
	var acc_before: int = hero.accuracy()
	var delay_before: float = hero._get_attack_delay()
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	t.check(hero.accuracy() == roundi(float(acc_before) * 1.5),
			"Sword dance grants 1.5x accuracy")
	var delay_after: float = hero._get_attack_delay()
	t.check(absf(delay_after - delay_before / 1.6) < 0.001,
			"Sword dance divides the attack delay by 1.6 without furor")
	hero.free()

func _test_recast_prolongs(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "scimitar")
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 3
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	var dance := hero.get_buff("SwordDance") as SwordDance
	t.check(dance != null, "First cast applies the stance")
	if dance != null:
		dance.time_left = 1.0
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	dance = hero.get_buff("SwordDance") as SwordDance
	t.check(dance != null and dance.get_time_left() == 3.0,
			"Re-cast prolongs the stance back to full duration")
	t.check(charger.charges == 1, "Each sword dance cast spends one charge")
	hero.free()

func _test_no_charge_refused(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "scimitar")
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 0
	charger.partial_charge = 0.0
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	t.check(hero.get_buff("SwordDance") == null, "No-charge sword dance is refused")
	t.check(hero._ability_spend == 0.0, "No-charge refusal costs no time")
	hero.free()
