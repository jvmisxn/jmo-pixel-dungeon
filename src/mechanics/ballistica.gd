class_name Ballistica
extends RefCounted
## Line-of-sight and projectile trajectory calculation using Bresenham's line.
## Mirrors Shattered PD's Ballistica.java — casts a ray from one cell to
## another, stopping based on configurable collision rules.

# --- Stop Condition Flags (combinable with bitwise OR) ---
## Stop when hitting a solid/wall tile.
const STOP_SOLID: int = 1
## Stop when hitting a cell occupied by a character (mob/hero).
const STOP_CHARS: int = 2
## Stop exactly at the target cell.
const STOP_TARGET: int = 4
## Ignore soft solid terrain (doors, webs) that is passable/avoidable.
const IGNORE_SOFT_SOLID: int = 8
## Projectile mode: stops at target or solid or chars, whichever comes first.
const PROJECTILE: int = STOP_TARGET | STOP_CHARS | STOP_SOLID
## Magic bolt mode: passes THROUGH target, stops at chars or solid.
## Used by wands — the bolt continues past the aimed cell until hitting
## a character or wall. Original: STOP_CHARS | STOP_SOLID (no STOP_TARGET).
const MAGIC_BOLT: int = STOP_CHARS | STOP_SOLID
## Won't stop at anything — traces the full line to map edge.
const WONT_STOP: int = 0

# --- Result Data ---
## The full trajectory as an array of flat-index positions.
var path: Array[int] = []
## The cell where the projectile actually stops (collision point).
var collision_pos: int = -1
## Index into [path] where collision occurred.
var collision_index: int = -1
## Subpath from source up to and including the collision point.
var subpath: Array[int] = []

# ---------------------------------------------------------------------------
# Construction / Casting
# ---------------------------------------------------------------------------

## Cast a ray from [from_pos] toward [to_pos] on a grid of the given [width].
## [passable] marks which cells can be traversed (true = passable).
## [occupied] marks which cells contain a character (true = occupied). Can be empty.
## [params] is a bitmask of STOP_* constants.
## Returns this Ballistica instance for chaining.
##
## NOTE: The full path extends past the collision point to the map edge,
## matching the original Ballistica.java behavior. Use subpath for the
## common source→collision segment.
func cast(from_pos: int, to_pos: int, passable: Array[bool], params: int,
		occupied: Array[bool] = [], width: int = 32, terrain: Array[int] = []) -> Ballistica:
	path.clear()
	subpath.clear()
	collision_pos = -1
	collision_index = -1

	var length: int = passable.size()
	@warning_ignore("integer_division")
	var height: int = length / width

	var x0: int = from_pos % width
	@warning_ignore("integer_division")
	var y0: int = from_pos / width
	var x1: int = to_pos % width
	@warning_ignore("integer_division")
	var y1: int = to_pos / width

	# --- DDA line (matches original Ballistica.build()) ---
	# Step along the major axis every iteration, minor axis when error accumulates.
	var dx: int = x1 - x0
	var dy: int = y1 - y0
	var step_x: int = 1 if dx > 0 else -1
	var step_y: int = 1 if dy > 0 else -1
	dx = absi(dx)
	dy = absi(dy)

	var step_a: int  # Step along major axis (as flat-array offset)
	var step_b: int  # Step along minor axis (as flat-array offset)
	var d_a: int     # Major axis distance
	var d_b: int     # Minor axis distance
	# Per-step x/y components, so we can bound on TRUE grid coordinates instead
	# of re-deriving them from a flat index. A pure horizontal step is a flat
	# offset of +-1, which silently wraps x from width-1 to 0 of the next row;
	# tracking cur_x/cur_y explicitly (as SPD's Ballistica does) prevents rays
	# from teleporting across the map edge to an adjacent row.
	var maj_dx: int
	var maj_dy: int
	var min_dx: int
	var min_dy: int

	if dx > dy:
		step_a = step_x
		step_b = step_y * width
		d_a = dx
		d_b = dy
		maj_dx = step_x
		maj_dy = 0
		min_dx = 0
		min_dy = step_y
	else:
		step_a = step_y * width
		step_b = step_x
		d_a = dy
		d_b = dx
		maj_dx = 0
		maj_dy = step_y
		min_dx = step_x
		min_dy = 0

	var cell: int = from_pos
	var cur_x: int = x0
	var cur_y: int = y0
	var err: int = d_a >> 1 if d_a > 0 else 0

	# Build the FULL path to the map edge (original continues past collision)
	while cur_x >= 0 and cur_x < width and cur_y >= 0 and cur_y < height:
		# Check collision BEFORE adding to path for terrain that's impassable
		# with no character present — collide at the PREVIOUS cell
		if collision_pos < 0 and (params & STOP_SOLID) != 0 and cell != from_pos:
			if cell < 0 or cell >= length or (not passable[cell] and (occupied.is_empty() or cell >= occupied.size() or not occupied[cell])):
				# Collide at previous cell (the ray hit a wall)
				if not path.is_empty():
					collision_pos = path[path.size() - 1]
					collision_index = path.size() - 1

		path.append(cell)

		# Additional collision checks at current cell (after adding to path)
		if collision_pos < 0 and cell != from_pos:
			# Solid terrain collision (cell is solid, not just impassable)
			if (params & STOP_SOLID) != 0:
				if cell >= 0 and cell < length and not passable[cell]:
					var soft_solid: bool = false
					if (params & IGNORE_SOFT_SOLID) != 0:
						# Doors and webs are "soft solid" — passable/avoidable
						# Since avoid[] is not implemented yet, treat all solids as hard solids.
						soft_solid = _is_soft_solid_terrain(cell, terrain)
					if not soft_solid:
						collision_pos = cell
						collision_index = path.size() - 1

			# Character collision
			if collision_pos < 0 and (params & STOP_CHARS) != 0:
				if occupied.size() > 0 and cell >= 0 and cell < occupied.size() and occupied[cell]:
					collision_pos = cell
					collision_index = path.size() - 1

			# Target reached
			if collision_pos < 0 and (params & STOP_TARGET) != 0:
				if cell == to_pos:
					collision_pos = cell
					collision_index = path.size() - 1

		# DDA step: always step along major axis
		cell += step_a
		cur_x += maj_dx
		cur_y += maj_dy
		err += d_b
		if err >= d_a and d_a > 0:
			err -= d_a
			cell += step_b
			cur_x += min_dx
			cur_y += min_dy

	# If nothing collided, collision is last cell in path
	if collision_pos < 0 and not path.is_empty():
		collision_pos = path[path.size() - 1]
		collision_index = path.size() - 1

	# Build subpath: source through collision (inclusive)
	subpath.clear()
	if collision_index >= 0:
		for i: int in range(collision_index + 1):
			subpath.append(path[i])
	elif not path.is_empty():
		subpath = path.duplicate()

	return self


func _is_soft_solid_terrain(cell: int, terrain: Array[int]) -> bool:
	if terrain.is_empty() or cell < 0 or cell >= terrain.size():
		return false
	match terrain[cell]:
		ConstantsData.Terrain.DOOR, ConstantsData.Terrain.WEB:
			return true
		_:
			return false


# ---------------------------------------------------------------------------
# Static Helpers
# ---------------------------------------------------------------------------

## Convenience: cast a line and return the subpath (array of cell positions).
## Creates a temporary Ballistica instance, casts the ray, and returns the
## subpath from source to collision point.
static func cast_line(from_pos: int, to_pos: int, passable: Array[bool],
		params: int, occupied: Array[bool] = [],
		width: int = ConstantsData.WIDTH, terrain: Array[int] = []) -> Array[int]:
	var b: Ballistica = Ballistica.new()
	b.cast(from_pos, to_pos, passable, params, occupied, width, terrain)
	return b.subpath


## Chebyshev (king-move) distance between two flat-index cells.
## Matches original SPD Level.distance(a, b).
static func distance(a: int, b: int, width: int = ConstantsData.WIDTH) -> int:
	var ax: int = a % width
	@warning_ignore("integer_division")
	var ay: int = a / width
	var bx: int = b % width
	@warning_ignore("integer_division")
	var by: int = b / width
	return maxi(absi(ax - bx), absi(ay - by))
