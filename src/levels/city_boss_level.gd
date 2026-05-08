class_name CityBossLevel
extends Level
## City boss level (depth 20) — Dwarf King fight.
## Throne room with summoning pedestals.

func _build() -> bool:
	_init_arrays()
	var W_: int = ConstantsData.WIDTH

	# Grand throne room
	var hall_left: int = 5
	var hall_top: int = 4
	var hall_right: int = 26
	var hall_bottom: int = 27

	# Fill with empty floor
	for y: int in range(hall_top, hall_bottom + 1):
		for x: int in range(hall_left, hall_right + 1):
			set_terrain(y * W_ + x, ConstantsData.Terrain.EMPTY_SP)

	# Pillars along the sides
	for y: int in range(hall_top + 2, hall_bottom - 1, 3):
		set_terrain(y * W_ + hall_left + 2, ConstantsData.Terrain.WALL_DECO)
		set_terrain(y * W_ + hall_right - 2, ConstantsData.Terrain.WALL_DECO)

	# Throne area at the back
	var throne_y: int = hall_top + 3
	@warning_ignore("integer_division")
	var cx: int = (hall_left + hall_right) / 2
	set_terrain(throne_y * W_ + cx, ConstantsData.Terrain.PEDESTAL)

	# Summoning pedestals in a ring around the center
	@warning_ignore("integer_division")
	var ring_y: int = (hall_top + hall_bottom) / 2
	var pedestal_positions: Array = [
		Vector2i(cx - 4, ring_y - 3), Vector2i(cx + 4, ring_y - 3),
		Vector2i(cx - 6, ring_y), Vector2i(cx + 6, ring_y),
		Vector2i(cx - 4, ring_y + 3), Vector2i(cx + 4, ring_y + 3),
	]
	for p: Vector2i in pedestal_positions:
		if p.x > hall_left and p.x < hall_right and p.y > hall_top and p.y < hall_bottom:
			set_terrain(p.y * W_ + p.x, ConstantsData.Terrain.PEDESTAL)

	# Carpet / embers path down the center
	for y: int in range(hall_top + 1, hall_bottom):
		set_terrain(y * W_ + cx, ConstantsData.Terrain.EMBERS)

	# Entrance corridor
	entrance = (hall_bottom + 2) * W_ + cx
	set_terrain(entrance, ConstantsData.Terrain.ENTRANCE)
	for y: int in range(hall_bottom, hall_bottom + 3):
		set_terrain(y * W_ + cx, ConstantsData.Terrain.EMPTY_SP)
		set_terrain(y * W_ + cx - 1, ConstantsData.Terrain.EMPTY_SP)
		set_terrain(y * W_ + cx + 1, ConstantsData.Terrain.EMPTY_SP)

	# Exit behind the throne (locked)
	exit_pos = (hall_top - 2) * W_ + cx
	set_terrain(exit_pos, ConstantsData.Terrain.EXIT)
	for y: int in range(hall_top - 2, hall_top + 1):
		set_terrain(y * W_ + cx, ConstantsData.Terrain.EMPTY_SP)
	set_terrain(hall_top * W_ + cx, ConstantsData.Terrain.LOCKED_DOOR)

	build_flag_maps()

	# Spawn Dwarf King boss on the throne
	var boss: Mob = MobFactory.create_boss(20)
	boss.pos = throne_y * W_ + cx
	add_mob(boss)

	return true
