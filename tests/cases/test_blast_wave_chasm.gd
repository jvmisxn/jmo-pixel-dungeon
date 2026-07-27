extends RefCounted
## Blast Wave knockback vs chasms (upstream Char.throwChar -> Level.occupyCell):
## chasm cells are AVOID terrain upstream, so forced movement can push chars
## onto them. Grounded mobs die to the fall (Chasm.mobFall), grounded heroes
## descend via the shared `hero_fell` path, and flying chars sail across
## without falling. The port's walk-time passability (chasm impassable to
## normal move_to) is unchanged.

const ROW_Y: int = 5
const CASTER_X: int = 3
const TARGET_X: int = 4
const CHASM_X: int = 6

func _make_level() -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.map[ConstantsData.xy_to_pos(CHASM_X, ROW_Y)] = ConstantsData.Terrain.CHASM
	level.build_flag_maps()
	return level

func _make_wand(wand_level: int) -> Object:
	var wand: Object = Wand.WandOfBlastWave.new()
	wand.level = wand_level
	return wand

func _knock(wand: Object, level: Level, target: Variant, distance: int) -> void:
	wand._apply_knockback(
		level, target,
		ConstantsData.xy_to_pos(CASTER_X, ROW_Y),
		target.pos, distance)

func run(t: Object) -> void:
	_test_grounded_mob_falls_and_dies(t)
	_test_flying_mob_sails_over(t)
	_test_hero_fall_uses_shared_descent(t)
	_test_wall_slam_still_applies(t)

func _test_grounded_mob_falls_and_dies(t: Object) -> void:
	var level: Level = _make_level()
	var mob := Mob.new()
	mob.hp_max = 40
	mob.hp = 40
	mob.pos = ConstantsData.xy_to_pos(TARGET_X, ROW_Y)
	mob.level = level
	level.add_mob(mob)
	var wand: Object = _make_wand(0)

	_knock(wand, level, mob, 2)

	t.check(mob.pos == ConstantsData.xy_to_pos(CHASM_X, ROW_Y),
		"grounded mob is pushed onto the chasm cell")
	t.check(not mob.is_alive,
		"grounded mob knocked into a chasm dies to the fall (Chasm.mobFall)")

	mob.free()

func _test_flying_mob_sails_over(t: Object) -> void:
	var level: Level = _make_level()
	var mob := Mob.new()
	mob.hp_max = 40
	mob.hp = 40
	mob.flying = true
	mob.pos = ConstantsData.xy_to_pos(TARGET_X, ROW_Y)
	mob.level = level
	level.add_mob(mob)
	var wand: Object = _make_wand(1)

	_knock(wand, level, mob, 3)

	t.check(mob.pos == ConstantsData.xy_to_pos(TARGET_X + 3, ROW_Y),
		"flying mob is knocked across the chasm to the far side")
	t.check(mob.is_alive, "flying mob does not fall into the chasm")

	mob.free()

func _test_hero_fall_uses_shared_descent(t: Object) -> void:
	var level: Level = _make_level()
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.pos = ConstantsData.xy_to_pos(TARGET_X, ROW_Y)
	hero.level = level
	hero.hp = 60
	hero.hp_max = 60
	hero.ht = 60
	var wand: Object = _make_wand(0)

	var fell_hero: Array[Variant] = [null]
	if EventBus != null and EventBus.has_signal("hero_fell"):
		var on_fell: Callable = func(hero_node: Variant) -> void:
			fell_hero[0] = hero_node
		EventBus.hero_fell.connect(on_fell, CONNECT_ONE_SHOT)

	_knock(wand, level, hero, 2)

	t.check(hero.pos == ConstantsData.xy_to_pos(CHASM_X, ROW_Y),
		"hero is pushed onto the chasm cell")
	t.check(fell_hero[0] == hero,
		"hero knocked into a chasm descends via the shared hero_fell path")
	t.check(hero.is_alive, "knockback chasm fall does not kill the hero in place")

	hero.free()

func _test_wall_slam_still_applies(t: Object) -> void:
	var level: Level = _make_level()
	var wall_pos: int = ConstantsData.xy_to_pos(CHASM_X, ROW_Y)
	level.set_terrain(wall_pos, ConstantsData.Terrain.WALL)
	var mob := Mob.new()
	mob.hp_max = 400
	mob.hp = 400
	mob.pos = ConstantsData.xy_to_pos(TARGET_X, ROW_Y)
	mob.level = level
	level.add_mob(mob)
	var wand: Object = _make_wand(0)

	_knock(wand, level, mob, 3)

	t.check(mob.pos == ConstantsData.xy_to_pos(CHASM_X - 1, ROW_Y),
		"mob stops in front of a solid wall")
	t.check(mob.hp < 400, "wall slam bonus damage still applies to real walls")

	mob.free()
