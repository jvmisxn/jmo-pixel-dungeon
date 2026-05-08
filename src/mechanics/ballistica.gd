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
		occupied: Array[bool] = [], width: int = 32) -> Ballistica:
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

	if dx > dy:
		step_a = step_x
		step_b = step_y * width
		d_a = dx
		d_b = dy
	else:
		step_a = step_y * width
		step_b = step_x
		d_a = dy
		d_b = dx

	var cell: int = from_pos
	var err: int = d_a / 2 if d_a > 0 else 0

	# Build the FULL path to the map edge (original continues past collision)
	while _inside_map(cell, width, height):
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
						# Since they're not passable here, only check avoidable terrain
						var terrain: int = -1
						if cell < length:
							terrain = ConstantsData.terrain_is_passable(0)  # placeholder
						soft_solid = false  # simplified: no avoid[] array yet
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
		err += d_b
		if err >= d_a and d_a > 0:
			err -= d_a
			cell += step_b

	# If nothing collided, collision is last cell in path
	if collision_pos < 0 and not path.is_empty():
		collision_pos = path[path.size() - 1]
		collision_index = path.size() - 1
