class_name PrisonBossLevel
extends Level
## Prison boss level (depth 10) — Tengu fight.
## Multi-phase arena with traps and maze segments.

func _build() -> bool:
	_init_arrays()
	var W_: int = ConstantsData.WIDTH

	# Phase 1 arena — open room with trap floor
	var arena_left: int = 4
	var arena_top: int = 4
	var arena_right: int = 27
	var arena_bottom: int = 27

	# Create the main arena
	for y: int in range(arena_top, arena_bottom + 1):
		for x: int in range(arena_left, arena_right + 1):
			set_terrain(y * W_ + x, ConstantsData.Terrain.EMPTY)

	# Create a maze-like pattern with walls inside
	for y: int in range(arena_top + 2, arena_bottom - 1, 4):
		for x: int in range(arena_left + 2, arena_right - 1):
			if randf() < 0.6:
				set_terrain(y * W_ + x, ConstantsData.Terrain.WALL)

	# Clear paths through the maze
	@warning_ignore("integer_division")
	var mid_y: int = (arena_top + arena_bottom) / 2
	for x: int in range(arena_left, arena_right + 1):
		set_terrain(mid_y * W_ + x, ConstantsData.Terrain.EMPTY)
		set_terrain((mid_y + 1) * W_ + x, ConstantsData.Terrain.EMPTY)

	@warning_ignore("integer_division")
	var mid_x: int = (arena_left + arena_right) / 2
	for y: int in range(arena_top, arena_bottom + 1):
		set_terrain(y * W_ + mid_x, ConstantsData.Terrain.EMPTY)
		set_terrain(y * W_ + mid_x + 1, ConstantsData.Terrain.EMPTY)

	# Scatter traps
	for y: int in range(arena_top + 1, arena_bottom):
		for x: int in range(arena_left + 1, arena_right):
			var pos: int = y * W_ + x
			if terrain_at(pos) == ConstantsData.Terrain.EMPTY and randf() < 0.12:
				set_terrain(pos, ConstantsData.Terrain.SECRET_TRAP)

	# Entrance at top
	entrance = (arena_top - 1) * W_ + mid_x
	set_terrain(entrance, ConstantsData.Terrain.ENTRANCE)
	# Clear path to entrance
	for y: int in range(arena_top - 2, arena_top + 1):
		set_terrain(y * W_ + mid_x, ConstantsData.Terrain.EMPTY)

	# Exit at bottom (locked)
	exit_pos = (arena_bottom + 2) * W_ + mid_x
	set_terrain(exit_pos, ConstantsData.Terrain.EXIT)
	for y: int in range(arena_bottom, arena_bottom + 3):
		set_terrain(y * W_ + mid_x, ConstantsData.Terrain.EMPTY)
	set_terrain(arena_bottom * W_ + mid_x, ConstantsData.Terrain.LOCKED_DOOR)

	build_flag_maps()

	# Spawn Tengu boss in the center of the arena
	var boss: Mob = MobFactory.create_boss(10)
	boss.pos = mid_y * W_ + mid_x
	add_mob(boss)

	return true
