class_name GardenRoom
extends Room
## Garden room — filled with high grass and a well of health.

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
	return 8

func max_height() -> int:
	return 8

func paint(level: Level) -> void:
	Painter.fill_room(level, self, ConstantsData.Terrain.WALL)
	Painter.fill_interior(level, self, ConstantsData.Terrain.HIGH_GRASS)

	# Path from door to center
	var c: int = center()
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)
			# Carve a grass path to center
			Painter.draw_line(level, door_pos, c, ConstantsData.Terrain.GRASS)

	# Well at center
	level.set_terrain(c, ConstantsData.Terrain.WELL)

	# Scatter some furrowed grass
	Painter.scatter(level, self, ConstantsData.Terrain.FURROWED_GRASS, 0.1)

	painted = true
