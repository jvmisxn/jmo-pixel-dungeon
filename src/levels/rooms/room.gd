class_name Room
extends RefCounted
## Base Room class for dungeon generation.
## A room is a rectangular region defined by (left, top, right, bottom) in tile coords.
## Mirrors Shattered PD's Room.java.

# --- Room Type ---
enum Type { STANDARD, CONNECTION, ENTRANCE, EXIT, SPECIAL, SECRET }

var type: Type = Type.STANDARD

# --- Bounds (inclusive) ---
var left: int = 0
var top: int = 0
var right: int = 0
var bottom: int = 0

# --- Connections to other rooms ---
## Maps Room -> door position (int). Represents doors connecting this room to neighbors.
var connected: Dictionary[Room, int] = {}

# --- Neighbors in the room graph (rooms we can potentially connect to) ---
var neighbors: Array[Room] = []

# --- State ---
var painted: bool = false

# ---------------------------------------------------------------------------
# Dimensions
# ---------------------------------------------------------------------------

func width() -> int:
	return right - left + 1

func height() -> int:
	return bottom - top + 1

func area() -> int:
	return width() * height()

func center_x() -> int:
	return (left + right) / 2

func center_y() -> int:
	return (top + bottom) / 2

func center() -> int:
	return center_y() * ConstantsData.WIDTH + center_x()

# ---------------------------------------------------------------------------
# Geometry Queries
# ---------------------------------------------------------------------------

## Returns true if the position (flat index) is inside this room (including walls).
func inside(pos: int) -> bool:
	var x: int = pos % ConstantsData.WIDTH
	var y: int = pos / ConstantsData.WIDTH
	return x >= left and x <= right and y >= top and y <= bottom

## Returns true if the position is in the room's interior (not on walls).
func inside_interior(pos: int) -> bool:
	var x: int = pos % ConstantsData.WIDTH
	var y: int = pos / ConstantsData.WIDTH
	return x > left and x < right and y > top and y < bottom

## Returns true if the position is on the room's perimeter.
func on_border(pos: int) -> bool:
	return inside(pos) and not inside_interior(pos)

## Returns a random interior position.
func random_interior() -> int:
	if width() <= 2 or height() <= 2:
		return center()
	var x: int = randi_range(left + 1, right - 1)
	var y: int = randi_range(top + 1, bottom - 1)
	return y * ConstantsData.WIDTH + x

## Returns a random position on the border suitable for a door.
func random_door_pos() -> int:
	# Pick a random wall cell that's not a corner
	var candidates: Array[int] = []
	# Top and bottom walls (excluding corners)
	for x: int in range(left + 1, right):
		candidates.append(top * ConstantsData.WIDTH + x)
		candidates.append(bottom * ConstantsData.WIDTH + x)
	# Left and right walls (excluding corners)
	for y: int in range(top + 1, bottom):
		candidates.append(y * ConstantsData.WIDTH + left)
		candidates.append(y * ConstantsData.WIDTH + right)
	if candidates.is_empty():
		return center()
	return candidates[randi_range(0, candidates.size() - 1)]

## Returns all interior positions as an array.
func interior_cells() -> Array[int]:
	var cells: Array[int] = []
	for y: int in range(top + 1, bottom):
		for x: int in range(left + 1, right):
			cells.append(y * ConstantsData.WIDTH + x)
	return cells

## Returns all positions (including border).
func all_cells() -> Array[int]:
	var cells: Array[int] = []
	for y: int in range(top, bottom + 1):
		for x: int in range(left, right + 1):
			cells.append(y * ConstantsData.WIDTH + x)
	return cells

# ---------------------------------------------------------------------------
# Overlap / Intersection
# ---------------------------------------------------------------------------

## Check if this room overlaps with another room (with optional margin).
func intersects(other: Room, margin: int = 0) -> bool:
	return not (right + margin < other.left or other.right + margin < left or \
		bottom + margin < other.top or other.bottom + margin < top)

## Check if this room is fully within the level bounds.
func in_bounds() -> bool:
	return left >= 1 and top >= 1 and right < ConstantsData.WIDTH - 1 and bottom < ConstantsData.HEIGHT - 1 \
		and left < right and top < bottom

# ---------------------------------------------------------------------------
# Connection Management
# ---------------------------------------------------------------------------

## Maximum number of connections this room can have.
## Original: StandardRoom returns ALL (unlimited), Special/Secret rooms return 1-2.
## Override in subclasses to restrict door count.
func max_connections(direction: int = -1) -> int:
	# -1 means total across all directions. direction 0-3 = specific side.
	return 999  # unlimited by default (StandardRoom behavior)

## Returns true if this room can accept another connection.
func can_connect() -> bool:
	return connected.size() < max_connections()

## Connect this room to another at a specific door position.
func connect_to(other: Room, door_pos: int) -> void:
	connected[other] = door_pos
	other.connected[self] = door_pos

## Check if this room is connected to another.
func is_connected_to(other: Room) -> bool:
	return connected.has(other)

## Get the door position connecting to another room, or -1.
func door_to(other: Room) -> int:
	if connected.has(other):
		return connected[other]
	return -1

## Find a valid door position between this room and an adjacent room.
func find_door_pos(other: Room) -> int:
	# Find shared wall cells
	var candidates: Array[int] = []

	# Check if rooms share a vertical wall
	if right == other.left or left == other.right:
		var shared_x: int = right if right == other.left else left
		var min_y: int = maxi(top + 1, other.top + 1)
		var max_y: int = mini(bottom - 1, other.bottom - 1)
		for y: int in range(min_y, max_y + 1):
			candidates.append(y * ConstantsData.WIDTH + shared_x)

	# Check if rooms share a horizontal wall
	if bottom == other.top or top == other.bottom:
		var shared_y: int = bottom if bottom == other.top else top
		var min_x: int = maxi(left + 1, other.left + 1)
		var max_x: int = mini(right - 1, other.right - 1)
		for x: int in range(min_x, max_x + 1):
			candidates.append(shared_y * ConstantsData.WIDTH + x)

	if candidates.is_empty():
		return -1
	return candidates[randi_range(0, candidates.size() - 1)]

# ---------------------------------------------------------------------------
# Size Requirements (override in subclasses)
# ---------------------------------------------------------------------------

func min_width() -> int:
	return 5

func min_height() -> int:
	return 5

func max_width() -> int:
	return 10

func max_height() -> int:
	return 10

# ---------------------------------------------------------------------------
# Sizing
# ---------------------------------------------------------------------------

## Set the room to a random valid size.
func set_random_size() -> void:
	var w: int = randi_range(min_width(), max_width())
	var h: int = randi_range(min_height(), max_height())
	right = left + w - 1
	bottom = top + h - 1

## Set the room to a specific size.
func set_size(w: int, h: int) -> void:
	right = left + w - 1
	bottom = top + h - 1

## Shift the room so its top-left is at (x, y).
func set_pos(x: int, y: int) -> void:
	var w: int = width()
	var h: int = height()
	left = x
	top = y
	right = x + w - 1
	bottom = y + h - 1

# ---------------------------------------------------------------------------
# Painting (override in subclasses)
# ---------------------------------------------------------------------------

## Paint this room's terrain onto the level map.
## The base implementation fills interior with EMPTY_SP and borders with WALL.
func paint(level: Level) -> void:
	# Fill walls
	for pos: int in all_cells():
		level.set_terrain(pos, ConstantsData.Terrain.WALL)
	# Fill interior
	for pos: int in interior_cells():
		level.set_terrain(pos, ConstantsData.Terrain.EMPTY)
	# Place doors from connections
	for door_pos: int in connected.values():
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)
