extends RefCounted
## Champion off-hand ability path (upstream Belongings.abilityWeapon +
## attackingWeapon + KindOfWeapon.isEquipped covering secondWep): the
## off-hand weapon's duelist ability is usable, its strike routes attack
## math through the off-hand weapon, the override clears once the ability
## resolves, and unequipped backpack weapons still refuse.

func run(t: Object) -> void:
	_test_attacking_weapon_override(t)
	_test_offhand_ability_strikes(t)
	_test_backpack_weapon_refused(t)

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

func _make_champion(level: Level, hero_pos: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.hero_subclass = ConstantsData.HeroSubclass.CHAMPION
	hero.level = level
	hero.pos = hero_pos
	hero.str_val = 20
	hero.belongings.weapon = MeleeWeapon.create("worn_shortsword")
	hero.belongings.second_wep = MeleeWeapon.create("greatsword")
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

func _test_attacking_weapon_override(t: Object) -> void:
	var level := _make_level()
	var hero := _make_champion(level, ConstantsData.xy_to_pos(5, 5))
	var offhand: MeleeWeapon = hero.belongings.second_wep as MeleeWeapon
	t.check(hero.belongings.get_equipped_weapon() == hero.belongings.weapon,
			"Attack math uses the primary weapon normally")
	hero.belongings.ability_weapon = offhand
	t.check(hero.belongings.get_equipped_weapon() == offhand,
			"ability_weapon overrides the attacking weapon during a strike")
	# A heavily upgraded off-hand out-rolls the worn shortsword's whole range,
	# proving damage_roll routes through the override rather than the primary.
	offhand.level = 50
	var worn_max: int = (hero.belongings.weapon as MeleeWeapon).get_damage_range()[1]
	var min_seen: int = 1 << 30
	for _i: int in range(30):
		min_seen = mini(min_seen, hero.damage_roll())
	t.check(min_seen > worn_max,
			"damage_roll uses the off-hand weapon while the override is set (min %d > worn max %d)" % [min_seen, worn_max])
	hero.belongings.ability_weapon = null
	offhand.level = 0
	hero.free()

func _test_offhand_ability_strikes(t: Object) -> void:
	var level := _make_level()
	var hero := _make_champion(level, ConstantsData.xy_to_pos(5, 5))
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	charger.partial_charge = 0.0
	hero._do_weapon_ability(hero.belongings.second_wep, enemy.pos)
	t.check(charger.charges == 1, "Off-hand cleave spent one charge")
	var dealt: int = 500 - enemy.hp
	t.check(dealt >= 7, "Off-hand cleave landed with at least the greatsword +7 boost, dealt %d" % dealt)
	t.check(hero.belongings.ability_weapon == null,
			"The attacking-weapon override is cleared once the ability resolves")
	t.check(hero.belongings.get_equipped_weapon() == hero.belongings.weapon,
			"Attack math is back on the primary weapon after the ability")
	t.check(hero._ability_spend > 0.0, "Non-kill off-hand cleave costs attack-delay time")
	hero.free()

func _test_backpack_weapon_refused(t: Object) -> void:
	var level := _make_level()
	var hero := _make_champion(level, ConstantsData.xy_to_pos(5, 5))
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 50)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	charger.partial_charge = 0.0
	var stashed := MeleeWeapon.create("sword")
	hero.belongings.backpack.append(stashed)
	hero._do_weapon_ability(stashed, enemy.pos)
	t.check(enemy.hp == 50, "A backpack weapon's ability is refused (no strike)")
	t.check(charger.charges == 2, "The refused backpack ability spends no charge")
	hero.free()
