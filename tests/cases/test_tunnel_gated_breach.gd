extends RefCounted
## Gated special-room walls must never be breached by tunnel carving
## (audit:S08): an L-shaped tunnel leg crossing a secret/vault/crystal
## border may only open the designated door endpoint, never extra wall
## cells. Covers Builder.build_tunnel protected-cell support and
## StandardPainter._gated_border_cells.

const SEALED_TERRAINS: Array[int] = [
	ConstantsData.Terrain.WALL,
	ConstantsData.Terrain.WALL_DECO,
	ConstantsData.Terrain.LOCKED_DOOR,
	ConstantsData.Terrain.CRYSTAL_DOOR,
	ConstantsData.Terrain.SECRET_DOOR,
]


func _make_level() -> Level:
	var level := Level.new()
	level._init_arrays()
	return level


func _make_standard(left: int, top: int, right: int, bottom: int) -> StandardRoom:
	var room := StandardRoom.new()
	room.left = left
	room.top = top
	room.right = right
	room.bottom = bottom
	return room


func _set_room_bounds(room: Room, left: int, top: int, right: int, bottom: int) -> Room:
	room.left = left
	room.top = top
	room.right = right
	room.bottom = bottom
	return room


func _border_cells(room: Room) -> Array[int]:
	var cells: Array[int] = []
	for x: int in range(room.left, room.right + 1):
		cells.append(ConstantsData.xy_to_pos(x, room.top))
		cells.append(ConstantsData.xy_to_pos(x, room.bottom))
	for y: int in range(room.top + 1, room.bottom):
		cells.append(ConstantsData.xy_to_pos(room.left, y))
		cells.append(ConstantsData.xy_to_pos(room.right, y))
	return cells


func run(t: Object) -> void:
	# 1) _gated_border_cells collects gated rooms only.
	var reg_level: Level = _make_level()
	var standard: StandardRoom = _make_standard(5, 5, 9, 9)
	var vault: VaultRoom = _set_room_bounds(VaultRoom.new(), 12, 10, 16, 14) as VaultRoom
	reg_level.rooms = [standard, vault]
	var protected: Dictionary = StandardPainter._gated_border_cells(reg_level)
	t.check(protected.has(ConstantsData.xy_to_pos(12, 10)),
		"gated border set contains the vault's corner wall")
	t.check(protected.has(ConstantsData.xy_to_pos(14, 14)),
		"gated border set contains the vault's bottom wall")
	t.check(not protected.has(ConstantsData.xy_to_pos(7, 5)),
		"standard-room border cells are not carve-protected")
	t.check(not protected.has(ConstantsData.xy_to_pos(14, 12)),
		"vault interior cells are not carve-protected")

	# 2) build_tunnel never carves a protected cell.
	var carve_level: Level = _make_level()
	for i: int in range(Level.LEN):
		carve_level.set_terrain(i, ConstantsData.Terrain.WALL)
	var blocked: int = ConstantsData.xy_to_pos(12, 8)
	Builder.build_tunnel(carve_level,
		ConstantsData.xy_to_pos(9, 8), ConstantsData.xy_to_pos(12, 11),
		{blocked: true})
	t.check(carve_level.terrain_at(blocked) == ConstantsData.Terrain.WALL,
		"protected cell survives tunnel carving")
	t.check(carve_level.terrain_at(ConstantsData.xy_to_pos(9, 8)) == ConstantsData.Terrain.EMPTY,
		"unprotected tunnel endpoint is carved")

	# 3) Full paint pass: diagonal-offset vault whose corner sits on the
	# horizontal-first L path. Both L orders must leave every vault border
	# cell sealed (wall or the locked door). Repeat across seeds to hit
	# both random L orientations.
	for run_seed: int in [11, 22, 33, 44, 55, 66]:
		seed(run_seed)
		var level: Level = _make_level()
		var std_room: StandardRoom = _make_standard(5, 5, 9, 9)
		var gated: VaultRoom = _set_room_bounds(VaultRoom.new(), 12, 10, 16, 14) as VaultRoom
		std_room.neighbors.append(gated)
		gated.neighbors.append(std_room)
		level.rooms = [std_room, gated]
		StandardPainter.paint_level(level)

		var breaches: Array[int] = []
		for cell: int in _border_cells(gated):
			if level.terrain_at(cell) not in SEALED_TERRAINS:
				breaches.append(cell)
		t.check(breaches.is_empty(),
			"seed %d: vault border has no carved breaches (found %s)" % [run_seed, str(breaches)])
		var has_door: bool = false
		for cell: int in _border_cells(gated):
			if level.terrain_at(cell) == ConstantsData.Terrain.LOCKED_DOOR:
				has_door = true
				break
		t.check(has_door, "seed %d: vault still gets its locked door" % run_seed)
