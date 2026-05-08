class_name LaboratoryRoom
extends Room
## Laboratory room — contains an alchemy pot and potion ingredients.

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

	# Alchemy pot at center
	level.set_terrain(center(), ConstantsData.Terrain.ALCHEMY)

	# Embers around the pot for ambiance
	for dir: int in ConstantsData.DIRS_4:
		var pos: int = center() + dir
		if inside_interior(pos):
			level.set_terrain(pos, ConstantsData.Terrain.EMBERS)

	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)

	painted = true
