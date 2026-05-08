class_name PoolRoom
extends Room
## Pool room — contains a well of healing or awareness surrounded by water.

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
	Painter.fill_interior(level, self, ConstantsData.Terrain.WATER)

	# Walkable ring around the edge
	for x: int in range(left + 1, right):
		level.set_terrain((top + 1) * ConstantsData.WIDTH + x, ConstantsData.Terrain.EMPTY)
		level.set_terrain((bottom - 1) * ConstantsData.WIDTH + x, ConstantsData.Terrain.EMPTY)
	for y: int in range(top + 1, bottom):
		level.set_terrain(y * ConstantsData.WIDTH + left + 1, ConstantsData.Terrain.EMPTY)
		level.set_terrain(y * ConstantsData.WIDTH + right - 1, ConstantsData.Terrain.EMPTY)

	# Well at center
	level.set_terrain(center(), ConstantsData.Terrain.WELL)

	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)

	painted = true
