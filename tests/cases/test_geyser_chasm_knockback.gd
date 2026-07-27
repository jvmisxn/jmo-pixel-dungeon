extends RefCounted
## GeyserTrap knockback now routes through the shared KnockBack helper
## (audit:S09 follow-up), matching upstream GeyserTrap ->
## WandOfBlastWave.throwChar: chasm cells are enterable by forced movement, so
## a geyser push can throw a grounded char into a chasm (mobs die via
## Chasm.force_fall) while flying chars sail over, and the centre-direction
## picker treats chasm cells as open candidates.

const TRAP_X: int = 15
const TRAP_Y: int = 12

func run(t: Object) -> void:
	_test_neighbour_pushed_into_chasm_dies(t)
	_test_flying_neighbour_sails_over_chasm(t)
	_test_center_push_into_chasm(t)
	_test_center_direction_accepts_chasm(t)
	_test_wall_still_stops_push(t)

func _make_level() -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func _make_mob(level: Level, x: int, y: int, hp: int = 40) -> Mob:
	var mob := Mob.new()
	mob.hp_max = hp
	mob.hp = hp
	mob.pos = ConstantsData.xy_to_pos(x, y)
	mob.level = level
	level.add_mob(mob)
	return mob

func _make_trap(level: Level, forced_dir: int = -1) -> GeyserTrap:
	var trap := GeyserTrap.new()
	if forced_dir != -1:
		trap.center_knock_back_direction = forced_dir
	trap.set_pos(ConstantsData.xy_to_pos(TRAP_X, TRAP_Y))
	level.set_terrain(trap.pos, ConstantsData.Terrain.TRAP)
	return trap

func _test_neighbour_pushed_into_chasm_dies(t: Object) -> void:
	seed(11)
	var level := _make_level()
	# Chasm two cells east of the east neighbour: push lands on it.
	level.set_terrain(ConstantsData.xy_to_pos(TRAP_X + 3, TRAP_Y),
		ConstantsData.Terrain.CHASM)
	var mob := _make_mob(level, TRAP_X + 1, TRAP_Y)
	var trap := _make_trap(level)

	trap.activate(null, level)

	t.check(mob.pos == ConstantsData.xy_to_pos(TRAP_X + 3, TRAP_Y),
		"geyser pushes the east neighbour onto the chasm cell")
	t.check(not mob.is_alive,
		"grounded mob thrown into a chasm by the geyser dies (Chasm fall)")

	mob.free()

func _test_flying_neighbour_sails_over_chasm(t: Object) -> void:
	seed(12)
	var level := _make_level()
	# Chasm one cell east of the east neighbour: first push step crosses it.
	level.set_terrain(ConstantsData.xy_to_pos(TRAP_X + 2, TRAP_Y),
		ConstantsData.Terrain.CHASM)
	var mob := _make_mob(level, TRAP_X + 1, TRAP_Y)
	mob.flying = true
	var trap := _make_trap(level)

	trap.activate(null, level)

	t.check(mob.pos == ConstantsData.xy_to_pos(TRAP_X + 3, TRAP_Y),
		"flying char is pushed across the chasm to the far side")
	t.check(mob.is_alive, "flying char does not fall into the chasm")

	mob.free()

func _test_center_push_into_chasm(t: Object) -> void:
	seed(13)
	var level := _make_level()
	level.set_terrain(ConstantsData.xy_to_pos(TRAP_X, TRAP_Y + 2),
		ConstantsData.Terrain.CHASM)
	var mob := _make_mob(level, TRAP_X, TRAP_Y)
	var trap := _make_trap(level, ConstantsData.DIR_S)

	trap.activate(mob, level)

	t.check(mob.pos == ConstantsData.xy_to_pos(TRAP_X, TRAP_Y + 2),
		"centre char is pushed south onto the chasm cell")
	t.check(not mob.is_alive,
		"centre char thrown into a chasm dies (Chasm fall)")

	mob.free()

func _test_center_direction_accepts_chasm(t: Object) -> void:
	seed(14)
	var level := _make_level()
	# Wall in every neighbour except a single chasm cell to the east: the
	# random centre-direction picker must still find the chasm as an open
	# forced-movement candidate (upstream AVOID terrain is throwable-into).
	var trap_pos := ConstantsData.xy_to_pos(TRAP_X, TRAP_Y)
	for dir: int in ConstantsData.DIRS_8:
		level.set_terrain(trap_pos + dir, ConstantsData.Terrain.WALL)
	level.set_terrain(trap_pos + ConstantsData.DIR_E, ConstantsData.Terrain.CHASM)
	var mob := _make_mob(level, TRAP_X, TRAP_Y)
	var trap := _make_trap(level)

	trap.activate(mob, level)

	t.check(not mob.is_alive,
		"boxed-in centre char is thrown into the only open (chasm) neighbour")

	mob.free()

func _test_wall_still_stops_push(t: Object) -> void:
	seed(15)
	var level := _make_level()
	level.set_terrain(ConstantsData.xy_to_pos(TRAP_X + 2, TRAP_Y),
		ConstantsData.Terrain.WALL)
	var mob := _make_mob(level, TRAP_X + 1, TRAP_Y)
	var trap := _make_trap(level)

	trap.activate(null, level)

	t.check(mob.pos == ConstantsData.xy_to_pos(TRAP_X + 1, TRAP_Y),
		"push stops before solid terrain")
	t.check(mob.hp == 40, "geyser push still deals no wall-slam damage")

	mob.free()
