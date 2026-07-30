extends RefCounted
## Heap fire/frost parity against upstream Heap.burn / Heap.freeze:
## - burn destroys non-unique scrolls (Scroll of Upgrade survives), evaporates
##   dewdrops, cooks mystery meat / frozen carpaccio into chargrilled meat
##   (quantity preserved), and detonates floor bombs (heap removed).
## - freeze shatters non-unique potions where they lie (Potion of Strength
##   survives), converts mystery meat into frozen carpaccio, and snuffs armed
##   fuses (port adaptation: the pending bomb returns to the floor as a heap).
## - container heaps (chests/skeletons/shop stock) are untouched by both.
## - FireBlob / FreezingBlob call the hooks for dense cells each tick.


func _make_level() -> Level:
	var level := Level.new()
	level.depth = 3
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level


func _heap_items_at(level: Level, cell: int) -> Array:
	var found: Array = []
	for heap: Dictionary in level.heaps:
		if int(heap.get("pos", -1)) == cell:
			found.append(heap.get("item"))
	return found


func run(t: Object) -> void:
	_test_burn_scrolls_and_dew(t)
	_test_burn_cooks_meat(t)
	_test_burn_detonates_bomb(t)
	_test_burn_skips_containers(t)
	_test_freeze_shatters_potions(t)
	_test_freeze_converts_meat(t)
	_test_freeze_snuffs_armed_fuse(t)
	_test_blob_wiring(t)


func _test_burn_scrolls_and_dew(t: Object) -> void:
	var level := _make_level()
	var cell: int = ConstantsData.xy_to_pos(10, 10)
	level.drop_item(cell, Scroll.create("identify"))
	level.drop_item(cell, Scroll.create("upgrade"))
	level.drop_item(cell, Generator.create_item("dewdrop"))
	var changed: bool = Heap.burn_at(level, cell)
	t.check(changed, "burn reports a change for scroll + dewdrop heaps")
	var left: Array = _heap_items_at(level, cell)
	t.check(left.size() == 1, "one item survives the fire")
	t.check(
		left.size() == 1 and left[0].item_id == "upgrade",
		"scroll of upgrade survives, plain scroll + dewdrop are destroyed"
	)
	t.check(not Heap.burn_at(level, cell), "second burn over the survivor is a no-op")


func _test_burn_cooks_meat(t: Object) -> void:
	var level := _make_level()
	var cell: int = ConstantsData.xy_to_pos(11, 10)
	var meat: Food = Food.create("mystery_meat")
	meat.quantity = 3
	level.drop_item(cell, meat)
	level.drop_item(cell + 1, Food.create("frozen_carpaccio"))
	t.check(Heap.burn_at(level, cell), "burn converts a mystery meat heap")
	t.check(Heap.burn_at(level, cell + 1), "burn converts a frozen carpaccio heap")
	var cooked: Array = _heap_items_at(level, cell)
	t.check(
		cooked.size() == 1 and cooked[0].item_id == "chargrilled_meat",
		"mystery meat becomes chargrilled meat"
	)
	t.check(
		cooked.size() == 1 and cooked[0].quantity == 3,
		"cooked stack keeps its quantity"
	)
	var carp: Array = _heap_items_at(level, cell + 1)
	t.check(
		carp.size() == 1 and carp[0].item_id == "chargrilled_meat",
		"frozen carpaccio also chargrills"
	)


func _test_burn_detonates_bomb(t: Object) -> void:
	var level := _make_level()
	var cell: int = ConstantsData.xy_to_pos(12, 10)
	level.drop_item(cell, Bomb.create("bomb"))
	t.check(Heap.burn_at(level, cell), "burn detonates a floor bomb")
	t.check(_heap_items_at(level, cell).is_empty(), "the bomb heap is gone after detonating")


func _test_burn_skips_containers(t: Object) -> void:
	var level := _make_level()
	var cell: int = ConstantsData.xy_to_pos(13, 10)
	level.drop_item(cell, Scroll.create("identify"), "chest")
	level.drop_item(cell, Potion.create("healing"), "skeleton")
	t.check(not Heap.burn_at(level, cell), "burn ignores container heaps")
	t.check(not Heap.freeze_at(level, cell), "freeze ignores container heaps")
	t.check(_heap_items_at(level, cell).size() == 2, "container contents are untouched")


func _test_freeze_shatters_potions(t: Object) -> void:
	var level := _make_level()
	var cell: int = ConstantsData.xy_to_pos(14, 10)
	level.drop_item(cell, Potion.create("liquid_flame"))
	level.drop_item(cell, Potion.create("strength"))
	t.check(Heap.freeze_at(level, cell), "freeze reports a change for a potion heap")
	var left: Array = _heap_items_at(level, cell)
	t.check(left.size() == 1, "one potion survives the frost")
	t.check(
		left.size() == 1 and left[0].item_id == "strength",
		"potion of strength survives, other potions shatter"
	)


func _test_freeze_converts_meat(t: Object) -> void:
	var level := _make_level()
	var cell: int = ConstantsData.xy_to_pos(15, 10)
	var meat: Food = Food.create("mystery_meat")
	meat.quantity = 2
	level.drop_item(cell, meat)
	level.drop_item(cell + 1, Food.create("chargrilled_meat"))
	t.check(Heap.freeze_at(level, cell), "freeze converts a mystery meat heap")
	var carp: Array = _heap_items_at(level, cell)
	t.check(
		carp.size() == 1 and carp[0].item_id == "frozen_carpaccio",
		"mystery meat becomes frozen carpaccio"
	)
	t.check(
		carp.size() == 1 and carp[0].quantity == 2,
		"frozen stack keeps its quantity"
	)
	t.check(
		not Heap.freeze_at(level, cell + 1),
		"chargrilled meat is unaffected by frost"
	)


func _test_freeze_snuffs_armed_fuse(t: Object) -> void:
	var level := _make_level()
	var cell: int = ConstantsData.xy_to_pos(16, 10)
	var bomb: Bomb = Bomb.create("bomb")
	level.arm_bomb(cell, bomb, 3)
	t.check(level.pending_bombs.size() == 1, "bomb is armed before the frost")
	t.check(Heap.freeze_at(level, cell), "freeze snuffs the armed fuse")
	t.check(level.pending_bombs.is_empty(), "the armed fuse is gone")
	var left: Array = _heap_items_at(level, cell)
	t.check(
		left.size() == 1 and left[0] == bomb,
		"the defused bomb returns to the floor as a heap"
	)
	t.check(not level.tick_pending_bombs(), "nothing detonates after defusing")


func _test_blob_wiring(t: Object) -> void:
	var level := _make_level()
	var cell: int = ConstantsData.xy_to_pos(20, 20)

	var fire := FireBlob.new()
	fire.level = level
	level.drop_item(cell, Food.create("mystery_meat"))
	fire.seed(cell, 3.0)
	fire._apply_effects()
	var burned: Array = _heap_items_at(level, cell)
	t.check(
		burned.size() == 1 and burned[0].item_id == "chargrilled_meat",
		"fire blob chargrills a heap in a burning cell"
	)

	var frost := FreezingBlob.new()
	frost.level = level
	var cell_2: int = ConstantsData.xy_to_pos(21, 20)
	level.drop_item(cell_2, Food.create("mystery_meat"))
	frost.seed(cell_2, 3.0)
	frost._apply_effects()
	var frozen: Array = _heap_items_at(level, cell_2)
	t.check(
		frozen.size() == 1 and frozen[0].item_id == "frozen_carpaccio",
		"freezing blob converts a heap in a frozen cell"
	)
