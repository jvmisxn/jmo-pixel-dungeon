class_name ArmoryRoom
extends Room
## Armory room — locked room with weapon/armor on pedestals and statues.

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

	# Statues in corners
	level.set_terrain((top + 1) * ConstantsData.WIDTH + left + 1, ConstantsData.Terrain.STATUE)
	level.set_terrain((top + 1) * ConstantsData.WIDTH + right - 1, ConstantsData.Terrain.STATUE)
	level.set_terrain((bottom - 1) * ConstantsData.WIDTH + left + 1, ConstantsData.Terrain.STATUE)
	level.set_terrain((bottom - 1) * ConstantsData.WIDTH + right - 1, ConstantsData.Terrain.STATUE)

	# Pedestal in center
	level.set_terrain(center(), ConstantsData.Terrain.PEDESTAL)

	# Locked door
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.LOCKED_DOOR)

	painted = true
