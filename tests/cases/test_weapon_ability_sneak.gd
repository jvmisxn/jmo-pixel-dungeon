extends RefCounted
## Duelist weapon abilities: dagger-family Sneak (upstream Dagger.sneakAbility
## via Dagger/Dirk/AssassinsBlade duelistAbility). Blink to an empty visible
## cell within the family range, instant, spends one charge, grants
## Invisibility for (2+lvl)-1 turns, lands on the tile normally, and refuses
## (costing nothing) when rooted, out of range, blocked, or occupied.

func run(t: Object) -> void:
	_test_ability_data(t)
	_test_sneak_blinks_and_turns_invisible(t)
	_test_sneak_lands_on_terrain(t)
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
	var dagger := MeleeWeapon.create("dagger")
	t.check(dagger.has_duelist_ability(), "Dagger has a duelist ability")
	t.check(dagger.ability_kind() == "sneak", "Dagger ability is sneak")
	t.check(dagger.ability_name() == "Sneak", "Dagger ability name is Sneak")
	t.check(dagger.ability_target_range() == 5, "Dagger sneak range is 5")
	t.check(MeleeWeapon.create("dirk").ability_target_range() == 4, "Dirk sneak range is 4")
	t.check(MeleeWeapon.create("assassins_blade").ability_target_range() == 3,
			"Assassin's blade sneak range is 3")
	t.check(dagger.ability_damage_boost() == 0, "Sneak has no damage boost")
	t.check(dagger.sneak_invis_turns() == 2, "Sneak invisibility is 2 turns at +0")
	dagger.level = 3
	t.check(dagger.sneak_invis_turns() == 5, "Sneak invisibility scales with level (2+3)")
	var sword := MeleeWeapon.create("sword")
	t.check(sword.ability_target_range() == sword.get_reach(),
			"Strike abilities still target within reach")

func _test_sneak_blinks_and_turns_invisible(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "dagger")
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	var target: int = ConstantsData.xy_to_pos(10, 5)
	hero._do_weapon_ability(hero.belongings.weapon, target)
	t.check(hero.pos == target, "Sneak blinked the hero 5 tiles")
	t.check(charger.charges == 1, "Sneak spent one charge")
	t.check(hero._ability_spend == 0.0, "Sneak is instant")
	var invis := hero.get_buff("Invisibility") as Invisibility
	t.check(invis != null, "Sneak grants Invisibility")
	t.check(invis != null and absf(invis.get_time_left() - 1.0) < 0.001,
			"+0 dagger invisibility lasts (2+0)-1 = 1 turn")
	# A longer existing invisibility is postponed, not shortened.
	invis.set_duration(10.0)
	hero._do_weapon_ability(hero.belongings.weapon, ConstantsData.xy_to_pos(9, 5))
	var invis2 := hero.get_buff("Invisibility") as Invisibility
	t.check(invis2 != null and invis2.get_time_left() >= 10.0,
			"Sneak never shortens existing invisibility")
	hero.free()

func _test_sneak_lands_on_terrain(t: Object) -> void:
	var level := _make_level()
	var target: int = ConstantsData.xy_to_pos(7, 5)
	level.map[target] = ConstantsData.Terrain.WATER
	level.build_flag_maps()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "dagger")
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero.add_buff(Burning.new())
	hero._do_weapon_ability(hero.belongings.weapon, target)
	t.check(hero.pos == target, "Sneak landed on the water tile")
	t.check(hero.get_buff("Burning") == null, "Landing in water extinguished burning")
	hero.free()

func _test_refusals_cost_nothing(t: Object) -> void:
	var level := _make_level()
	var wall: int = ConstantsData.xy_to_pos(7, 7)
	level.map[wall] = ConstantsData.Terrain.WALL
	level.build_flag_maps()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "dagger")
	var start: int = hero.pos
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	# Out of range: 6 steps with a 5-range dagger.
	hero._do_weapon_ability(hero.belongings.weapon, ConstantsData.xy_to_pos(11, 5))
	t.check(hero.pos == start and charger.charges == 2, "Out-of-range sneak refused")
	# Impassable target cell.
	hero._do_weapon_ability(hero.belongings.weapon, wall)
	t.check(hero.pos == start and charger.charges == 2, "Sneak into a wall refused")
	# Occupied target cell.
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(7, 5), 50)
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(hero.pos == start and charger.charges == 2, "Sneak onto a mob refused")
	# Rooted hero cannot sneak.
	var rooted := Rooted.new()
	rooted.set_duration(5.0)
	hero.add_buff(rooted)
	hero._do_weapon_ability(hero.belongings.weapon, ConstantsData.xy_to_pos(8, 5))
	t.check(hero.pos == start and charger.charges == 2, "Rooted sneak refused")
	hero.remove_buff(rooted)
	# No charge left.
	charger.charges = 0
	charger.partial_charge = 0.0
	hero._do_weapon_ability(hero.belongings.weapon, ConstantsData.xy_to_pos(8, 5))
	t.check(hero.pos == start, "No-charge sneak refused")
	t.check(hero.get_buff("Invisibility") == null, "Refusals never grant invisibility")
	hero.free()
