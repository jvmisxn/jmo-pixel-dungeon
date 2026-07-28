extends RefCounted
## Duelist weapon abilities: sword-family Cleave (upstream MeleeWeapon
## AC_ABILITY + Sword.cleaveAbility). Ability data per weapon, charge spend
## via WeaponCharger, guaranteed-hit bonus-damage strike, instant kills that
## open the free-recast CleaveTracker window, refusal guards that cost no
## charge, and the Aggressive Barrier talent shield at half HP.

func run(t: Object) -> void:
	_test_ability_data(t)
	_test_charge_use_and_free_window(t)
	_test_before_ability_spends_charges(t)
	_test_aggressive_barrier(t)
	_test_cleave_hits_with_boost(t)
	_test_cleave_kill_is_instant_and_opens_window(t)
	_test_refusals_cost_nothing(t)

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
	var sword := MeleeWeapon.create("sword")
	t.check(sword.has_duelist_ability(), "Sword has a duelist ability")
	t.check(sword.ability_name() == "Cleave", "Sword ability is Cleave")
	t.check(sword.ability_damage_boost() == 5, "Sword cleave boost is 5 at +0")
	sword.level = 3
	t.check(sword.ability_damage_boost() == 8, "Cleave boost scales with level (5+3)")
	var worn := MeleeWeapon.create("worn_shortsword")
	t.check(worn.ability_damage_boost() == 3, "Worn shortsword boost is 3")
	t.check(MeleeWeapon.create("greatsword").ability_damage_boost() == 7, "Greatsword boost is 7")
	var mace := MeleeWeapon.create("mace")
	t.check(not mace.has_duelist_ability(), "Mace has no ported ability yet")

func _test_charge_use_and_free_window(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "sword")
	var weapon: MeleeWeapon = hero.belongings.weapon as MeleeWeapon
	t.check(weapon.ability_charge_use(hero) == 1.0, "Cleave costs 1 charge normally")
	hero.add_buff(CleaveTracker.new())
	t.check(weapon.ability_charge_use(hero) == 0.0, "Cleave is free inside the CleaveTracker window")
	hero.free()

func _test_before_ability_spends_charges(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "sword")
	var weapon: MeleeWeapon = hero.belongings.weapon as MeleeWeapon
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	charger.partial_charge = 0.25
	weapon.before_ability_used(hero, 1.0)
	t.check(charger.charges == 1, "Charge spend consumes a full charge")
	t.check(absf(charger.partial_charge - 0.25) < 0.001, "Partial charge is preserved across the spend")
	weapon.before_ability_used(hero, 0.0)
	t.check(charger.charges == 1, "Free window spend consumes nothing")
	hero.free()

func _test_aggressive_barrier(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "sword")
	var weapon: MeleeWeapon = hero.belongings.weapon as MeleeWeapon
	hero.talent_levels["duelist_aggressive_barrier"] = 2
	hero.hp = hero.hp_max
	weapon.before_ability_used(hero, 1.0)
	t.check(hero.get_buff("Barrier") == null, "No barrier above half HP")
	hero.hp = hero.hp_max / 2
	weapon.before_ability_used(hero, 0.0)
	var barrier := hero.get_buff("Barrier") as Barrier
	t.check(barrier != null and barrier.get_shielding() == 5, "Aggressive Barrier +2 shields 5 at half HP")
	hero.free()

func _test_cleave_hits_with_boost(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "sword")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(charger.charges == 1, "Cleave spent one charge")
	var dealt: int = 500 - enemy.hp
	t.check(dealt >= 5, "Cleave landed (guaranteed hit) with at least the +5 boost, dealt %d" % dealt)
	t.check(hero._ability_spend > 0.0, "Non-kill cleave costs attack-delay time")
	t.check(hero.get_buff("CleaveTracker") == null, "Non-kill cleave opens no window")
	hero.free()

func _test_cleave_kill_is_instant_and_opens_window(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "sword")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 1)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(not enemy.is_alive, "Cleave killed the 1 HP enemy")
	t.check(hero._ability_spend == 0.0, "Killing cleave is instant")
	t.check(hero.get_buff("CleaveTracker") != null, "Kill opens the CleaveTracker window")
	# Free recast inside the window that also kills: window closes, no charge.
	var enemy2 := _make_enemy(level, ConstantsData.xy_to_pos(5, 6), 1)
	hero._do_weapon_ability(hero.belongings.weapon, enemy2.pos)
	t.check(not enemy2.is_alive, "Free recast killed the second enemy")
	t.check(charger.charges == 1, "Only the first cleave spent a charge")
	t.check(hero.get_buff("CleaveTracker") == null, "Second kill closes the window instead of chaining")
	hero.free()

func _test_refusals_cost_nothing(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "sword")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(9, 5), 50)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 0
	charger.partial_charge = 0.0
	var adjacent := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 50)
	hero._do_weapon_ability(hero.belongings.weapon, adjacent.pos)
	t.check(adjacent.hp == 50, "No charge: ability refused, no strike")
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(enemy.hp == 50 and charger.charges == 2, "Out-of-reach target refused before spending")
	var warrior := Hero.new()
	warrior.init_class(ConstantsData.HeroClass.WARRIOR)
	warrior.level = level
	warrior.pos = ConstantsData.xy_to_pos(5, 5)
	warrior.belongings.weapon = MeleeWeapon.create("sword")
	warrior._do_weapon_ability(warrior.belongings.weapon, adjacent.pos)
	t.check(adjacent.hp == 50, "Non-Duelist gets no weapon ability")
	hero.free()
	warrior.free()
