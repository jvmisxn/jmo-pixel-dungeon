extends RefCounted
## Blob/gas simulation coverage: spread lifecycle, row-wrap guard, decay/prune,
## character effects, serialize round-trip, Level.add_blob merge + tick_blobs,
## and shared-timeline advance_blobs cadence.

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
	_test_volume_does_not_explode(t)
	_test_decay_reduces_volume(t)
	_test_spread_shape_is_sane(t)
	_test_toxic_gas_poisons(t)
	_test_paralytic_gas_paralyzes(t)
	_test_freezing_blob_freezes(t)
	_test_freezing_blob_freezes_water(t)
	_test_serialize_round_trip(t)
	_test_level_merge_and_tick(t)
	_test_advance_blobs_uses_game_time(t)
	_test_advance_blobs_reports_final_decay(t)
	_test_blob_time_serializes(t)

## Total blob volume = sum of density across every currently-active cell.
## Pruned cells are zeroed and dropped from active_cells, so this equals the
## whole-field volume.
func _total_volume(blob: Blob) -> float:
	var total: float = 0.0
	for cell: int in blob.active_cells:
		total += blob.get_density(cell)
	return total

func _test_spread(t: Object) -> void:
	var blob: Blob = Blob.new()
	blob.spread_rate = 0.5
	blob.decay_rate = 0.0
	blob.level = StubLevel.new()
	var center: int = _center()
	blob.seed(center, 4.0)
	t.check(blob.active_cells.size() == 1, "seed marks a single active cell")

	blob.tick()
	# Volume-conserving diffusion: the seed averages across itself + 4 open
	# neighbors -> 4.0/5 = 0.8 in each of the 5 cells (> min_density), and the
	# total (5 * 0.8 = 4.0) matches what was seeded rather than growing.
	var north: int = center - ConstantsData.WIDTH
	var east: int = center + 1
	t.check(blob.get_density(north) > blob.min_density, "blob spreads north")
	t.check(blob.get_density(east) > blob.min_density, "blob spreads east")
	t.check(center in blob.active_cells, "origin stays active after spread")
	t.check(blob.active_cells.size() == 5, "spread adds four cardinal neighbors")
	t.check(is_equal_approx(_total_volume(blob), 4.0),
			"diffusion conserves the seeded volume on the first step")

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

## The whole point of the SPD-style diffusion port: spreading must never mint
## new volume. With decay off, total volume must stay at (or just below, from
## sub-threshold tail cells pruning) the seeded amount across many steps -- the
## old copy-outward model grew the total every frontier step.
func _test_volume_does_not_explode(t: Object) -> void:
	var blob: Blob = Blob.new()
	blob.spread_rate = 0.5
	blob.decay_rate = 0.0  # isolate spread; only pruning can remove volume
	blob.level = StubLevel.new()
	var seeded: float = 10.0
	blob.seed(_center(), seeded)
	var peak: float = _total_volume(blob)
	for _i: int in range(12):
		blob.tick()
		var vol: float = _total_volume(blob)
		peak = maxf(peak, vol)
		t.check(vol <= seeded + 0.001,
				"spread never grows total volume beyond the seeded amount")
	t.check(peak <= seeded + 0.001, "peak volume across all steps stays bounded")
	t.check(_total_volume(blob) > 0.0, "blob is still present after diffusing")

## Decay must monotonically shrink total volume for a spreading blob.
func _test_decay_reduces_volume(t: Object) -> void:
	var blob: Blob = Blob.new()
	blob.spread_rate = 0.5
	blob.decay_rate = 0.15
	blob.level = StubLevel.new()
	blob.seed(_center(), 40.0)  # large seed so it never empties within the loop
	var prev: float = _total_volume(blob)
	for _i: int in range(5):
		blob.tick()
		if blob.active_cells.is_empty():
			break
		var vol: float = _total_volume(blob)
		t.check(vol < prev, "each decaying step reduces total volume")
		prev = vol

## Diffusion produces a sane, symmetric, outward-decreasing plume rather than a
## lopsided or edge-biased shape.
func _test_spread_shape_is_sane(t: Object) -> void:
	var blob: Blob = Blob.new()
	blob.spread_rate = 0.5
	blob.decay_rate = 0.0
	blob.level = StubLevel.new()
	var center: int = _center()
	blob.seed(center, 16.0)
	blob.tick()
	blob.tick()
	var n: float = blob.get_density(center - ConstantsData.WIDTH)
	var s: float = blob.get_density(center + ConstantsData.WIDTH)
	var e: float = blob.get_density(center + 1)
	var w: float = blob.get_density(center - 1)
	t.check(is_equal_approx(n, s) and is_equal_approx(e, w) and is_equal_approx(n, e),
			"diffusion stays radially symmetric on an open field")
	t.check(blob.get_density(center) >= n, "center density is >= its neighbors")
	var far: float = blob.get_density(center - 2 * ConstantsData.WIDTH)
	t.check(n >= far, "density decreases monotonically outward from the center")

func _test_paralytic_gas_paralyzes(t: Object) -> void:
	var victim: Char = Char.new()
	var cell: int = _center()
	victim.pos = cell
	var stub: StubLevel = StubLevel.new()
	stub._char = victim
	stub._char_cell = cell
	var gas: ParalyticGas = ParalyticGas.new()
	gas.level = stub
	gas.seed(cell, 5.0)
	gas.tick()
	t.check(victim.has_buff("Paralysis"), "paralytic gas paralyzes a character standing in it")
	victim.free()

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

func _test_advance_blobs_uses_game_time(t: Object) -> void:
	var level: Level = Level.new()
	var center: int = _center()
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			level.set_terrain(ConstantsData.xy_to_pos(16 + dx, 16 + dy),
					ConstantsData.Terrain.EMPTY)

	level.add_blob(FireBlob.new(), center, 5.0)
	var fire: Variant = level.blobs[0].get("blob")
	var before: float = fire.get_density(center)

	t.check(not level.advance_blobs(TurnManagerNode.TICK * 0.5),
			"advance_blobs waits for a full game-time tick")
	t.check(is_equal_approx(fire.get_density(center), before),
			"partial game-time ticks do not advance blob density")

	t.check(level.advance_blobs(TurnManagerNode.TICK),
			"advance_blobs ticks once at one full game-time tick")
	t.check(fire.get_density(center) < before,
			"full game-time tick advances blob decay")

	var after_one: float = fire.get_density(center)
	level.advance_blobs(TurnManagerNode.TICK * 3.0)
	t.check(fire.get_density(center) < after_one,
			"advance_blobs catches up multiple elapsed game-time ticks")

func _test_advance_blobs_reports_final_decay(t: Object) -> void:
	var level: Level = Level.new()
	var center: int = _center()
	level.set_terrain(center, ConstantsData.Terrain.EMPTY)
	var fire := FireBlob.new()
	fire.spread_rate = 0.0
	fire.decay_rate = 1.0
	level.add_blob(fire, center, 0.2)

	t.check(level.advance_blobs(TurnManagerNode.TICK),
			"advance_blobs reports a visual change when the final blob decays")
	t.check(level.blobs.is_empty(), "advance_blobs drops the fully decayed blob")

func _test_blob_time_serializes(t: Object) -> void:
	var level: Level = Level.new()
	var center: int = _center()
	level.set_terrain(center, ConstantsData.Terrain.EMPTY)
	var fire := FireBlob.new()
	fire.spread_rate = 0.0
	level.add_blob(fire, center, 5.0)
	level.advance_blobs(TurnManagerNode.TICK * 2.0)

	var restored := Level.new()
	restored.deserialize(level.serialize())
	t.check(is_equal_approx(restored.serialize().get("blob_time", -1.0), TurnManagerNode.TICK * 2.0),
			"blob timeline cursor survives level serialization")
