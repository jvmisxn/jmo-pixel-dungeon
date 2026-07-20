extends RefCounted
## Vertigo's randomize_direction picks a random true 8-neighbour of the current
## cell. It iterates the flat-array direction offsets as `current_pos + dir`; at
## column 0 / WIDTH-1 the E/W/diagonal offsets land on the opposite edge of an
## adjacent row. A dizzy character standing at a column edge must never be shoved
## to a cell that wrapped across the map. See backlog audit S06/S19 (grid
## edge-wrap) and the plant edge-wrap regression.

class FakeLevel:
	extends RefCounted

	# Every in-bounds cell is passable so the ONLY thing that can reject a
	# candidate is the column-adjacency edge-wrap guard.
	func is_passable(cell: int) -> bool:
		return cell >= 0 and cell < Level.LEN

func run(t: Object) -> void:
	# Deterministic RNG so the sampling loop is reproducible across runs.
	seed(20260719)

	var ch: Char = Char.new()
	ch.name = "dizzy"
	ch.hp = 10
	ch.hp_max = 10
	ch.ht = 10
	ch.pos = Level.W          # row 1, column 0 (a left-edge cell)
	ch.level = FakeLevel.new()

	var vertigo := Vertigo.new()
	vertigo.target = ch

	var col0: int = ch.pos % Level.W
	# Cells that would only appear via horizontal edge-wrap from column 0.
	var west_wrap: int = ch.pos - 1              # col W-1, previous row
	var sw_wrap: int = ch.pos + Level.W - 1      # col W-1, next row

	var saw_real_neighbour: bool = false
	var wrapped_ever: bool = false
	var out_of_column: bool = false
	for _i: int in range(400):
		var dest: int = vertigo.randomize_direction(999, ch.pos)
		if dest == west_wrap or dest == sw_wrap:
			wrapped_ever = true
		if absi(dest % Level.W - col0) > 1:
			out_of_column = true
		if dest < 0 or dest >= Level.LEN:
			out_of_column = true
		if dest == 0 or dest == Level.W * 2:  # North / South true neighbours
			saw_real_neighbour = true

	t.check(not wrapped_ever, "Vertigo never shoves a left-edge char to a wrapped cell")
	t.check(not out_of_column, "Vertigo destinations stay within one column and in bounds")
	t.check(saw_real_neighbour, "Vertigo still returns real cardinal neighbours")

	# When no legal neighbour is passable, fall back to the intended cell.
	var walled := Vertigo.new()
	var boxed: Char = Char.new()
	boxed.name = "boxed"
	boxed.pos = Level.W + 1
	boxed.level = _blocked_level()
	walled.target = boxed
	t.check(
		walled.randomize_direction(555, boxed.pos) == 555,
		"Vertigo returns the intended cell when no neighbour is passable"
	)

	vertigo.free()
	walled.free()
	ch.free()
	boxed.free()

func _blocked_level() -> RefCounted:
	return BlockedLevel.new()

class BlockedLevel:
	extends RefCounted

	func is_passable(_cell: int) -> bool:
		return false
