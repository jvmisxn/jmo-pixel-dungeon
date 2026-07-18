extends RefCounted
## AoE plants must not wrap across a map edge. Icecap freezing and Firebloom
## grass ignition iterate DIRS_8 as `pos + dir`; at column 0 / WIDTH-1 the
## E/W/diagonal offsets land on the opposite edge of an adjacent row. A plant
## triggered against a wall must only affect true 8-neighbours, never a cell
## across the map. See backlog audit S19 (grid edge-wrap).

class FakeIcecapLevel:
	extends RefCounted

	var chars_by_pos: Dictionary = {}

	func find_char_at(cell: int) -> Variant:
		return chars_by_pos.get(cell, null)

class FakeFirebloomLevel:
	extends RefCounted

	var terrain: Dictionary = {}

	func terrain_at(cell: int) -> int:
		return int(terrain.get(cell, ConstantsData.Terrain.EMPTY))

	func set_terrain(cell: int, value: int) -> void:
		terrain[cell] = value

func run(t: Object) -> void:
	_test_icecap_no_edge_wrap(t)
	_test_firebloom_no_edge_wrap(t)

func _make_char(cell: int) -> Char:
	var ch: Char = Char.new()
	ch.pos = cell
	ch.hp = 20
	ch.hp_max = 20
	ch.ht = 20
	ch.name = "test char"
	return ch

func _test_icecap_no_edge_wrap(t: Object) -> void:
	# Plant at column 0 of row 1 (cell = W). The North neighbour (cell 0) is a
	# real 8-neighbour; the West offset (cell W-1) wraps to row 0's last column.
	var plant_pos: int = Level.W          # row 1, column 0
	var real_neighbour: int = 0           # row 0, column 0 (North)
	var wrap_cell: int = Level.W - 1      # row 0, last column (West wrap)

	var level := FakeIcecapLevel.new()
	var neighbour_char: Char = _make_char(real_neighbour)
	var wrapped_char: Char = _make_char(wrap_cell)
	level.chars_by_pos[real_neighbour] = neighbour_char
	level.chars_by_pos[wrap_cell] = wrapped_char

	var icecap := Icecap.new()
	icecap.pos = plant_pos
	icecap._do_effect(neighbour_char, level)

	t.check(neighbour_char.has_buff("Frozen"), "Icecap freezes a true 8-neighbour")
	t.check(
		not wrapped_char.has_buff("Frozen"),
		"Icecap does not freeze a cell that wrapped across the map edge"
	)

	neighbour_char.free()
	wrapped_char.free()

func _test_firebloom_no_edge_wrap(t: Object) -> void:
	var plant_pos: int = Level.W          # row 1, column 0
	var real_neighbour: int = 0           # row 0, column 0 (North)
	var wrap_cell: int = Level.W - 1      # row 0, last column (West wrap)

	var level := FakeFirebloomLevel.new()
	level.terrain[real_neighbour] = ConstantsData.Terrain.HIGH_GRASS
	level.terrain[wrap_cell] = ConstantsData.Terrain.HIGH_GRASS

	var firebloom := Firebloom.new()
	firebloom.pos = plant_pos
	# Null trigger char: exercise only the grass-ignition loop.
	firebloom._do_effect(null, level)

	t.check(
		level.terrain_at(real_neighbour) == ConstantsData.Terrain.EMBERS,
		"Firebloom ignites grass on a true 8-neighbour"
	)
	t.check(
		level.terrain_at(wrap_cell) == ConstantsData.Terrain.HIGH_GRASS,
		"Firebloom does not ignite grass that wrapped across the map edge"
	)
