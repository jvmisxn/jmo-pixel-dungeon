class_name Painter
extends RefCounted
## Base painter class — responsible for filling rooms with terrain and decorations.
## Mirrors Shattered PD's Painter.java.

# ---------------------------------------------------------------------------
# Static Painting Utilities
# ---------------------------------------------------------------------------

## Fill a rectangular area with a terrain type.
static func fill(level: Level, left: int, top: int, right: int, bottom: int, terrain: int) -> void:
	for y: int in range(top, bottom + 1):
		for x: int in range(left, right + 1):
			var pos: int = y * ConstantsData.WIDTH + x
			if pos >= 0 and pos < Level.LEN:
				level.set_terrain(pos, terrain)

## Fill a room's full area with a terrain type.
static func fill_room(level: Level, room: Room, terrain: int) -> void:
	fill(level, room.left, room.top, room.right, room.bottom, terrain)

## Fill a room's interior (excluding walls) with a terrain type.
static func fill_interior(level: Level, room: Room, terrain: int) -> void:
	fill(level, room.left + 1, room.top + 1, room.right - 1, room.bottom - 1, terrain)

## Draw a rectangular outline.
static func draw_rect(level: Level, left: int, top: int, right: int, bottom: int, terrain: int) -> void:
	for x: int in range(left, right + 1):
		level.set_terrain(top * ConstantsData.WIDTH + x, terrain)
		level.set_terrain(bottom * ConstantsData.WIDTH + x, terrain)
	for y: int in range(top + 1, bottom):
		level.set_terrain(y * ConstantsData.WIDTH + left, terrain)
		level.set_terrain(y * ConstantsData.WIDTH + right, terrain)

## Draw a line of terrain from pos_a to pos_b (Bresenham).
static func draw_line(level: Level, from_pos: int, to_pos: int, terrain: int) -> void:
	var x0: int = from_pos % ConstantsData.WIDTH
	var y0: int = from_pos / ConstantsData.WIDTH
	var x1: int = to_pos % ConstantsData.WIDTH
	var y1: int = to_pos / ConstantsData.WIDTH

	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy

	while true:
		var pos: int = y0 * ConstantsData.WIDTH + x0
		level.set_terrain(pos, terrain)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy

## Place a single terrain tile at a position.
static func set_cell(level: Level, pos: int, terrain: int) -> void:
	level.set_terrain(pos, terrain)

## Scatter a terrain type across a room's interior at a given density.
static func scatter(level: Level, room: Room, terrain: int, density: float) -> void:
	var interior: Array[int] = room.interior_cells()
	for pos: int in interior:
		if randf() < density:
			level.set_terrain(pos, terrain)

## Place a terrain type at the center of a room.
static func set_center(level: Level, room: Room, terrain: int) -> void:
	level.set_terrain(room.center(), terrain)

## Create a diamond/rhombus pattern inside a room.
static func fill_diamond(level: Level, room: Room, terrain: int) -> void:
	var cx: int = room.center_x()
	var cy: int = room.center_y()
	@warning_ignore("integer_division")
	var rx: int = (room.width() - 3) / 2
	@warning_ignore("integer_division")
	var ry: int = (room.height() - 3) / 2
	var r: int = mini(rx, ry)

	for y: int in range(room.top + 1, room.bottom):
		for x: int in range(room.left + 1, room.right):
			if absi(x - cx) + absi(y - cy) <= r:
				level.set_terrain(y * ConstantsData.WIDTH + x, terrain)

## Create an ellipse pattern inside a room.
static func fill_ellipse(level: Level, room: Room, terrain: int) -> void:
	var cx: float = (room.left + room.right) / 2.0
	var cy: float = (room.top + room.bottom) / 2.0
	var rx: float = (room.width() - 2) / 2.0
	var ry: float = (room.height() - 2) / 2.0

	for y: int in range(room.top + 1, room.bottom):
		for x: int in range(room.left + 1, room.right):
			var dx: float = (x - cx) / rx
			var dy: float = (y - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				level.set_terrain(y * ConstantsData.WIDTH + x, terrain)
