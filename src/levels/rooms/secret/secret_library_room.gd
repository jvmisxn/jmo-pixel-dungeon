class_name SecretLibraryRoom
extends Room
## Secret library room — hidden library with bookshelves and scrolls.
## Paints BOOKSHELF on interior walls, drops scrolls on the floor.

func _init() -> void:
	type = Type.SECRET

## Secret rooms can only have 1 connection (the secret door).
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

	# Line interior walls with bookshelves
	for x: int in range(left + 1, right):
		level.set_terrain((top + 1) * ConstantsData.WIDTH + x, ConstantsData.Terrain.BOOKSHELF)
		level.set_terrain((bottom - 1) * ConstantsData.WIDTH + x, ConstantsData.Terrain.BOOKSHELF)
	for y: int in range(top + 2, bottom - 1):
		level.set_terrain(y * ConstantsData.WIDTH + left + 1, ConstantsData.Terrain.BOOKSHELF)
		level.set_terrain(y * ConstantsData.WIDTH + right - 1, ConstantsData.Terrain.BOOKSHELF)

	# Clear walkable path in the inner area
	for y: int in range(top + 2, bottom - 1):
		for x: int in range(left + 2, right - 1):
			level.set_terrain(y * ConstantsData.WIDTH + x, ConstantsData.Terrain.EMPTY_SP)

	# All doors to this room are secret doors
	# Clear bookshelf at door positions so entry is possible
	for other: Variant in connected:
		var door_pos: int = door(other)
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.SECRET_DOOR)
	painted = true
