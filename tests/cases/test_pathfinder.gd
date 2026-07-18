extends RefCounted
## Focused coverage for Pathfinder — the pure A*/BFS grid helpers. Uses a small
## 10-wide grid so neighbor sets and path lengths can be hand-verified. Tests
## the high-blast-radius semantics: edge-wrap-free neighbors, reachability,
## diagonal corner-cut rejection, and distance-map flood. See backlog S22.

const W: int = 10
const LEN: int = 100  # 10x10

func run(t: Object) -> void:
	_test_neighbors_corner(t)
	_test_neighbors_no_edge_wrap(t)
	_test_manhattan_and_distance(t)
	_test_find_path_straight(t)
	_test_find_path_unreachable(t)
	_test_diagonal_corner_cut_rejected(t)
	_test_distance_map(t)

func _all_passable() -> Array[bool]:
	var p: Array[bool] = []
	p.resize(LEN)
	p.fill(true)
	return p

# A corner cell has exactly 3 in-bounds neighbors.
func _test_neighbors_corner(t: Object) -> void:
	var n: Array[int] = Pathfinder.get_neighbors(0, W, LEN)
	t.check(n.size() == 3, "corner cell 0 has 3 neighbors")
	t.check(1 in n and W in n and (W + 1) in n, "corner neighbors are E, S, SE")

# A left-edge cell must not wrap to the previous row's right edge.
func _test_neighbors_no_edge_wrap(t: Object) -> void:
	var n: Array[int] = Pathfinder.get_neighbors(W, W, LEN)  # (0,1)
	t.check(n.size() == 5, "left-edge cell has 5 neighbors, not 8")
	t.check(not (W - 1) in n, "no wrap to prior row's last column (cell 9)")
	t.check(not (2 * W - 1) in n, "no wrap to same/next row's last column (cell 19)")

# Distance helpers: Manhattan is exact ints; octile distance collapses to the
# axis delta for pure cardinal moves.
func _test_manhattan_and_distance(t: Object) -> void:
	t.check(Pathfinder.manhattan(0, 33, W) == 6, "manhattan is |dx|+|dy|")
	t.check(is_equal_approx(Pathfinder.distance(0, 3, W), 3.0), "cardinal octile distance == axis delta")

# Shortest path across an open row is all-cardinal, length == step count.
func _test_find_path_straight(t: Object) -> void:
	var path: Array[int] = Pathfinder.find_path(0, 3, _all_passable(), W)
	t.check(path.size() == 3, "straight 3-cell path has 3 steps")
	t.check(path[path.size() - 1] == 3, "path terminates at the goal")
	t.check(Pathfinder.find_step(0, 3, _all_passable(), W) == path[0], "find_step returns the first path cell")

# A full-height wall column splits the grid: no path across it.
func _test_find_path_unreachable(t: Object) -> void:
	var passable: Array[bool] = _all_passable()
	for y: int in range(10):
		passable[y * W + 5] = false  # solid column x=5
	var path: Array[int] = Pathfinder.find_path(22, 27, passable, W)
	t.check(path.is_empty(), "no path through a full wall column")
	t.check(Pathfinder.find_step(22, 27, passable, W) == -1, "find_step returns -1 when unreachable")

# A diagonal move may not slip between two orthogonally-adjacent walls.
func _test_diagonal_corner_cut_rejected(t: Object) -> void:
	var passable: Array[bool] = _all_passable()
	passable[1] = false   # (1,0) wall
	passable[W] = false   # (0,1) wall
	# From 0, the only remaining neighbor (11, SE) needs both 1 and W passable.
	var path: Array[int] = Pathfinder.find_path(0, 11, passable, W)
	t.check(path.is_empty(), "diagonal move rejected when both flanking cells are walls")

# BFS flood: source is 0, cardinal step is exactly 1.0, walled-off cells are INF.
func _test_distance_map(t: Object) -> void:
	var passable: Array[bool] = _all_passable()
	for y: int in range(10):
		passable[y * W + 5] = false  # solid column x=5
	var dist: Array[float] = Pathfinder.build_distance_map(0, passable, W)
	t.check(dist[0] == 0.0, "source distance is 0")
	t.check(is_equal_approx(dist[1], 1.0), "adjacent cardinal cell is distance 1.0")
	t.check(is_inf(dist[6]), "cell across the wall column is unreachable (INF)")
