extends RefCounted
## Blob/gas simulation coverage: spread lifecycle, row-wrap guard, decay/prune,
## character effects, serialize round-trip, and Level.add_blob merge + tick_blobs.

## Minimal Level stand-in: every cell passable, optionally one char at a cell.
class StubLevel:
	extends RefCounted
	var _char: Char = null
	var _char_cell: int = -1
	func is_passable(_pos: int) -> bool:
		return true
	func find_char_at(cell: int) -> Variant:
		return _char if cell == _char_cell else null

func _center() -> int:
	return ConstantsData.xy_to_pos(16, 16)

func run(t: Object) -> void:
	_test_spread(t)
	_test_no_row_wrap(t)
	_test_decay_and_prune(t)
	_test_toxic_gas_poisons(t)
	_test_freezing_blob_freezes(t)
	_test_freezing_blob_freezes_water(t)
	_test_serialize_round_trip(t)
	_test_level_merge_and_tick(t)

func _test_spread(t: Object) -> void:
	var blob: Blob = Blob.new()
	blob.spread_rate = 0.5
	blob.decay_rate = 0.0
	blob.level = StubLevel.new()
	var center: int = _center()
	blob.seed(center, 4.0)
	t.check(blob.active_cells.size() == 1, "seed marks a single active cell")

	blob.tick()
	# 4.0 * 0.5 * 0.25 = 0.5 pushed into each cardinal neighbor (> min_density).
	var north: int = center - ConstantsData.WIDTH
	var east: int = center + 1
	t.check(blob.get_density(north) > blob.min_density, "blob spreads north")
	t.check(blob.get_density(east) > blob.min_density, "blob spreads east")
	t.check(center in blob.active_cells, "origin stays active after spread")
	t.check(blob.active_cells.size() == 5, "spread adds four cardinal neighbors")

func _test_no_row_wrap(t: Object) -> void:
	var blob: Blob = Blob.new()
	blob.spread_rate = 0.9
	blob.decay_rate = 0.0
	blob.level = StubLevel.new()
	# Column 0, row 1: a raw -1 offset would wrap to the last column of row 0.
	var edge: int = ConstantsData.xy_to_pos(0, 1)
	blob.seed(edge, 8.0)
	blob.tick()
	var wrapped: int = edge - 1  # row 0, column WIDTH-1
	t.check(blob.get_density(wrapped) == 0.0, "blob does not wrap across a row edge")

func _test_decay_and_prune(t: Object) -> void:
	var blob: Blob = Blob.new()
	blob.spread_rate = 0.0  # isolate decay
	blob.decay_rate = 0.1
	blob.level = StubLevel.new()
	var center: int = _center()
	blob.seed(center, 0.35)
	# 0.35 -> 0.25 -> 0.15 -> 0.05 (<= min_density 0.1) => pruned on 3rd tick.
	blob.tick()
	t.check(blob.active_cells.size() == 1, "blob survives while above min density")
	blob.tick()
	blob.tick()
	t.check(blob.active_cells.is_empty(), "blob burns out once density decays below min")
	t.check(blob.get_density(center) == 0.0, "pruned cell density is zeroed")

func _test_toxic_gas_poisons(t: Object) -> void:
	var victim: Char = Char.new()
	var cell: int = _center()
	victim.pos = cell
	var stub: StubLevel = StubLevel.new()
	stub._char = victim
	stub._char_cell = cell
	var gas: ToxicGas = ToxicGas.new()
	gas.level = stub
	gas.seed(cell, 5.0)
	gas.tick()
	t.check(victim.has_buff("Poison"), "toxic gas poisons a character standing in it")
	victim.free()

func _test_freezing_blob_freezes(t: Object) -> void:
	var victim: Char = Char.new()
	var cell: int = _center()
	victim.pos = cell
	var stub: StubLevel = StubLevel.new()
	stub._char = victim
	stub._char_cell = cell
	var script: GDScript = load("res://src/actors/blobs/freezing_blob.gd") as GDScript
	var frost: Blob = script.new() as Blob
	frost.level = stub
	frost.seed(cell, 5.0)
	frost.tick()
	t.check(victim.has_buff("Frozen"), "freezing blob freezes a character standing in it")
	victim.free()

func _test_freezing_blob_freezes_water(t: Object) -> void:
	var level: Level = Level.new()
	var cell: int = _center()
	level.set_terrain(cell, ConstantsData.Terrain.WATER)
	var script: GDScript = load("res://src/actors/blobs/freezing_blob.gd") as GDScript
	var frost: Blob = script.new() as Blob
	frost.level = level
	frost.seed(cell, 5.0)
	frost.tick()
	t.check(level.get_terrain(cell) == ConstantsData.Terrain.EMPTY,
			"freezing blob freezes water terrain")

func _test_serialize_round_trip(t: Object) -> void:
	var gas: ToxicGas = ToxicGas.new()
	gas.level = StubLevel.new()
	var center: int = _center()
	gas.seed(center, 3.0)
	gas.tick()  # spread so there are several active cells
	var data: Dictionary = gas.serialize()

	var restored: ToxicGas = ToxicGas.new()
	restored.deserialize(data)
	t.check(restored.blob_id == "toxic_gas", "deserialize restores blob_id")
	t.check(restored.active_cells.size() == gas.active_cells.size(),
			"deserialize restores active cell count")
	t.check(is_equal_approx(restored.get_density(center), gas.get_density(center)),
			"deserialize restores per-cell density")

func _test_level_merge_and_tick(t: Object) -> void:
	var level: Level = Level.new()
	var center: int = _center()
	# Carve a passable 5x5 pocket so blobs have somewhere to spread.
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			level.set_terrain(ConstantsData.xy_to_pos(16 + dx, 16 + dy),
					ConstantsData.Terrain.EMPTY)

	level.add_blob(FireBlob.new(), center, 5.0)
	level.add_blob(FireBlob.new(), center + 1, 5.0)  # same type -> should merge
	t.check(level.blobs.size() == 1, "same-type blobs merge into one entry")
	var fire: Variant = level.blobs[0].get("blob")
	t.check(fire.active_cells.size() == 2, "merged blob seeds both requested cells")

	var still_active: bool = level.tick_blobs()
	t.check(still_active, "tick_blobs reports the fire is still active")
	t.check(level.blobs.size() == 1, "active blob is retained after a tick")

	# A different blob type stays a separate entry.
	level.add_blob(ToxicGas.new(), center, 5.0)
	t.check(level.blobs.size() == 2, "different blob types are tracked separately")

	# Burn everything down: enough ticks that both the fire (decay 0.15) and the
	# slower toxic gas (decay 0.08, seeded at 5.0) fully decay and are dropped.
	for _i: int in range(200):
		level.tick_blobs()
	t.check(level.blobs.is_empty(), "fully decayed blobs are dropped from the level")
