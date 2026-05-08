class_name ExitRoom
extends Room
## Exit room — contains the stairs down to the next depth.
## The exit is placed at the center of the room.

func _init() -> void:
	type = Type.EXIT

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

	# Place exit stairs at center
	var exit_cell: int = center()
	level.set_terrain(exit_cell, ConstantsData.Terrain.EXIT)
	level.exit_pos = exit_cell

	# Place doors
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)

	painted = true
