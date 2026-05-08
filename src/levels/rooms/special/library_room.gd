class_name LibraryRoom
extends Room
## Library room — contains bookshelves with scrolls.

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

	# Rows of bookshelves
	for y: int in range(top + 2, bottom - 1, 2):
		for x: int in range(left + 2, right - 1):
			level.set_terrain(y * ConstantsData.WIDTH + x, ConstantsData.Terrain.BOOKSHELF)

	# Clear a path through the center column
	var cx: int = center_x()
	for y: int in range(top + 1, bottom):
		level.set_terrain(y * ConstantsData.WIDTH + cx, ConstantsData.Terrain.EMPTY_SP)

	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)

	painted = true
