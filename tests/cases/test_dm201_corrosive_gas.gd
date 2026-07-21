extends RefCounted
## DM-201 parity: upstream zaps a CorrosiveGas cloud (strength 8) at the enemy,
## rather than directly applying Poison/Ooze to adjacent characters.

class FakeLevel:
	extends RefCounted
	var blobs: Array[Dictionary] = []
	var blocked: Dictionary = {}

	func add_blob(blob: Variant, cell: int, amount: float = 1.0) -> void:
		var new_id: String = str(blob.get("blob_id")) if blob.get("blob_id") != null else ""
		for entry: Dictionary in blobs:
			var existing: Variant = entry.get("blob")
			if existing != null and str(existing.get("blob_id")) == new_id:
				if existing.has_method("merge_from_blob"):
					existing.merge_from_blob(blob)
				existing.seed(cell, amount)
				return
		blob.level = self
		blob.seed(cell, amount)
		blobs.append({"blob": blob, "pos": cell})

	func is_passable(cell: int) -> bool:
		return not blocked.has(cell)

	func find_char_at(_cell: int) -> Variant:
		return null

func run(t: Object) -> void:
	_test_dm201_vent_seeds_corrosive_gas(t)
	_test_dm201_gas_uses_bounded_open_neighbors(t)

func _center() -> int:
	return ConstantsData.xy_to_pos(16, 16)

func _make_dm(level: FakeLevel, cell: int, target_cell: int) -> DM201:
	var dm: DM201 = DM201.new()
	dm.level = level
	dm.pos = cell
	var hero: Char = Char.new()
	hero.name = "Target"
	hero.pos = target_cell
	hero.hp = 100
	hero.hp_max = 100
	hero.is_alive = true
	dm.target = hero
	return dm

func _test_dm201_vent_seeds_corrosive_gas(t: Object) -> void:
	var level := FakeLevel.new()
	var target_cell: int = _center() + 1
	var dm: DM201 = _make_dm(level, _center(), target_cell)

	dm._vent_corrosive_gas()

	t.check(level.blobs.size() == 1, "DM-201 vent seeds one merged CorrosiveGas cloud")
	var gas: CorrosiveGas = level.blobs[0]["blob"] as CorrosiveGas
	t.check(gas != null, "DM-201 vent uses the real CorrosiveGas blob")
	t.check(gas != null and gas.strength == 8 and gas.source_id == "DM201",
			"DM-201 gas uses upstream strength 8 and source tag")
	t.check(gas != null and is_equal_approx(gas.get_density(target_cell), 15.0),
			"DM-201 gas seeds 15 volume at the enemy cell")
	t.check(gas != null and is_equal_approx(gas.get_density(target_cell + ConstantsData.WIDTH), 5.0),
			"DM-201 gas seeds 5 volume into open neighboring cells")
	t.check(not dm.target.has_buff("Poison") and not dm.target.has_buff("Ooze"),
			"DM-201 vent does not apply direct Poison/Ooze stand-ins")

	dm.target.free()
	dm.free()

func _test_dm201_gas_uses_bounded_open_neighbors(t: Object) -> void:
	var level := FakeLevel.new()
	var edge_cell: int = ConstantsData.xy_to_pos(0, 1)
	var blocked_cell: int = ConstantsData.xy_to_pos(1, 1)
	level.blocked[blocked_cell] = true
	var dm: DM201 = _make_dm(level, ConstantsData.xy_to_pos(1, 1), edge_cell)

	dm._vent_corrosive_gas()

	var gas: CorrosiveGas = level.blobs[0]["blob"] as CorrosiveGas
	var wrapped: int = edge_cell - 1
	t.check(gas != null and is_equal_approx(gas.get_density(edge_cell), 15.0),
			"DM-201 edge vent seeds the target cell")
	t.check(gas != null and gas.get_density(wrapped) == 0.0,
			"DM-201 gas footprint does not wrap across map rows")
	t.check(gas != null and gas.get_density(blocked_cell) == 0.0,
			"DM-201 gas skips blocked neighboring cells")

	dm.target.free()
	dm.free()
