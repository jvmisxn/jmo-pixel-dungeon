class_name StatueRoom
extends Room
## Statue room — contains an animated statue guarding a reward item.
## Small room (5x5 to 7x7) with a STATUE terrain in center.

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
	Painter.fill_interior(level, self, ConstantsData.Terrain.EMPTY)

	# Animated statue at center guards a reward
	level.set_terrain(center(), ConstantsData.Terrain.STATUE)

	# Place an item adjacent to the statue (one cell offset from center)
	var item_pos: int = center() + 1
	if inside_interior(item_pos):
		level.set_terrain(item_pos, ConstantsData.Terrain.EMPTY_SP)

	# Place doors
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)

	painted = true
