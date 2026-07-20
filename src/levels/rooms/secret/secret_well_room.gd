class_name SecretWellRoom
extends Room
## Secret well room — a tiny hidden room with a well at center.

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
	return 5

func max_height() -> int:
	return 5

func paint(level: Level) -> void:
	Painter.fill_room(level, self, ConstantsData.Terrain.WALL)
	Painter.fill_interior(level, self, ConstantsData.Terrain.EMPTY_SP)

	# Well at the center, seeded with healing water (SPD WellWater). Healing runs
	# through the WaterOfHealth blob layer when the hero stands on the tile.
	var well_cell: int = center()
	level.set_terrain(well_cell, ConstantsData.Terrain.WELL)
	WaterOfHealth.seed_well(level, well_cell)

	# All doors to this room are secret doors
	for other: Variant in connected:
		var door_pos: int = door_to(other)
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.SECRET_DOOR)
	painted = true
