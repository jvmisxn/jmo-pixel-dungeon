extends RefCounted
## Focused coverage for Ballistica — the pure Bresenham/DDA ray caster that
## combat, wands, and LOS all ride on. Uses a small 10-wide grid so expected
## cells can be hand-verified. See backlog audit S22 (geometry core tests).

const W: int = 10
const LEN: int = 100  # 10x10

func run(t: Object) -> void:
	_test_straight_wont_stop(t)
	_test_wall_stops_before(t)
	_test_char_stops_on_cell(t)
	_test_stop_target(t)
	_test_magic_bolt_passes_through_target(t)
	_test_diagonal_path(t)
	_test_distance_chebyshev(t)

func _all_passable() -> Array[bool]:
	var p: Array[bool] = []
	p.resize(LEN)
	p.fill(true)
	return p

func _no_occupied() -> Array[bool]:
	return []

# Cast a horizontal ray with no obstacles and WONT_STOP: the path runs to the
# map edge and the "collision" degrades to the final in-bounds cell.
func _test_straight_wont_stop(t: Object) -> void:
	var b: Ballistica = Ballistica.new()
	b.cast(22, 27, _all_passable(), Ballistica.WONT_STOP, _no_occupied(), W)
	# Row 2 (y=2) runs cells 20..29; cast starts at x=2 so path is 22..29.
	t.check(b.path.size() == 8, "WONT_STOP traces to map edge (8 cells)")
	t.check(b.path[0] == 22 and b.path[b.path.size() - 1] == 29, "path spans source to east edge")
	t.check(b.collision_pos == 29, "WONT_STOP collision degrades to last cell")
	# Regression: a horizontal ray must terminate at the east border, never wrap
	# its flat index onto row 3 (cells 30+). Every path cell stays on row 2.
	var stayed_on_row: bool = true
	for c: int in b.path:
		@warning_ignore("integer_division")
		if c / W != 2:
			stayed_on_row = false
	t.check(stayed_on_row, "horizontal ray does not wrap across the map edge")

# A wall directly on the line stops the ray at the cell BEFORE the wall.
func _test_wall_stops_before(t: Object) -> void:
	var passable: Array[bool] = _all_passable()
	passable[25] = false  # wall at (5,2)
	var b: Ballistica = Ballistica.new()
	b.cast(22, 29, passable, Ballistica.STOP_SOLID, _no_occupied(), W)
	t.check(b.collision_pos == 24, "STOP_SOLID stops in front of the wall (cell 24)")
	t.check(b.subpath == ([22, 23, 24] as Array[int]), "subpath ends at the pre-wall cell")

# A character on the line stops the ray ON the occupied cell (not before it).
func _test_char_stops_on_cell(t: Object) -> void:
	var occupied: Array[bool] = _all_passable()  # reuse bool-array of size LEN
	occupied.fill(false)
	occupied[25] = true  # char at (5,2)
	var b: Ballistica = Ballistica.new()
	b.cast(22, 29, _all_passable(), Ballistica.STOP_CHARS, occupied, W)
	t.check(b.collision_pos == 25, "STOP_CHARS stops on the occupied cell (25)")
	t.check(b.subpath[b.subpath.size() - 1] == 25, "subpath ends on the character cell")

# STOP_TARGET halts exactly at the aimed cell.
func _test_stop_target(t: Object) -> void:
	var b: Ballistica = Ballistica.new()
	b.cast(22, 25, _all_passable(), Ballistica.STOP_TARGET, _no_occupied(), W)
	t.check(b.collision_pos == 25, "STOP_TARGET halts at the aimed cell")
	t.check(b.subpath == ([22, 23, 24, 25] as Array[int]), "subpath is source..target inclusive")

# MAGIC_BOLT (no STOP_TARGET) sails past the aimed cell to the next obstacle /
# map edge — the wand-bolt semantics.
func _test_magic_bolt_passes_through_target(t: Object) -> void:
	var b: Ballistica = Ballistica.new()
	b.cast(22, 25, _all_passable(), Ballistica.MAGIC_BOLT, _no_occupied(), W)
	t.check(b.collision_pos == 29, "MAGIC_BOLT passes through target to the edge")
	t.check(25 in b.path, "aimed cell is still part of the traced path")

# A perfect diagonal keeps x==y along the ray.
func _test_diagonal_path(t: Object) -> void:
	var subpath: Array[int] = Ballistica.cast_line(
		22, 55, _all_passable(), Ballistica.STOP_TARGET, _no_occupied(), W
	)
	# (2,2)->(5,5): cells 22,33,44,55.
	t.check(subpath == ([22, 33, 44, 55] as Array[int]), "diagonal ray walks the x==y cells")

# Chebyshev (king-move) distance helper.
func _test_distance_chebyshev(t: Object) -> void:
	t.check(Ballistica.distance(22, 27, W) == 5, "cardinal distance is the axis delta")
	t.check(Ballistica.distance(22, 65, W) == 4, "diagonal-ish distance is max(dx,dy)")
	t.check(Ballistica.distance(22, 22, W) == 0, "distance to self is 0")
