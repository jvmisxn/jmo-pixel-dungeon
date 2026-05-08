class_name EntranceRoom
extends Room
## Entrance room — contains the stairs up (or starting position on depth 1).
## The entrance is placed at the center of the room.

func _init() -> void:
	type = Type.ENTRANCE

func min_width() -> int:
	return 5

func min_height() -> int:
	return 5

func max_width() -> int:
	return 8

func max_height() -> int:
	return 8

# ---------------------------------------------------------------------------
# Painting
# ---------------------------------------------------------------------------

func paint(level: Level) -> void:
	# Walls and floor
	for pos: int in all_cells():
		level.set_terrain(pos, ConstantsData.Terrain.WALL)
	for pos: int in interior_cells():
		level.set_terrain(pos, ConstantsData.Terrain.EMPTY)

	# Place entrance stairs at center
	var entrance_pos: int = center()
	level.set_terrain(entrance_pos, ConstantsData.Terrain.ENTRANCE)
	level.entrance = entrance_pos

	# Place doors
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)

	painted = true
