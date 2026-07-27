extends RefCounted
## Assassin's Reach + prepared blink-attack (upstream Preparation
## ActionIndicator / AttackLevel.blinkDistance): blink range scales with
## preparation level and Assassin's Reach points, and tapping a visible
## enemy within range yields a blink-attack action that teleports the hero
## to a free cell beside the target before striking.

func run(t: Object) -> void:
	_test_blink_distance_table(t)
	_test_blink_action_within_range(t)
	_test_no_blink_out_of_range(t)
	_test_no_blink_without_prep_or_visibility(t)
	_test_blink_dest_skips_occupied_cells(t)
	_test_blink_attack_moves_and_strikes(t)

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 3
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	level.visible.resize(ConstantsData.LENGTH)
	level.visible.fill(true)
	return level

func _make_assassin(level: Level, hero_pos: int, reach_points: int, turns_invis: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	hero.hero_subclass = ConstantsData.HeroSubclass.ASSASSIN
	if reach_points > 0:
		hero.talent_levels["assassin_assassins_reach"] = reach_points
	hero.level = level
	hero.pos = hero_pos
	if turns_invis > 0:
		var prep := AssassinPreparation.new()
		prep.turns_invis = turns_invis
		hero.add_buff(prep)
	return hero

func _make_enemy(level: Level, mob_pos: int) -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = 100
	mob.hp = 100
	mob.pos = mob_pos
	mob.level = level
	level.add_mob(mob)
	return mob

func _test_blink_distance_table(t: Object) -> void:
	var level := _make_level()
	var hero := _make_assassin(level, ConstantsData.xy_to_pos(5, 5), 0, 1)
	var prep := hero.get_buff("AssassinPreparation") as AssassinPreparation
	t.check(prep.blink_distance() == 1, "Prep level 1, no talent: blink range 1")
	prep.turns_invis = 9
	t.check(prep.blink_distance() == 4, "Prep level 4, no talent: blink range 4")
	hero.talent_levels["assassin_assassins_reach"] = 3
	t.check(prep.blink_distance() == 10, "Prep level 4, +3: blink range 10")
	prep.turns_invis = 3
	t.check(prep.blink_distance() == 5, "Prep level 2, +3: blink range 5")
	hero.free()

func _test_blink_action_within_range(t: Object) -> void:
	var level := _make_level()
	var hero := _make_assassin(level, ConstantsData.xy_to_pos(5, 5), 0, 9)
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(9, 5))
	var action: Dictionary = hero.get_auto_ranged_action(enemy.pos)
	t.check(action.get("type", "") == "attack", "Blink action is an attack")
	t.check(action.get("target") == enemy, "Blink action targets the tapped enemy")
	var dest: int = int(action.get("blink_pos", -1))
	t.check(dest == ConstantsData.xy_to_pos(8, 5),
		"Blink dest is the free neighbor closest to the hero")
	enemy.free()
	hero.free()

func _test_no_blink_out_of_range(t: Object) -> void:
	var level := _make_level()
	# Prep level 1 (range 1) cannot reach an enemy 4 tiles out.
	var hero := _make_assassin(level, ConstantsData.xy_to_pos(5, 5), 0, 1)
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(9, 5))
	t.check(hero.get_auto_ranged_action(enemy.pos).is_empty(),
		"Enemy beyond blink range yields no blink action")
	enemy.free()
	hero.free()

func _test_no_blink_without_prep_or_visibility(t: Object) -> void:
	var level := _make_level()
	var hero := _make_assassin(level, ConstantsData.xy_to_pos(5, 5), 0, 0)
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(7, 5))
	t.check(hero.get_auto_ranged_action(enemy.pos).is_empty(),
		"No Preparation buff means no blink action")
	var prep := AssassinPreparation.new()
	prep.turns_invis = 9
	hero.add_buff(prep)
	level.visible[enemy.pos] = false
	t.check(hero.get_auto_ranged_action(enemy.pos).is_empty(),
		"Invisible (out-of-FOV) enemy yields no blink action")
	level.visible[enemy.pos] = true
	hero.add_buff(Rooted.new())
	t.check(hero.get_auto_ranged_action(enemy.pos).is_empty(),
		"Rooted hero cannot blink")
	enemy.free()
	hero.free()

func _test_blink_dest_skips_occupied_cells(t: Object) -> void:
	var level := _make_level()
	var hero := _make_assassin(level, ConstantsData.xy_to_pos(5, 5), 0, 9)
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(8, 5))
	var blocker := _make_enemy(level, ConstantsData.xy_to_pos(7, 5))
	var action: Dictionary = hero.get_auto_ranged_action(enemy.pos)
	var dest: int = int(action.get("blink_pos", -1))
	t.check(dest != blocker.pos, "Occupied neighbor is never the blink dest")
	t.check(dest == ConstantsData.xy_to_pos(7, 4) or dest == ConstantsData.xy_to_pos(7, 6),
		"Blink dest falls back to a free diagonal neighbor")
	blocker.free()
	enemy.free()
	hero.free()

func _test_blink_attack_moves_and_strikes(t: Object) -> void:
	var level := _make_level()
	var hero := _make_assassin(level, ConstantsData.xy_to_pos(5, 5), 0, 9)
	hero.hp_max = 100
	hero.hp = 100
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(9, 5))
	var action: Dictionary = hero.get_auto_ranged_action(enemy.pos)
	t.check(not action.is_empty(), "Blink attack action produced")
	var hp_before: int = enemy.hp
	hero._do_attack(action.get("target"), int(action.get("target_pos", -1)), int(action.get("blink_pos", -1)))
	t.check(hero.pos == ConstantsData.xy_to_pos(8, 5),
		"Hero blinked adjacent to the target")
	t.check(enemy.hp < hp_before or not enemy.is_alive,
		"Prepared blink strike damaged the target")
	enemy.free()
	hero.free()
