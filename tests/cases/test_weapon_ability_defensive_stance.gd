extends RefCounted
## Duelist weapon abilities: Quarterstaff Defensive Stance (upstream
## Quarterstaff.duelistAbility). Casting is instant, costs one charge, and
## prolongs the DefensiveStance buff for 3+lvl turns tripling evasion.

func run(t: Object) -> void:
	_test_ability_data(t)
	_test_stance_applies_and_triples_evasion(t)
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
	var staff := MeleeWeapon.create("quarterstaff")
	t.check(staff.has_duelist_ability(), "Quarterstaff has a duelist ability")
	t.check(staff.ability_name() == "Defensive Stance",
			"Quarterstaff ability is Defensive Stance")
	t.check(staff.ability_kind() == "defensive_stance",
			"Quarterstaff ability kind is defensive_stance")
	t.check(staff.defensive_stance_turns() == 3,
			"Defensive stance prolongs 3 turns at +0")
	staff.level = 2
	t.check(staff.defensive_stance_turns() == 5,
			"Defensive stance prolongs 3+lvl turns (5 at +2)")

func _test_stance_applies_and_triples_evasion(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "quarterstaff")
	var eva_before: int = hero.evasion()
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	var stance := hero.get_buff("DefensiveStance") as DefensiveStance
	t.check(stance != null, "Defensive stance applies the DefensiveStance buff")
	if stance != null:
		t.check(stance.get_time_left() == 3.0, "Defensive stance lasts 3 turns at +0")
	t.check(hero.evasion() == eva_before * 3, "Defensive stance triples evasion")
	t.check(charger.charges == 1, "Defensive stance spent one charge")
	t.check(hero._ability_spend == 0.0, "Defensive stance is instant")
	hero.free()

func _test_recast_prolongs(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "quarterstaff")
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 3
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	var stance := hero.get_buff("DefensiveStance") as DefensiveStance
	t.check(stance != null, "First cast applies the stance")
	if stance != null:
		stance.time_left = 1.0
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	stance = hero.get_buff("DefensiveStance") as DefensiveStance
	t.check(stance != null and stance.get_time_left() == 3.0,
			"Re-cast prolongs the stance back to full duration")
	t.check(charger.charges == 1, "Each defensive stance cast spends one charge")
	hero.free()

func _test_no_charge_refused(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "quarterstaff")
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 0
	charger.partial_charge = 0.0
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	t.check(hero.get_buff("DefensiveStance") == null,
			"No-charge defensive stance is refused")
	t.check(hero._ability_spend == 0.0, "No-charge refusal costs no time")
	hero.free()
