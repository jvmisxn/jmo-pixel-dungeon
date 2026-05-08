class_name TrapRoom
extends Room
## Trap room — filled with traps, with a reward on a pedestal at the center.

func _init() -> void:
	type = Type.SPECIAL

## Special rooms have a single entrance.
## Matches original SpecialRoom.maxConnections() = 1.
func max_connections(_direction: int = -1) -> int:
	return 1

func min_width() -> int:
	return 6

func min_height() -> int:
	return 6

func max_width() -> int:
	return 8

func max_height() -> int:
	return 8

func paint(level: Level) -> void:
	Painter.fill_room(level, self, ConstantsData.Terrain.WALL)
	Painter.fill_interior(level, self, ConstantsData.Terrain.EMPTY_SP)

	# Fill interior with trap tiles (actual trap objects placed by level gen)
	var interior: Array[int] = interior_cells()
	for pos: int in interior:
		if pos != center():
			if randf() < 0.6:
				level.set_terrain(pos, ConstantsData.Terrain.SECRET_TRAP)

	# Pedestal at center with the reward
	level.set_terrain(center(), ConstantsData.Terrain.PEDESTAL)

	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)

	painted = true
