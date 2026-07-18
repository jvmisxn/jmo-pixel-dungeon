extends RefCounted
## Focused coverage for ShadowCaster — the recursive-shadowcasting FOV that all
## visibility/LOS rides on. Uses a 21x21 grid with the origin at center (10,10)
## so radius math stays clear of edges. Assertions target robust invariants
## (origin/neighbor visibility, circular radius cutoff, wall occlusion) rather
## than exact shadow geometry. See backlog audit S22 (geometry core tests).

const W: int = 21
const H: int = 21
const LEN: int = 441  # 21x21
const ORIGIN: int = 220  # (10,10)

func run(t: Object) -> void:
	_test_origin_and_neighbors_visible(t)
	_test_circular_radius_cutoff(t)
	_test_wall_occludes_behind(t)

func _no_blocking() -> Array[bool]:
	var b: Array[bool] = []
	b.resize(LEN)
	b.fill(false)
	return b

func _cell(x: int, y: int) -> int:
	return y * W + x

# In an open field, the origin and all 8 immediate neighbors are lit.
func _test_origin_and_neighbors_visible(t: Object) -> void:
	var vis: Array[bool] = ShadowCaster.cast_fov(ORIGIN, _no_blocking(), W, 5)
	t.check(vis[ORIGIN], "origin is always visible")
	var all_neighbors: bool = true
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if not vis[_cell(10 + dx, 10 + dy)]:
				all_neighbors = false
	t.check(all_neighbors, "all 8 immediate neighbors are visible in open field")

# The circular cutoff: a cardinal cell at exactly the radius is visible; one
# cell further out is not.
func _test_circular_radius_cutoff(t: Object) -> void:
	var vis: Array[bool] = ShadowCaster.cast_fov(ORIGIN, _no_blocking(), W, 5)
	t.check(vis[_cell(10, 15)], "cardinal cell at radius (dist 5) is visible")
	t.check(not vis[_cell(10, 16)], "cell beyond radius (dist 6) is not visible")

# A wall casts a shadow: the wall cell itself is visible, but a cell directly
# behind it (further along the same axis) is occluded. Off-axis cells stay lit.
func _test_wall_occludes_behind(t: Object) -> void:
	var blocking: Array[bool] = _no_blocking()
	blocking[_cell(13, 10)] = true  # wall 3 cells east of origin
	var vis: Array[bool] = ShadowCaster.cast_fov(ORIGIN, blocking, W, 8)
	t.check(vis[_cell(13, 10)], "the wall cell itself is visible")
	t.check(not vis[_cell(16, 10)], "cell directly behind the wall is occluded")
	t.check(vis[_cell(13, 13)], "off-axis clear cell remains visible past the wall")
