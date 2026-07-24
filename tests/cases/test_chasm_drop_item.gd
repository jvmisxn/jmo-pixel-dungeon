extends RefCounted
## Chasm drop routing parity against Shattered Pixel Dungeon's `Level.drop`:
## an item dropped/thrown onto a CHASM cell is not placed as a heap on that
## floor. It routes through `GameManager.drop_to_chasm` (upstream
## `Dungeon.dropToChasm`) and lands on the next depth down; past the last
## depth it is lost. Non-chasm cells keep normal heap placement.

func _make_level(depth: int) -> Level:
	var level := Level.new()
	level.depth = depth
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func run(t: Object) -> void:
	var original_depth: int = GameManager.depth
	var original_level: Variant = GameManager.current_level
	var original_pending: Dictionary = GameManager.pending_dropped_items.duplicate(true)
	GameManager.pending_dropped_items.clear()

	GameManager.depth = 4
	var level: Level = _make_level(4)
	GameManager.current_level = level

	var chasm_pos: int = ConstantsData.xy_to_pos(10, 10)
	var floor_pos: int = ConstantsData.xy_to_pos(12, 12)
	level.map[chasm_pos] = ConstantsData.Terrain.CHASM

	# --- Item dropped onto a chasm cell falls through, no heap remains ---
	var falling: Item = Generator.create_item("dewdrop")
	t.check(falling != null, "test item can be created")
	var result: Dictionary = level.drop_item(chasm_pos, falling)
	t.check(bool(result.get("dropped_to_chasm", false)),
		"drop_item reports the item as dropped to the chasm")
	t.check(level.heaps_at(chasm_pos).is_empty(),
		"no heap is placed on the chasm cell")
	t.check(GameManager.pending_dropped_items.has(5),
		"chasm-dropped item is queued for the next depth down")

	# --- Non-chasm cells keep normal heap placement ---
	var grounded: Item = Generator.create_item("dewdrop")
	level.drop_item(floor_pos, grounded)
	t.check(not level.heaps_at(floor_pos).is_empty(),
		"a normal floor cell still receives a heap")

	# --- Past the last depth the item is lost, still no heap ---
	GameManager.pending_dropped_items.clear()
	GameManager.depth = ConstantsData.MAX_DEPTH
	var last: Level = _make_level(ConstantsData.MAX_DEPTH)
	last.map[chasm_pos] = ConstantsData.Terrain.CHASM
	GameManager.current_level = last
	last.drop_item(chasm_pos, Generator.create_item("dewdrop"))
	t.check(last.heaps_at(chasm_pos).is_empty(),
		"no heap is placed on a last-depth chasm cell")
	t.check(GameManager.pending_dropped_items.is_empty(),
		"an item dropped past the last depth is lost, not queued")

	GameManager.depth = original_depth
	GameManager.current_level = original_level
	GameManager.pending_dropped_items = original_pending
