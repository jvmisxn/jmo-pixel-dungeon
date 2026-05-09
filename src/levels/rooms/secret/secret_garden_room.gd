class_name SecretGardenRoom
extends Room
## Secret garden room — a hidden garden with seeds and dew.
## Small room with HIGH_GRASS interior and WATER at center.

func _init() -> void:
	type = Type.SECRET

## Secret rooms can only have 1 connection (the secret door).
func max_connections(_direction: int = -1) -> int:
	return 1

func min_width() -> int:
	return 4

func min_height() -> int:
	return 4

func max_width() -> int:
	return 6

func max_height() -> int:
	return 6

func paint(level: Level) -> void:
	Painter.fill_room(level, self, ConstantsData.Terrain.WALL)
	Painter.fill_interior(level, self, ConstantsData.Terrain.HIGH_GRASS)

	# Water pool at center for dew
	level.set_terrain(center(), ConstantsData.Terrain.WATER)

	# Scatter some furrowed grass for visual variety
	Painter.scatter(level, self, ConstantsData.Terrain.FURROWED_GRASS, 0.15)

	# Restore center water (scatter may have overwritten it)
	level.set_terrain(center(), ConstantsData.Terrain.WATER)

	# All doors to this room are secret doors
	for other: Variant in connected:
		var door_pos: int = door_to(other)
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.SECRET_DOOR)
	painted = true
