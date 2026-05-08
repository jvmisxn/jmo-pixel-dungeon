class_name CrystalVaultRoom
extends Room
## Crystal vault room — locked with a crystal door, contains high-tier loot.
## Painted with EMPTY_SP floor, decorative walls, CRYSTAL_DOOR entrance,
## and a PEDESTAL with an item at center.

func _init() -> void:
	type = Type.SPECIAL

## Special rooms have a single entrance.
## Matches original SpecialRoom.maxConnections() = 1.
func max_connections(_direction: int = -1) -> int:
	return 1

func min_width() -> int:
	return 5

func min_height() -> int:
	return 5

func max_width() -> int:
	return 7

func max_height() -> int:
	return 7

func paint(level: Level) -> void:
	Painter.fill_room(level, self, ConstantsData.Terrain.WALL)
	Painter.fill_interior(level, self, ConstantsData.Terrain.EMPTY_SP)

	# Decorative crystal walls along interior edges
	for x: int in range(left + 1, right):
		level.set_terrain((top + 1) * ConstantsData.WIDTH + x, ConstantsData.Terrain.WALL_DECO)
		level.set_terrain((bottom - 1) * ConstantsData.WIDTH + x, ConstantsData.Terrain.WALL_DECO)
	for y: int in range(top + 2, bottom - 1):
		level.set_terrain(y * ConstantsData.WIDTH + left + 1, ConstantsData.Terrain.WALL_DECO)
		level.set_terrain(y * ConstantsData.WIDTH + right - 1, ConstantsData.Terrain.WALL_DECO)

	# Clear the inner core for walkability
	for y: int in range(top + 2, bottom - 1):
		for x: int in range(left + 2, right - 1):
			level.set_terrain(y * ConstantsData.WIDTH + x, ConstantsData.Terrain.EMPTY_SP)

	# Pedestal at center for high-tier loot
	level.set_terrain(center(), ConstantsData.Terrain.PEDESTAL)

	# Crystal door at entrance
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.CRYSTAL_DOOR)

	painted = true
