class_name CavesBossLevel
extends Level
## Caves boss level (depth 15) — DM-300 fight.
## Large cavern with pylons and water channels.

func _build() -> bool:
	_init_arrays()
	var W_: int = ConstantsData.WIDTH

	# Large cavern
	var cave_left: int = 4
	var cave_top: int = 4
	var cave_right: int = 27
	var cave_bottom: int = 27

	# Fill cavern with floor
	for y: int in range(cave_top, cave_bottom + 1):
		for x: int in range(cave_left, cave_right + 1):
			set_terrain(y * W_ + x, ConstantsData.Terrain.EMPTY)

	# Irregular edges — erode the rectangle into a more natural shape
	for y: int in range(cave_top, cave_bottom + 1):
		for x: int in range(cave_left, cave_right + 1):
			@warning_ignore("integer_division")
			var dx: float = float(x - (cave_left + cave_right) / 2)
			@warning_ignore("integer_division")
			var dy: float = float(y - (cave_top + cave_bottom) / 2)
			var rx: float = float(cave_right - cave_left) / 2.0
			var ry: float = float(cave_bottom - cave_top) / 2.0
			var dist: float = (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry)
			if dist > 0.85 and randf() < 0.4:
				set_terrain(y * W_ + x, ConstantsData.Terrain.WALL)

	# Water channels in a cross pattern
	@warning_ignore("integer_division")
	var cx: int = (cave_left + cave_right) / 2
	@warning_ignore("integer_division")
	var cy: int = (cave_top + cave_bottom) / 2
	for i: int in range(-8, 9):
		if absi(i) > 2:
			set_terrain(cy * W_ + cx + i, ConstantsData.Terrain.WATER)
			set_terrain((cy + i) * W_ + cx, ConstantsData.Terrain.WATER)

	# Pylons (destructible pillars) — represented as statues
	var pylon_offsets: Array = [
		Vector2i(-5, -5), Vector2i(5, -5),
		Vector2i(-5, 5), Vector2i(5, 5),
		Vector2i(-8, 0), Vector2i(8, 0),
	]
	for offset: Vector2i in pylon_offsets:
		var px: int = cx + offset.x
		var py: int = cy + offset.y
		if px > cave_left and px < cave_right and py > cave_top and py < cave_bottom:
			set_terrain(py * W_ + px, ConstantsData.Terrain.STATUE_SP)

	# Entrance
	entrance = (cave_top - 1) * W_ + cx
	set_terrain(entrance, ConstantsData.Terrain.ENTRANCE)
	for y: int in range(cave_top - 2, cave_top + 1):
		set_terrain(y * W_ + cx, ConstantsData.Terrain.EMPTY)

	# Exit (locked)
	exit_pos = (cave_bottom + 2) * W_ + cx
	set_terrain(exit_pos, ConstantsData.Terrain.EXIT)
	for y: int in range(cave_bottom, cave_bottom + 3):
		set_terrain(y * W_ + cx, ConstantsData.Terrain.EMPTY)
	set_terrain(cave_bottom * W_ + cx, ConstantsData.Terrain.LOCKED_DOOR)

	build_flag_maps()

	# Spawn DM-300 boss in the center
	var boss: Mob = MobFactory.create_boss(15)
	boss.pos = cy * W_ + cx
	add_mob(boss)

	return true
