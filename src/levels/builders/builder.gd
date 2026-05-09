class_name Builder
extends RefCounted
## Base class for level layout builders.
## A builder takes a list of rooms and arranges them on the grid,
## establishing connections (doors) between rooms.
## Mirrors Shattered PD's Builder.java.

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Build a layout from the given rooms. Returns true on success.
## Subclasses override this.
func build(_rooms: Array) -> bool:
	return false

# ---------------------------------------------------------------------------
# Shared Utilities
# ---------------------------------------------------------------------------

## Try to place a room adjacent to a target room on a random side.
## Returns true if placement succeeded (room fits in bounds, no overlap).
static func place_adjacent(room: Room, target: Room, all_rooms: Array, margin: int = 0) -> bool:
	var sides: Array[int] = [0, 1, 2, 3]
	sides.shuffle()

	for side: int in sides:
		_position_on_side(room, target, side)
		if _is_valid_placement(room, all_rooms, margin):
			return true
	return false

## Position [room] on the given side of [target] with a 1-tile gap between them.
## The gap leaves space for corridor tunnels to be carved between rooms.
## 0=right, 1=bottom, 2=left, 3=top
static func _position_on_side(room: Room, target: Room, side: int) -> void:
	# CRITICAL: Cache dimensions before modifying coordinates.
	# room.width()/height() compute from (right-left+1)/(bottom-top+1),
	# so changing left/top first corrupts subsequent reads.
	var w: int = room.width()
	var h: int = room.height()
	# Gap between rooms — creates space for corridor tunnels.
	# +2 means 1 empty tile between room walls (target.right, gap, room.left).
	var gap: int = 2
	match side:
		0:  # Right
			room.left = target.right + gap
			room.right = room.left + w - 1
			# Vertically align with some random offset
			var min_y: int = target.top - h + 3
			var max_y: int = target.bottom - 2
			if min_y > max_y:
				min_y = target.top
				max_y = target.top
			room.top = randi_range(min_y, max_y)
			room.bottom = room.top + h - 1
		1:  # Bottom
			room.top = target.bottom + gap
			room.bottom = room.top + h - 1
			var min_x: int = target.left - w + 3
			var max_x: int = target.right - 2
			if min_x > max_x:
				min_x = target.left
				max_x = target.left
			room.left = randi_range(min_x, max_x)
			room.right = room.left + w - 1
		2:  # Left
			room.right = target.left - gap
			room.left = room.right - w + 1
			var min_y: int = target.top - h + 3
			var max_y: int = target.bottom - 2
			if min_y > max_y:
				min_y = target.top
				max_y = target.top
			room.top = randi_range(min_y, max_y)
			room.bottom = room.top + h - 1
		3:  # Top
			room.bottom = target.top - gap
			room.top = room.bottom - h + 1
			var min_x: int = target.left - w + 3
			var max_x: int = target.right - 2
			if min_x > max_x:
				min_x = target.left
				max_x = target.left
			room.left = randi_range(min_x, max_x)
			room.right = room.left + w - 1

## Check if a room placement is valid: in bounds and no overlaps.
static func _is_valid_placement(room: Room, all_rooms: Array, margin: int = 0) -> bool:
	if not room.in_bounds():
		return false
	for other: Variant in all_rooms:
		if other == room:
			continue
		if other is Room and room.intersects(other as Room, margin):
			return false
	return true

## Find two adjacent rooms that share a wall and connect them with a door.
## Respects max_connections() — won't create a door if either room is at capacity.
static func connect_adjacent(a: Room, b: Room) -> bool:
	# Check connection limits before creating a door
	if not a.can_connect() or not b.can_connect():
		return false
	var door_pos: int = a.find_door_pos(b)
	if door_pos < 0:
		return false
	a.connect_to(b, door_pos)
	return true

## Build a tunnel (line of empty cells) between two positions.
## Used when rooms aren't directly adjacent.
static func build_tunnel(level: Level, from_pos: int, to_pos: int) -> void:
	var fx: int = from_pos % ConstantsData.WIDTH
	var fy: int = from_pos / ConstantsData.WIDTH
	var tx: int = to_pos % ConstantsData.WIDTH
	var ty: int = to_pos / ConstantsData.WIDTH

	# L-shaped tunnel: horizontal first, then vertical (or vice versa)
	if randi() % 2 == 0:
		# Horizontal first
		_carve_h_line(level, fx, tx, fy)
		_carve_v_line(level, fy, ty, tx)
	else:
		# Vertical first
		_carve_v_line(level, fy, ty, fx)
		_carve_h_line(level, fx, tx, ty)

static func _carve_h_line(level: Level, x1: int, x2: int, y: int) -> void:
	var start_x: int = mini(x1, x2)
	var end_x: int = maxi(x1, x2)
	for x: int in range(start_x, end_x + 1):
		var pos: int = y * ConstantsData.WIDTH + x
		if level.terrain_at(pos) == ConstantsData.Terrain.WALL:
			level.set_terrain(pos, ConstantsData.Terrain.EMPTY)

static func _carve_v_line(level: Level, y1: int, y2: int, x: int) -> void:
	var start_y: int = mini(y1, y2)
	var end_y: int = maxi(y1, y2)
	for y: int in range(start_y, end_y + 1):
		var pos: int = y * ConstantsData.WIDTH + x
		if level.terrain_at(pos) == ConstantsData.Terrain.WALL:
			level.set_terrain(pos, ConstantsData.Terrain.EMPTY)
