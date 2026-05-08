class_name SacrificeRoom
extends Room
## Sacrifice room — contains a demonic pedestal in the center.
## When the hero steps on it, they can sacrifice HP for a powerful item.
## Painted with EMPTY floor, EMBERS accents, and a PEDESTAL at center.

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

	# Scatter embers around the room for a demonic atmosphere
	Painter.scatter(level, self, ConstantsData.Terrain.EMBERS, 0.35)

	# Demonic pedestal at the center for the sacrifice
	level.set_terrain(center(), ConstantsData.Terrain.PEDESTAL)

	# Place doors
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)

	painted = true
