class_name ShopRoom
extends Room
## Shop room — contains a shopkeeper and items for sale on pedestals.

func _init() -> void:
	type = Type.SPECIAL

## Shop rooms allow 2 connections (entrance + potential back door).
## Matches original ShopRoom.maxConnections() = 2.
func max_connections(_direction: int = -1) -> int:
	return 2

func min_width() -> int:
	return 7

func min_height() -> int:
	return 7

func max_width() -> int:
	return 9

func max_height() -> int:
	return 9

func paint(level: Level) -> void:
	Painter.fill_room(level, self, ConstantsData.Terrain.WALL)
	Painter.fill_interior(level, self, ConstantsData.Terrain.EMPTY_SP)

	# Ring of pedestals around the inside edge
	for x: int in range(left + 2, right - 1):
		level.set_terrain((top + 2) * ConstantsData.WIDTH + x, ConstantsData.Terrain.PEDESTAL)
		level.set_terrain((bottom - 2) * ConstantsData.WIDTH + x, ConstantsData.Terrain.PEDESTAL)
	for y: int in range(top + 2, bottom - 1):
		level.set_terrain(y * ConstantsData.WIDTH + left + 2, ConstantsData.Terrain.PEDESTAL)
		level.set_terrain(y * ConstantsData.WIDTH + right - 2, ConstantsData.Terrain.PEDESTAL)

	# Place doors
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)

	painted = true
