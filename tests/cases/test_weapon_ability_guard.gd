extends RefCounted
## Duelist weapon abilities: shield-family Guard (upstream
## RoundShield.guardAbility). Entering the stance costs one charge and one
## turn, applies GuardTracker for 5+lvl (RoundShield) / 3+lvl (Greatshield)
## turns, and blocks all incoming attacks while active. Re-casts prolong
## the stance and reset the blocked marker.

func run(t: Object) -> void:
	_test_ability_data(t)
	_test_guard_applies_stance(t)
	_test_guard_blocks_attacks(t)
	_test_recast_prolongs_and_resets(t)
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

func _make_enemy(level: Level, mob_pos: int, hp: int) -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = maxi(hp, 1)
	mob.hp = hp
	mob.pos = mob_pos
	mob.level = level
	level.add_mob(mob)
	return mob

func _test_ability_data(t: Object) -> void:
	var shield := MeleeWeapon.create("round_shield")
	t.check(shield.has_duelist_ability(), "Round shield has a duelist ability")
	t.check(shield.ability_name() == "Guard", "Round shield ability is Guard")
	t.check(shield.ability_kind() == "guard", "Round shield ability kind is guard")
	t.check(shield.guard_duration() == 5, "Round shield guard lasts 5 turns at +0")
	shield.level = 2
	t.check(shield.guard_duration() == 7, "Round shield guard lasts 5+lvl turns (7 at +2)")
	var greatshield := MeleeWeapon.create("greatshield")
	t.check(greatshield.ability_kind() == "guard", "Greatshield ability kind is guard")
	t.check(greatshield.guard_duration() == 3, "Greatshield guard lasts 3 turns at +0")

func _test_guard_applies_stance(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "round_shield")
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	var guard := hero.get_buff("GuardTracker") as GuardTracker
	t.check(guard != null, "Guard applies the GuardTracker stance")
	if guard != null:
		t.check(guard.get_time_left() == 5.0, "Guard stance lasts 5 turns at +0")
		t.check(not guard.has_blocked, "Fresh guard stance has not blocked yet")
	t.check(charger.charges == 1, "Guard spent one charge")
	t.check(hero._ability_spend == 1.0, "Guard costs one turn")
	hero.free()

func _test_guard_blocks_attacks(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "round_shield")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 100)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	var all_missed := true
	for i in 20:
		if Char.hit(enemy, hero):
			all_missed = false
	t.check(all_missed, "All attack rolls miss a guarding hero")
	var hp_before: int = hero.hp
	enemy.attack(hero)
	t.check(hero.hp == hp_before, "Guarded attack deals no damage")
	var guard := hero.get_buff("GuardTracker") as GuardTracker
	t.check(guard != null and guard.has_blocked, "Blocking an attack marks the stance")
	hero.free()

func _test_recast_prolongs_and_resets(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "round_shield")
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 3
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	var guard := hero.get_buff("GuardTracker") as GuardTracker
	t.check(guard != null, "First cast applies the stance")
	if guard != null:
		guard.time_left = 1.0
		guard.has_blocked = true
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	guard = hero.get_buff("GuardTracker") as GuardTracker
	t.check(guard != null and guard.get_time_left() == 5.0,
			"Re-cast prolongs the stance back to full duration")
	t.check(guard != null and not guard.has_blocked,
			"Re-cast resets the blocked marker")
	t.check(charger.charges == 1, "Each guard cast spends one charge")
	hero.free()

func _test_no_charge_refused(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "round_shield")
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 0
	charger.partial_charge = 0.0
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	t.check(hero.get_buff("GuardTracker") == null, "No-charge guard is refused")
	t.check(hero._ability_spend == 0.0, "No-charge guard refusal costs no time")
	hero.free()
