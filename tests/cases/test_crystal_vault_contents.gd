extends RefCounted
## CrystalVaultRoom contents parity against upstream CrystalVaultRoom.java:
## fixed 7x7, iron-LOCKED entrance, two wand/ring/artifact prizes dropped as
## crystal_chest heaps (or one chest + a CrystalMimic on the 1/10 roll) on
## opposite CIRCLE8 neighbours of the centre away from the door, each on a
## PEDESTAL, and a crystal key + iron key queued in level.items_to_spawn.

const PRIZE_CATEGORIES: Array[int] = [
	ConstantsData.ItemCategory.WAND,
	ConstantsData.ItemCategory.RING,
	ConstantsData.ItemCategory.ARTIFACT,
]

func _make_level(depth: int) -> Level:
	var level := Level.new()
	level.depth = depth
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	return level

func _paint_vault(depth: int) -> Dictionary:
	var level: Level = _make_level(depth)
	var room := CrystalVaultRoom.new()
	room.left = 5
	room.top = 5
	room.right = 11
	room.bottom = 11
	var door_pos: int = ConstantsData.xy_to_pos(room.left, 8)
	var neighbor := Room.new()
	room.connected[neighbor] = door_pos
	room.paint(level)
	return {"level": level, "room": room, "door": door_pos}

func run(t: Object) -> void:
	var painted: Dictionary = _paint_vault(12)
	var level: Level = painted["level"]
	var room: CrystalVaultRoom = painted["room"]
	var door_pos: int = painted["door"]

	# --- Fixed 7x7 footprint + single entrance ---
	t.check(room.min_width() == 7 and room.max_width() == 7
		and room.min_height() == 7 and room.max_height() == 7,
		"crystal vault is fixed 7x7 like upstream")
	t.check(room.max_connections() == 1,
		"crystal vault allows a single entrance like upstream SpecialRoom")

	# --- Iron-locked entrance, no crystal door ---
	t.check(level.terrain_at(door_pos) == ConstantsData.Terrain.LOCKED_DOOR,
		"entrance is an iron-locked door (upstream IronKey lock)")

	# --- Keys queued for the wider floor ---
	var key_ids: Array[String] = []
	for pending: Variant in level.items_to_spawn:
		if pending is Item:
			key_ids.append(str(pending.item_id))
	t.check(key_ids.has("crystal_key") and key_ids.has("iron_key")
		and key_ids.size() == 2,
		"a crystal key and an iron key are queued in items_to_spawn")

	# --- Prize placement across many paints (mimic roll is random) ---
	var c: int = room.center()
	for trial: int in range(30):
		var p: Dictionary = _paint_vault(12)
		var lv: Level = p["level"]
		var rm: CrystalVaultRoom = p["room"]
		var dp: int = p["door"]
		var chest_cells: Array[int] = []
		for heap: Dictionary in lv.heaps:
			t.check(str(heap.get("type", "")) == "crystal_chest",
				"every vault heap is a crystal_chest")
			chest_cells.append(int(heap.get("pos", -1)))
			var it: Variant = heap.get("item")
			t.check(it is Item and PRIZE_CATEGORIES.has(it.category),
				"chest prize comes from the wand/ring/artifact table")
		var mimics: Array = []
		for mob: Variant in lv.mobs:
			if mob is CrystalMimic:
				mimics.append(mob)
		t.check(chest_cells.size() + mimics.size() == 2,
			"exactly two prize slots (chests + crystal mimics)")
		var slot_cells: Array[int] = chest_cells.duplicate()
		for m: Variant in mimics:
			t.check(not (m as CrystalMimic).stored_items.is_empty(),
				"a rolled crystal mimic swallows the second prize")
			slot_cells.append(int((m as CrystalMimic).pos))
		var rc: int = rm.center()
		for cell: int in slot_cells:
			t.check(lv.terrain_at(cell) == ConstantsData.Terrain.PEDESTAL,
				"each prize slot sits on a pedestal")
			var dx: int = abs(cell % ConstantsData.WIDTH - rc % ConstantsData.WIDTH)
			var dy: int = abs(cell / ConstantsData.WIDTH - rc / ConstantsData.WIDTH)
			t.check(dx <= 1 and dy <= 1 and cell != rc,
				"each prize slot is a CIRCLE8 neighbour of the centre")
			var ddx: int = abs(cell % ConstantsData.WIDTH - dp % ConstantsData.WIDTH)
			var ddy: int = abs(cell / ConstantsData.WIDTH - dp / ConstantsData.WIDTH)
			t.check(ddx > 1 or ddy > 1,
				"prize slots are never adjacent to the entrance")
		if slot_cells.size() == 2:
			t.check(slot_cells[0] + slot_cells[1] == 2 * rc,
				"the two prize slots sit on opposite sides of the centre")

	# --- Centre stays clear (no pedestal at centre like the old port) ---
	t.check(level.terrain_at(c) == ConstantsData.Terrain.EMPTY,
		"vault centre is open floor, not the old single centre pedestal")
