class_name ShadowCaster
extends RefCounted
## Recursive shadowcasting FOV algorithm.
##
## Faithfully ported from Shattered PD's ShadowCaster.java.
## Uses 8-octant recursive shadowcasting with a precomputed rounding
## table for circular FOV and 0.499 offsets to prevent vision leaking.
##
## Usage:
##   var visible: Array[bool] = ShadowCaster.cast_fov(origin, blocking, width, radius)

const MAX_DISTANCE: int = 20

## Precomputed rounding table — limits how many columns are scanned per row
## at each distance, producing a circular FOV shape.
static var _rounding: Array[Array] = []
static var _rounding_initialized: bool = false

static func _init_rounding() -> void:
	if _rounding_initialized:
		return
	_rounding_initialized = true
	_rounding.resize(MAX_DISTANCE + 1)
	for i: int in range(1, MAX_DISTANCE + 1):
		var row_arr: Array[int] = []
		row_arr.resize(i + 1)
		row_arr.fill(0)
		for j: int in range(1, i + 1):
			# Testing the middle of a cell, so we use i + 0.5
			row_arr[j] = mini(j, roundi(float(i) * cos(asin(float(j) / (float(i) + 0.5)))))
		_rounding[i] = row_arr

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Calculate field of view from [origin] on a flat grid.
## [blocking] is an Array[bool] of size width*height — true where vision is blocked.
## [width] is the grid width (columns).
## [view_distance] is the maximum sight radius.
## Returns an Array[bool] of the same length where true = visible.
static func cast_fov(origin: int, blocking: Array[bool], width: int, view_distance: int) -> Array[bool]:
	_init_rounding()

	var length: int = blocking.size()
	var visible: Array[bool] = []
	visible.resize(length)
	visible.fill(false)

	if view_distance > MAX_DISTANCE:
		view_distance = MAX_DISTANCE

	# The origin is always visible.
	if origin >= 0 and origin < length:
		visible[origin] = true

	var ox: int = origin % width
	var oy: int = origin / width

	# Scans octants, clockwise — matches original SPD octant ordering.
	# Each call uses mirroring parameters (mX, mY, mXY) instead of
	# explicit octant coordinate transforms.
	_scan_octant(view_distance, visible, blocking, 1, ox, oy, width, length, 0.0, 1.0,  +1, -1, false)
	_scan_octant(view_distance, visible, blocking, 1, ox, oy, width, length, 0.0, 1.0,  -1, +1, true)
	_scan_octant(view_distance, visible, blocking, 1, ox, oy, width, length, 0.0, 1.0,  +1, +1, true)
	_scan_octant(view_distance, visible, blocking, 1, ox, oy, width, length, 0.0, 1.0,  +1, +1, false)
	_scan_octant(view_distance, visible, blocking, 1, ox, oy, width, length, 0.0, 1.0,  -1, +1, false)
	_scan_octant(view_distance, visible, blocking, 1, ox, oy, width, length, 0.0, 1.0,  +1, -1, true)
	_scan_octant(view_distance, visible, blocking, 1, ox, oy, width, length, 0.0, 1.0,  -1, -1, true)
	_scan_octant(view_distance, visible, blocking, 1, ox, oy, width, length, 0.0, 1.0,  -1, -1, false)

	return visible

# ---------------------------------------------------------------------------
# Octant Scan — direct port of SPD's scanOctant()
# ---------------------------------------------------------------------------

## Scans a single 45-degree octant of the FOV.
## mX/mY mirror in X and Y; mXY swaps X and Y axes.
## lSlope/rSlope define the unblocked arc (0.0 to 1.0).
static func _scan_octant(
	distance: int,
	fov: Array[bool],
	blocking: Array[bool],
	row: int,
	x: int, y: int,
	w: int,
	length: int,
	l_slope: float,
	r_slope: float,
	m_x: int, m_y: int,
	m_xy: bool,
) -> void:
	var in_blocking: bool = false
	var start: int
	var end: int
	var col: int

	# Get rounding table for this distance. At distance 2, fill in corners
	# to avoid disproportionately punishing diagonal movement.
	var rounding_at_dist: Array[int]
	if distance == 2:
		rounding_at_dist = (_rounding[distance] as Array[int]).duplicate()
		rounding_at_dist[2] = 2
	else:
		rounding_at_dist = _rounding[distance] as Array[int]

	# Calculations offset by 0.5 because FOV originates from cell center.
	# For each row, starting with the current one:
	while row <= distance:
		if l_slope >= r_slope:
			break

		# Determine the column range for this row based on the rounding table
		if row < rounding_at_dist.size():
			end = rounding_at_dist[row]
		else:
			end = row

		start = maxi(0, int(ceilf(float(row) * l_slope - 0.499)))

		col = start
		while col <= end:
			# Calculate the slope for the left and right edges of this cell
			var left_slope: float = float(col) / (float(row) + 0.5)
			var right_slope: float = (float(col) + 1.0) / (float(row) - 0.5)

			if right_slope <= l_slope:
				col += 1
				continue
			if left_slope >= r_slope:
				break

			# Map octant coordinates to grid coordinates
			var g_col: int = col * m_x
			var g_row: int = row * m_y
			var real_x: int
			var real_y: int
			if m_xy:
				real_x = x + g_row
				real_y = y + g_col
			else:
				real_x = x + g_col
				real_y = y + g_row

			var pos: int = real_y * w + real_x

			# Check bounds
			if real_x >= 0 and real_x < w and pos >= 0 and pos < length:
				fov[pos] = true

				if blocking[pos]:
					# This cell blocks vision
					if not in_blocking:
						in_blocking = true
						# Recursively scan the remaining unblocked portion
						if col > start:
							_scan_octant(distance, fov, blocking, row + 1,
								x, y, w, length,
								l_slope, left_slope,
								m_x, m_y, m_xy)
					# Narrow the left slope for the next open section
					l_slope = right_slope
				else:
					# This cell is open
					if in_blocking:
						in_blocking = false
			col += 1

		# If we ended the row while in a blocking run, no further rows will
		# be visible in this octant.
		if in_blocking:
			break
		row += 1
