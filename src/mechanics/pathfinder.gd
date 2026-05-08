class_name Pathfinder
extends RefCounted
## A* pathfinding on a flat-array grid with 8-directional movement.
## Mirrors Shattered PD's PathFinder.java.

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Find the shortest path from [from_pos] to [to_pos] on a flat grid.
## [passable] is Array[bool] — true means the cell can be walked.
## [width] is the grid width.
## Returns an Array[int] of cell indices from start (exclusive) to goal (inclusive),
## or an empty array if no path exists.
static func find_path(from_pos: int, to_pos: int, passable: Array[bool],
		width: int = 32) -> Array[int]:
	var length: int = passable.size()
	if from_pos < 0 or from_pos >= length or to_pos < 0 or to_pos >= length:
		return []
	if from_pos == to_pos:
		return []
	if not passable[to_pos]:
		return []

	# g_cost: cheapest known cost from start to each cell.
	var g_cost: Dictionary[int, float] = { from_pos: 0.0 }
	# came_from: backtrack map.
	var came_from: Dictionary[int, int] = {}
	# Open set as a simple array-based min-heap keyed by f-cost.
	# Each entry: [f_cost, pos]
	var open: Array[Array] = [[_heuristic(from_pos, to_pos, width), from_pos]]
	var closed: Dictionary[int, bool] = {}

	while not open.is_empty():
		# Pop lowest f-cost entry.
		var best_idx: int = 0
		var best_f: float = open[0][0]
		for i: int in range(1, open.size()):
			if open[i][0] < best_f:
				best_f = open[i][0]
				best_idx = i
		var current_entry: Array = open[best_idx]
		open.remove_at(best_idx)
		var current: int = current_entry[1] as int

		if current == to_pos:
			return _reconstruct(came_from, to_pos)

		if closed.has(current):
			continue
		closed[current] = true

		var neighbors: Array[int] = get_neighbors(current, width, length)
		for neighbor: int in neighbors:
			if closed.has(neighbor):
				continue
			if not passable[neighbor]:
				continue
			# Diagonal movement check: prevent corner-cutting through walls.
			if not _diagonal_passable(current, neighbor, passable, width):
				continue

			var move_cost: float = _step_cost(current, neighbor, width)
			var tentative_g: float = (g_cost[current] as float) + move_cost

			if not g_cost.has(neighbor) or tentative_g < (g_cost[neighbor] as float):
				g_cost[neighbor] = tentative_g
				came_from[neighbor] = current
				var f: float = tentative_g + _heuristic(neighbor, to_pos, width)
				open.append([f, neighbor])

	return []  # No path found.

## Find just the next single step from [from_pos] toward [to_pos].
## Returns the cell index to move to, or -1 if no path exists.
static func find_step(from_pos: int, to_pos: int, passable: Array[bool],
		width: int = 32) -> int:
	var path: Array[int] = find_path(from_pos, to_pos, passable, width)
	if path.is_empty():
		return -1
	return path[0]

## Compute a distance map (BFS flood) from a source cell.
## Returns an Array[float] of distances; unreachable cells have INF.
static func build_distance_map(source: int, passable: Array[bool],
		width: int = 32) -> Array[float]:
	var length: int = passable.size()
	var dist: Array[float] = []
	dist.resize(length)
	dist.fill(INF)

	if source < 0 or source >= length:
		return dist

	dist[source] = 0.0
	var queue: Array[int] = [source]
	var head: int = 0

	while head < queue.size():
		var current: int = queue[head]
		head += 1
		var neighbors: Array[int] = get_neighbors(current, width, length)
		for neighbor: int in neighbors:
			if not passable[neighbor]:
				continue
			if not _diagonal_passable(current, neighbor, passable, width):
				continue
			var new_dist: float = dist[current] + _step_cost(current, neighbor, width)
			if new_dist < dist[neighbor]:
				dist[neighbor] = new_dist
				queue.append(neighbor)

	return dist

# ---------------------------------------------------------------------------
# Neighbor Lookup
# ---------------------------------------------------------------------------

## Return all valid neighbor positions (8-directional) for a cell.
static func get_neighbors(pos: int, width: int, length: int = -1) -> Array[int]:
	if length < 0:
		length = width * width  # assume square
	var result: Array[int] = []
	var x: int = pos % width
	@warning_ignore("integer_division")
	var y: int = pos / width
	@warning_ignore("integer_division")
	var height: int = length / width

	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx >= 0 and nx < width and ny >= 0 and ny < height:
				result.append(ny * width + nx)

	return result

## Chebyshev distance (king moves) between two flat-index positions.
static func distance(a: int, b: int, width: int = 32) -> float:
	var ax: int = a % width
	@warning_ignore("integer_division")
	var ay: int = a / width
	var bx: int = b % width
	@warning_ignore("integer_division")
	var by: int = b / width
	var dx: int = absi(bx - ax)
	var dy: int = absi(by - ay)
	# Octile distance: diag costs sqrt(2), cardinal costs 1.
	return float(maxi(dx, dy)) + (sqrt(2.0) - 1.0) * float(mini(dx, dy))

## Manhattan distance.
static func manhattan(a: int, b: int, width: int = 32) -> int:
	var ax: int = a % width
	@warning_ignore("integer_division")
	var ay: int = a / width
	var bx: int = b % width
	@warning_ignore("integer_division")
	var by: int = b / width
	return absi(bx - ax) + absi(by - ay)

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Octile heuristic for A*.
static func _heuristic(a: int, b: int, width: int) -> float:
	return distance(a, b, width)

## Trace back the path from [to_pos] using the came_from map.
static func _reconstruct(came_from: Dictionary, to_pos: int) -> Array[int]:
	var path: Array[int] = []
	var current: int = to_pos
	while came_from.has(current):
		path.insert(0, current)
		current = came_from[current]
	return path

## Movement cost for one step.
static func _step_cost(from_pos: int, to_pos: int, width: int) -> float:
	var fx: int = from_pos % width
	@warning_ignore("integer_division")
	var fy: int = from_pos / width
	var tx: int = to_pos % width
	@warning_ignore("integer_division")
	var ty: int = to_pos / width
	if fx != tx and fy != ty:
		return sqrt(2.0)  # diagonal
	return 1.0

## Check that a diagonal move doesn't cut through two adjacent walls.
static func _diagonal_passable(from_pos: int, to_pos: int, passable: Array[bool],
		width: int) -> bool:
	var fx: int = from_pos % width
	@warning_ignore("integer_division")
	var fy: int = from_pos / width
	var tx: int = to_pos % width
	@warning_ignore("integer_division")
	var ty: int = to_pos / width
	var dx: int = tx - fx
	var dy: int = ty - fy
	# Only relevant for diagonal moves.
	if dx == 0 or dy == 0:
		return true
	# Both adjacent cardinal cells must be passable to allow diagonal.
	var adj_h: int = fy * width + tx  # horizontal neighbor
	var adj_v: int = ty * width + fx  # vertical neighbor
	return passable[adj_h] and passable[adj_v]
