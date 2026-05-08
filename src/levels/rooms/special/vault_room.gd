class_name VaultRoom
extends Room
## Vault room — locked room containing treasure. Requires a crystal or golden key.

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
	Painter.fill_interior(level, self, ConstantsData.Terrain.EMPTY_SP)

	# Central pedestal for the treasure
	level.set_terrain(center(), ConstantsData.Terrain.PEDESTAL)

	# Locked door
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.LOCKED_DOOR)

	painted = true
