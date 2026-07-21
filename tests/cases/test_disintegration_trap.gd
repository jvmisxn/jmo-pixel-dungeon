extends RefCounted
## Coverage for DisintegrationTrap, matching Shattered Pixel Dungeon's visible
## City death-ray trap: it targets the closest aimable character and deals
## NormalIntRange(30, 50) + scalingDepth damage through Char.take_damage().

class _FixedDisintegrationTrap:
	extends DisintegrationTrap

	var fixed_damage: int = 42

	func _roll_damage(_level: Level) -> int:
		return fixed_damage

func run(t: Object) -> void:
	_test_triggerer_at_cell_is_hit(t)
	_test_closest_aimable_target_is_hit(t)
	_test_blocked_or_too_far_targets_are_ignored(t)

func _make_level(depth: int = 16) -> Level:
	var level := Level.new()
	level.depth = depth
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func _make_char(pos: int, level: Level, hp: int = 100) -> Char:
	var ch := Char.new()
	ch.pos = pos
	ch.level = level
	ch.hp_max = hp
	ch.hp = hp
	ch.is_alive = true
	return ch

func _test_triggerer_at_cell_is_hit(t: Object) -> void:
	var trap_pos: int = ConstantsData.xy_to_pos(10, 10)
	var level: Level = _make_level()
	level.set_terrain(trap_pos, ConstantsData.Terrain.TRAP)
	var hero := _make_char(trap_pos, level)
	var trap := _FixedDisintegrationTrap.new()
	trap.set_pos(trap_pos)

	trap.activate(hero, level)

	t.check(trap.trap_name == "disintegration trap", "trap reports its SPD name")
	t.check(trap.visible, "disintegration trap starts visible")
	t.check(hero.hp == 58, "triggerer standing on trap takes the death-ray damage")
	t.check(level.terrain_at(trap_pos) == ConstantsData.Terrain.INACTIVE_TRAP,
		"disintegration trap is consumed as a one-shot")

func _test_closest_aimable_target_is_hit(t: Object) -> void:
	var trap_pos: int = ConstantsData.xy_to_pos(10, 10)
	var level: Level = _make_level()
	var near := _make_char(ConstantsData.xy_to_pos(13, 10), level)
	var far := _make_char(ConstantsData.xy_to_pos(16, 10), level)
	level.mobs = [near, far] as Array[Node]
	var trap := _FixedDisintegrationTrap.new()
	trap.set_pos(trap_pos)

	trap._do_effect(null, level)

	t.check(near.hp == 58, "disintegration trap targets the closest aimable char")
	t.check(far.hp == 100, "farther aimable chars are not hit by the trap")

func _test_blocked_or_too_far_targets_are_ignored(t: Object) -> void:
	var trap_pos: int = ConstantsData.xy_to_pos(10, 10)
	var level: Level = _make_level()
	var blocked := _make_char(ConstantsData.xy_to_pos(13, 10), level)
	var too_far := _make_char(ConstantsData.xy_to_pos(25, 10), level)
	level.mobs = [blocked, too_far] as Array[Node]
	level.set_terrain(ConstantsData.xy_to_pos(12, 10), ConstantsData.Terrain.WALL)
	var trap := _FixedDisintegrationTrap.new()
	trap.set_pos(trap_pos)

	trap._do_effect(null, level)

	t.check(blocked.hp == 100, "disintegration trap ignores targets blocked by projectile terrain")
	t.check(too_far.hp == 100, "disintegration trap ignores aimable targets past trap range")
