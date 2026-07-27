extends RefCounted
## Shared forced-movement pushes (KnockBack.throw_char) vs chasms, mirroring
## upstream Char.throwChar -> Level.occupyCell for the Repulsion glyph and
## Elastic enchant sites: chasm cells are AVOID terrain upstream, so a 2-cell
## push can force a grounded char in (mobs die, heroes descend via hero_fell)
## while flying chars sail over. Solid terrain and other chars still stop the
## push, with no wall-slam damage (that is Blast Wave-specific).

const ROW_Y: int = 5
const SOURCE_X: int = 3
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

func _make_mob(level: Level, x: int, hp: int) -> Mob:
	var mob := Mob.new()
	mob.hp_max = hp
	mob.hp = hp
	mob.pos = ConstantsData.xy_to_pos(x, ROW_Y)
	mob.level = level
	level.add_mob(mob)
	return mob

func run(t: Object) -> void:
	_test_grounded_mob_falls_and_dies(t)
	_test_flying_mob_sails_over(t)
	_test_wall_stops_push_without_damage(t)
	_test_other_char_blocks_push(t)
	_test_elastic_proc_pushes_into_chasm(t)
	_test_hero_fall_uses_shared_descent(t)

func _test_grounded_mob_falls_and_dies(t: Object) -> void:
	var level: Level = _make_level()
	var mob: Mob = _make_mob(level, TARGET_X, 40)

	var moved: bool = KnockBack.throw_char(
		mob, ConstantsData.xy_to_pos(SOURCE_X, ROW_Y), 2, level)

	t.check(moved, "push into a chasm reports movement")
	t.check(mob.pos == ConstantsData.xy_to_pos(CHASM_X, ROW_Y),
		"grounded mob is pushed onto the chasm cell")
	t.check(not mob.is_alive,
		"grounded mob pushed into a chasm dies to the fall (Chasm.mobFall)")

	mob.free()

func _test_flying_mob_sails_over(t: Object) -> void:
	var level: Level = _make_level()
	var mob: Mob = _make_mob(level, TARGET_X, 40)
	mob.flying = true

	KnockBack.throw_char(mob, ConstantsData.xy_to_pos(SOURCE_X, ROW_Y), 3, level)

	t.check(mob.pos == ConstantsData.xy_to_pos(TARGET_X + 3, ROW_Y),
		"flying mob is pushed across the chasm to the far side")
	t.check(mob.is_alive, "flying mob does not fall into the chasm")

	mob.free()

func _test_wall_stops_push_without_damage(t: Object) -> void:
	var level: Level = _make_level()
	level.set_terrain(ConstantsData.xy_to_pos(CHASM_X, ROW_Y), ConstantsData.Terrain.WALL)
	var mob: Mob = _make_mob(level, TARGET_X, 40)

	KnockBack.throw_char(mob, ConstantsData.xy_to_pos(SOURCE_X, ROW_Y), 3, level)

	t.check(mob.pos == ConstantsData.xy_to_pos(CHASM_X - 1, ROW_Y),
		"push stops in front of solid terrain")
	t.check(mob.hp == 40, "simple pushes deal no wall-slam damage")

	mob.free()

func _test_other_char_blocks_push(t: Object) -> void:
	var level: Level = _make_level()
	var mob: Mob = _make_mob(level, TARGET_X, 40)
	var blocker: Mob = _make_mob(level, TARGET_X + 1, 40)

	var moved: bool = KnockBack.throw_char(
		mob, ConstantsData.xy_to_pos(SOURCE_X, ROW_Y), 2, level)

	t.check(not moved, "push blocked immediately by another char reports no movement")
	t.check(mob.pos == ConstantsData.xy_to_pos(TARGET_X, ROW_Y),
		"another char blocks the push")

	mob.free()
	blocker.free()

func _test_elastic_proc_pushes_into_chasm(t: Object) -> void:
	var level: Level = _make_level()
	var attacker: Mob = _make_mob(level, SOURCE_X, 40)
	var defender: Mob = _make_mob(level, TARGET_X, 40)
	var ench: WeaponEnchantment = WeaponEnchantment.create("elastic")

	ench._elastic_proc(null, attacker, defender, 5)

	t.check(defender.pos == ConstantsData.xy_to_pos(CHASM_X, ROW_Y),
		"Elastic's 2-cell push forces the defender onto the chasm cell")
	t.check(not defender.is_alive,
		"defender pushed into the chasm by Elastic dies to the fall")

	attacker.free()
	defender.free()

func _test_hero_fall_uses_shared_descent(t: Object) -> void:
	var level: Level = _make_level()
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.pos = ConstantsData.xy_to_pos(TARGET_X, ROW_Y)
	hero.level = level
	hero.hp = 60
	hero.hp_max = 60
	hero.ht = 60

	var fell_hero: Array[Variant] = [null]
	if EventBus != null and EventBus.has_signal("hero_fell"):
		var on_fell: Callable = func(hero_node: Variant) -> void:
			fell_hero[0] = hero_node
		EventBus.hero_fell.connect(on_fell, CONNECT_ONE_SHOT)

	KnockBack.throw_char(hero, ConstantsData.xy_to_pos(SOURCE_X, ROW_Y), 2, level)

	t.check(hero.pos == ConstantsData.xy_to_pos(CHASM_X, ROW_Y),
		"hero is pushed onto the chasm cell")
	t.check(fell_hero[0] == hero,
		"hero pushed into a chasm descends via the shared hero_fell path")
	t.check(hero.is_alive, "forced chasm fall does not kill the hero in place")

	hero.free()
