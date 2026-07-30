extends RefCounted
## Duelist weapon abilities: blunt/axe-family Heavy Blow (upstream
## Mace.heavyBlowAbility used by Cudgel/HandAxe/Mace/BattleAxe/WarHammer).
## Guaranteed hit whose flat damage boost only applies against surprised
## targets, Daze on a surviving target, always costs the attack delay, and
## kills open no free-recast window.

func run(t: Object) -> void:
	_test_ability_data(t)
	_test_surprised_hit_gets_boost_and_daze(t)
	_test_aware_hit_gets_no_boost(t)
	_test_kill_costs_time_and_opens_no_window(t)

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
	var mace := MeleeWeapon.create("mace")
	t.check(mace.has_duelist_ability(), "Mace has a duelist ability")
	t.check(mace.ability_name() == "Heavy Blow", "Mace ability is Heavy Blow")
	t.check(mace.ability_kind() == "heavy_blow", "Mace ability kind is heavy_blow")
	t.check(mace.ability_damage_boost() == 5, "Mace boost is 5 at +0")
	mace.level = 3
	t.check(mace.ability_damage_boost() == 10, "Boost scales 1.5x level rounded (5+round(4.5))")
	t.check(MeleeWeapon.create("cudgel").ability_damage_boost() == 3, "Cudgel boost is 3")
	t.check(MeleeWeapon.create("hand_axe").ability_damage_boost() == 4, "Hand axe boost is 4")
	t.check(MeleeWeapon.create("battle_axe").ability_damage_boost() == 5, "Battle axe boost is 5")
	t.check(MeleeWeapon.create("war_hammer").ability_damage_boost() == 6, "War hammer boost is 6")
	t.check(MeleeWeapon.create("greataxe").ability_kind() == "retribution",
			"Greataxe is not in the heavy-blow family (distinct Retribution ability)")
	var mace2 := MeleeWeapon.create("mace")
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.add_buff(CleaveTracker.new())
	t.check(mace2.ability_charge_use(hero) == 1.0,
			"Heavy blow still costs 1 charge inside a cleave window")
	hero.free()

func _test_surprised_hit_gets_boost_and_daze(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "mace")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	# Default mob state is SLEEPING -> surprised by the hero.
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(charger.charges == 1, "Heavy blow spent one charge")
	var dealt: int = 500 - enemy.hp
	t.check(dealt >= 5, "Surprised heavy blow landed with at least the +5 boost, dealt %d" % dealt)
	t.check(enemy.has_buff("Daze"), "Surviving target is dazed")
	t.check(hero._ability_spend > 0.0, "Heavy blow costs attack-delay time")
	hero.free()

func _test_aware_hit_gets_no_boost(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "war_hammer")
	# hp_max huge so the unboosted hit can't kill; state HUNTING + adjacent LOS
	# makes the mob aware -> no bonus damage (upstream surprise gating).
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 5000)
	enemy.state = Mob.AIState.HUNTING
	var weapon: MeleeWeapon = hero.belongings.weapon as MeleeWeapon
	# Pin STR to the exact requirement so no excess-STR bonus muddies the bound.
	hero.str_val = weapon.get_str_requirement()
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	t.check(weapon.ability_damage_boost() == 6, "War hammer boost would be 6")
	var max_unboosted: int = weapon.get_damage_range()[1]
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	var dealt: int = 5000 - enemy.hp
	t.check(dealt >= 1, "Aware heavy blow still lands (guaranteed hit), dealt %d" % dealt)
	t.check(dealt <= max_unboosted, "Aware target takes no flat boost (dealt %d <= max %d)"
			% [dealt, max_unboosted])
	t.check(enemy.has_buff("Daze"), "Aware surviving target is still dazed")
	hero.free()

func _test_kill_costs_time_and_opens_no_window(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "mace")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 1)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(not enemy.is_alive, "Heavy blow killed the 1 HP enemy")
	t.check(hero._ability_spend > 0.0, "Killing heavy blow still costs attack-delay time")
	t.check(hero.get_buff("CleaveTracker") == null, "Heavy blow kill opens no cleave window")
	hero.free()
