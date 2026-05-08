class_name MagicWellRoom
extends Room
## Magic well room — contains a well that grants a one-time effect.
## Effects include: identify all items, upgrade an item, or full healing.
## Paints with EMPTY floor and a WELL at center.

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

	# Well at the center
	level.set_terrain(center(), ConstantsData.Terrain.WELL)

	# Small water puddle around the well for decoration
	var cx: int = center_x()
	var cy: int = center_y()
	var offsets: Array = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for offset: Vector2i in offsets:
		var adj_pos: int = (cy + offset.y) * ConstantsData.WIDTH + (cx + offset.x)
		if inside_interior(adj_pos):
			level.set_terrain(adj_pos, ConstantsData.Terrain.WATER)

	# Place doors
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)

	painted = true
