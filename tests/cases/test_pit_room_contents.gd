extends RefCounted
## PitRoom contents parity against Shattered Pixel Dungeon's PitRoom.java:
## the room is sealed behind a CRYSTAL door, an empty well sits against the
## wall opposite the entrance, and a skeleton heap at the centre holds the
## main loot, 1-2 minor prizes, and the crystal key that opens the door.
## The room also bans trap/grass/water generation inside itself.

func _make_level(depth: int) -> Level:
	var level := Level.new()
	level.depth = depth
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	return level

func run(t: Object) -> void:
	var level: Level = _make_level(6)

	var room := PitRoom.new()
	room.left = 5
	room.top = 5
	room.right = 11
	room.bottom = 11

	# Entrance on the left wall, mid-height
	var door_pos: int = ConstantsData.xy_to_pos(room.left, 8)
	var neighbor := Room.new()
	room.connected[neighbor] = door_pos

	room.paint(level)

	# --- Crystal door entrance ---
	t.check(level.terrain_at(door_pos) == ConstantsData.Terrain.CRYSTAL_DOOR,
		"pit room entrance is painted as a crystal door")
	t.check(room.max_connections() == 1,
		"pit room allows a single entrance like upstream SpecialRoom")

	# --- Empty well opposite the entrance ---
	var wells: Array[int] = []
	for cell: int in room.interior_cells():
		if level.terrain_at(cell) == ConstantsData.Terrain.EMPTY_WELL:
			wells.append(cell)
	t.check(wells.size() == 1, "exactly one empty well is painted")
	if wells.size() == 1:
		var wx: int = ConstantsData.pos_to_x(wells[0])
		var wy: int = ConstantsData.pos_to_y(wells[0])
		t.check(wx == room.right - 1,
			"well sits against the wall opposite the left-side entrance")
		t.check(wy == room.top + 1 or wy == room.bottom - 1,
			"well sits next to a corner like upstream")

	# --- Centre skeleton heap: main loot + 1-2 prizes + crystal key ---
	var remains: Array[Dictionary] = level.heaps_at(room.center())
	t.check(remains.size() >= 3 and remains.size() <= 4,
		"centre holds main loot, 1-2 prizes, and the key (3-4 drops)")
	var skeleton_count: int = 0
	var key_count: int = 0
	for heap: Dictionary in remains:
		if str(heap.get("type", "")) == "skeleton":
			skeleton_count += 1
		var item: Variant = heap.get("item")
		if item is Key and (item as Key).item_id == "crystal_key":
			key_count += 1
			t.check((item as Key).depth == level.depth,
				"crystal key is bound to the pit room's depth")
	t.check(skeleton_count == 1, "main loot is placed as a skeleton heap")
	t.check(key_count == 1, "exactly one crystal key is dropped at the centre")

	# --- Generation bans inside the room ---
	var inner: int = room.center()
	t.check(not room.can_place_trap(inner), "pit room forbids trap generation")
	t.check(not room.can_place_grass(inner), "pit room forbids grass generation")
	t.check(not room.can_place_water(inner), "pit room forbids water patches")
	var base := Room.new()
	t.check(base.can_place_trap(inner) and base.can_place_grass(inner) \
		and base.can_place_water(inner),
		"base rooms still allow trap/grass/water generation")

	# --- No chasm ring: interior is walkable so the hero can reach the door ---
	var chasms: int = 0
	for cell: int in room.interior_cells():
		if level.terrain_at(cell) == ConstantsData.Terrain.CHASM:
			chasms += 1
	t.check(chasms == 0, "upstream pit room floor has no chasm cells")
