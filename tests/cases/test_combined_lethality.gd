extends RefCounted
## Champion Combined Lethality (upstream Talent.COMBINED_LETHALITY):
## a weapon ability arms CombinedLethalityAbilityTracker; a melee hit with a
## different weapon executes non-boss enemies at or below 0.4*points/3 of max
## HP and consumes the tracker either way. Same-weapon abilities just re-arm.

func run(t: Object) -> void:
	_test_ability_arms_tracker(t)
	_test_differing_hit_executes(t)
	_test_threshold_and_boss_gates(t)
	_test_offhand_ability_chain(t)

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

func _make_champion(level: Level, hero_pos: int, points: int = 3) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.hero_subclass = ConstantsData.HeroSubclass.CHAMPION
	hero.level = level
	hero.pos = hero_pos
	hero.str_val = 20
	hero.belongings.weapon = MeleeWeapon.create("worn_shortsword")
	hero.belongings.second_wep = MeleeWeapon.create("greatsword")
	hero.talent_levels["champion_combined_lethality"] = points
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	if charger != null:
		charger.charges = 5
		charger.partial_charge = 0.0
	return hero

func _make_enemy(level: Level, mob_pos: int, hp: int, hp_max: int) -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = hp_max
	mob.hp = hp
	mob.pos = mob_pos
	mob.level = level
	level.add_mob(mob)
	return mob

func _test_ability_arms_tracker(t: Object) -> void:
	var level := _make_level()
	var hero := _make_champion(level, ConstantsData.xy_to_pos(5, 5))
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500, 500)
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	var tracker := hero.get_buff("CombinedLethalityAbilityTracker") \
			as CombinedLethalityAbilityTracker
	t.check(tracker != null, "A weapon ability arms the tracker")
	t.check(tracker != null and tracker.weapon == hero.belongings.weapon,
			"The tracker records the ability weapon")
	# Same-weapon ability keeps/re-arms the tracker instead of consuming it.
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	tracker = hero.get_buff("CombinedLethalityAbilityTracker") \
			as CombinedLethalityAbilityTracker
	t.check(tracker != null and tracker.weapon == hero.belongings.weapon,
			"A same-weapon ability re-arms rather than consumes the tracker")
	hero.free()

func _test_differing_hit_executes(t: Object) -> void:
	var level := _make_level()
	var hero := _make_champion(level, ConstantsData.xy_to_pos(5, 5))
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 150, 500)
	# Arm as if the off-hand's ability was used; a regular attack always uses
	# the primary weapon, which differs -> execute at 30% <= 40% (3 points).
	var tracker: CombinedLethalityAbilityTracker = hero.add_buff(
			CombinedLethalityAbilityTracker.new()) as CombinedLethalityAbilityTracker
	tracker.weapon = hero.belongings.second_wep
	hero.attack(enemy)
	t.check(not enemy.is_alive or enemy.hp == 0,
			"A differing-weapon hit executes an enemy under the HP threshold")
	t.check(hero.get_buff("CombinedLethalityAbilityTracker") == null,
			"The tracker is consumed by the executing hit")
	hero.free()

func _test_threshold_and_boss_gates(t: Object) -> void:
	var level := _make_level()
	var hero := _make_champion(level, ConstantsData.xy_to_pos(5, 5))
	# 60% HP is above the 3-point 40% threshold: no execute, tracker consumed.
	var healthy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 300, 500)
	var tracker: CombinedLethalityAbilityTracker = hero.add_buff(
			CombinedLethalityAbilityTracker.new()) as CombinedLethalityAbilityTracker
	tracker.weapon = hero.belongings.second_wep
	hero.attack(healthy)
	t.check(healthy.is_alive and healthy.hp > 200,
			"An enemy above the HP threshold is not executed")
	t.check(hero.get_buff("CombinedLethalityAbilityTracker") == null,
			"The tracker is still consumed by a non-executing differing hit")
	# Bosses are immune even under the threshold.
	var boss := _make_enemy(level, ConstantsData.xy_to_pos(4, 5), 150, 500)
	boss._properties.append("BOSS")
	tracker = hero.add_buff(CombinedLethalityAbilityTracker.new()) \
			as CombinedLethalityAbilityTracker
	tracker.weapon = hero.belongings.second_wep
	hero.attack(boss)
	t.check(boss.is_alive and boss.hp > 100, "Bosses are never executed")
	t.check(hero.get_buff("CombinedLethalityAbilityTracker") == null,
			"The tracker is consumed against a boss too")
	hero.free()

func _test_offhand_ability_chain(t: Object) -> void:
	var level := _make_level()
	var hero := _make_champion(level, ConstantsData.xy_to_pos(5, 5))
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 150, 500)
	# Primary ability arms, then the off-hand's own ability strike is itself
	# the differing-weapon hit: it executes and re-arms with the off-hand.
	var tracker: CombinedLethalityAbilityTracker = hero.add_buff(
			CombinedLethalityAbilityTracker.new()) as CombinedLethalityAbilityTracker
	tracker.weapon = hero.belongings.weapon
	hero._do_weapon_ability(hero.belongings.second_wep, enemy.pos)
	t.check(not enemy.is_alive or enemy.hp == 0,
			"An off-hand ability strike executes via the primary-armed tracker")
	tracker = hero.get_buff("CombinedLethalityAbilityTracker") \
			as CombinedLethalityAbilityTracker
	t.check(tracker != null and tracker.weapon == hero.belongings.second_wep,
			"The chain re-arms with the off-hand after its ability")
	hero.free()
