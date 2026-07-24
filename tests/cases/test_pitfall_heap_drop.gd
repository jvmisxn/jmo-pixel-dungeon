extends RefCounted
## Pitfall fallen-item parity against Shattered Pixel Dungeon's
## `PitfallTrap.DelayedPit` + `Dungeon.dropToChasm`: item heaps inside the
## collapsing 3x3 footprint are not destroyed with the floor. They queue on
## `GameManager.pending_dropped_items` for the next depth down, and the
## level-arrival path (upstream switchLevel's droppedItems delivery) lands them
## at a random passable cell on that floor. Items dropped past the last depth
## are lost, as upstream.

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
	var original_hero: Node = GameManager.hero
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_level: Variant = GameManager.current_level
	var original_pending: Dictionary = GameManager.pending_dropped_items.duplicate(true)
	GameManager.pending_dropped_items.clear()

	var trap_pos: int = ConstantsData.xy_to_pos(10, 10)

	# --- Collapse routes footprint heaps to the next depth ---
	GameManager.depth = 6
	var level: Level = _make_level(6)
	GameManager.current_level = level

	var hero := Hero.new()
	hero.pos = trap_pos
	hero.level = level
	GameManager.hero = hero
	GameManager.heroes = [hero]

	var inside_item: Item = Generator.create_item("dewdrop")
	t.check(inside_item != null, "test item can be created")
	level.drop_item(trap_pos + 1, inside_item)
	var outside_item: Item = Generator.create_item("dewdrop")
	level.drop_item(trap_pos + 5 * ConstantsData.WIDTH, outside_item)

	var pit := DelayedPit.new()
	pit.pit_depth = 6
	pit.positions = Blob.blast_cells(level, trap_pos, 1)
	hero.add_buff(pit)
	hero.process_buffs(1.0)

	t.check(level.heaps_at(trap_pos + 1).is_empty(),
		"heap inside the collapsing footprint is removed from the level")
	t.check(not level.heaps_at(trap_pos + 5 * ConstantsData.WIDTH).is_empty(),
		"heap outside the footprint survives the collapse")
	t.check(GameManager.pending_dropped_items.has(7),
		"footprint heap item is queued for the next depth down")

	# --- Arrival delivery lands the queued item on the lower floor ---
	GameManager.depth = 7
	var below: Level = _make_level(7)
	GameManager.current_level = below
	var loading := LoadingScene.new()
	loading._deliver_fallen_items(below)
	loading.free()

	var landed: bool = false
	for heap: Dictionary in below.get_heaps():
		var item: Variant = heap.get("item")
		if item != null and item.get("item_id") == "dewdrop":
			landed = true
	t.check(landed, "queued fallen item lands as a heap on the next floor")
	t.check(not GameManager.pending_dropped_items.has(7),
		"pending fallen items for a depth are consumed on delivery")

	# --- Items dropped past the last depth are lost ---
	GameManager.depth = ConstantsData.MAX_DEPTH
	GameManager.drop_to_chasm(Generator.create_item("dewdrop"))
	t.check(GameManager.pending_dropped_items.is_empty(),
		"an item dropped past the last depth is lost, not queued")

	hero.free()
	GameManager.depth = original_depth
	GameManager.hero = original_hero
	GameManager.heroes = original_heroes
	GameManager.current_level = original_level
	GameManager.pending_dropped_items = original_pending
