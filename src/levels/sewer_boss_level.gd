class_name SewerBossLevel
extends Level
## Sewer boss level (depth 5) — Goo fight.
## A pre-designed arena with water pools and a central open area.

func _build() -> bool:
	# Fill with walls
	_init_arrays()

	var W_: int = ConstantsData.WIDTH

	# Create a large central arena
	var arena_left: int = 6
	var arena_top: int = 8
	var arena_right: int = 25
	var arena_bottom: int = 24

	# Fill arena with empty floor
	for y: int in range(arena_top, arena_bottom + 1):
		for x: int in range(arena_left, arena_right + 1):
			set_terrain(y * W_ + x, ConstantsData.Terrain.EMPTY)

	# Water pools in the arena
	for y: int in range(arena_top + 2, arena_bottom - 1):
		for x: int in range(arena_left + 2, arena_right - 1):
			if randf() < 0.3:
				set_terrain(y * W_ + x, ConstantsData.Terrain.WATER)

	# Entrance corridor from the top
	@warning_ignore("integer_division")
	var entrance_x: int = (arena_left + arena_right) / 2
	for y: int in range(arena_top - 4, arena_top + 1):
		for x: int in range(entrance_x - 1, entrance_x + 2):
			set_terrain(y * W_ + x, ConstantsData.Terrain.EMPTY)

	# Place entrance at top of corridor
	entrance = (arena_top - 4) * W_ + entrance_x
	set_terrain(entrance, ConstantsData.Terrain.ENTRANCE)

	# Exit at far end (locked until boss is defeated)
	@warning_ignore("integer_division")
	var exit_x: int = (arena_left + arena_right) / 2
	for y: int in range(arena_bottom, arena_bottom + 4):
		for x: int in range(exit_x - 1, exit_x + 2):
			set_terrain(y * W_ + x, ConstantsData.Terrain.EMPTY)

	exit_pos = (arena_bottom + 3) * W_ + exit_x
	set_terrain(exit_pos, ConstantsData.Terrain.EXIT)

	# Door between arena and exit corridor (locked until boss dies)
	set_terrain(arena_bottom * W_ + exit_x, ConstantsData.Terrain.LOCKED_DOOR)

	# Pillars in the arena for cover
	var pillar_positions: Array[int] = [
		(arena_top + 3) * W_ + arena_left + 4,
		(arena_top + 3) * W_ + arena_right - 4,
		(arena_bottom - 3) * W_ + arena_left + 4,
		(arena_bottom - 3) * W_ + arena_right - 4,
	]
	for p: int in pillar_positions:
		set_terrain(p, ConstantsData.Terrain.WALL_DECO)

	build_flag_maps()

	# Spawn Goo boss in the center of the arena
	@warning_ignore("integer_division")
	var boss_x: int = (arena_left + arena_right) / 2
	@warning_ignore("integer_division")
	var boss_y: int = (arena_top + arena_bottom) / 2
	var boss: Mob = MobFactory.create_boss(5)
	boss.pos = boss_y * W_ + boss_x
	add_mob(boss)

	return true
