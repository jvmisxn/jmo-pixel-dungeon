class_name RotGardenRoom
extends Room
## Rot garden room — an overgrown room with high grass and a rotberry plant.
## Paints with HIGH_GRASS everywhere and FURROWED_GRASS patches.

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
	Painter.fill_interior(level, self, ConstantsData.Terrain.HIGH_GRASS)

	# Scatter furrowed grass patches
	Painter.scatter(level, self, ConstantsData.Terrain.FURROWED_GRASS, 0.25)

	# Rotberry plant location at center (marked with special grass)
	level.set_terrain(center(), ConstantsData.Terrain.HIGH_GRASS)

	# Place doors with a grass path leading to them
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)
			Painter.draw_line(level, door_pos, center(), ConstantsData.Terrain.GRASS)

	painted = true
