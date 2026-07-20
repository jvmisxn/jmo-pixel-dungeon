extends RefCounted
## WandOfCorrosion fidelity: upstream seeds CorrosiveGas at the bolt collision
## cell, and the gas applies Corrosion on its own blob tick.

class _FakeLevel:
	extends RefCounted
	var blobs: Array[Dictionary] = []
	var target_char: Char = null
	var pressed_cell: int = -1

	func add_blob(blob: Variant, cell: int, amount: float = 1.0) -> void:
		if blob == null:
			return
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

	func find_char_at(cell: int) -> Variant:
		if target_char != null and target_char.pos == cell:
			return target_char
		return null

	func press_cell(cell: int) -> void:
		pressed_cell = cell

func run(t: Object) -> void:
	_test_corrosive_gas_applies_corrosion(t)
	_test_corrosive_gas_strength_merges_and_serializes(t)
	_test_wand_seeds_corrosive_gas_instead_of_poison(t)

func _center() -> int:
	return ConstantsData.xy_to_pos(16, 16)

func _make_char(cell: int) -> Char:
	var c: Char = Char.new()
	c.name = "CorrosionTarget"
	c.hp = 100
	c.hp_max = 100
	c.is_alive = true
	c.pos = cell
	return c

func _make_hero(level: Object) -> Char:
	var hero: Char = Char.new()
	hero.name = "CorrosionCaster"
	hero.hp = 100
	hero.hp_max = 100
	hero.is_alive = true
	hero.pos = _center() - 1
	hero.level = level
	return hero

func _test_corrosive_gas_applies_corrosion(t: Object) -> void:
	var cell: int = _center()
	var victim: Char = _make_char(cell)
	var level := _FakeLevel.new()
	level.target_char = victim
	var gas: CorrosiveGas = CorrosiveGas.new()
	gas.level = level
	gas.set_strength(4, "WandOfCorrosion")
	gas.seed(cell, 8.0)

	gas.tick()

	var corrosion: Corrosion = victim.get_buff("Corrosion") as Corrosion
	t.check(corrosion != null, "corrosive gas applies Corrosion")
	t.check(corrosion != null and int(corrosion.damage) == 4,
			"corrosive gas applies its strength as Corrosion damage")
	t.check(corrosion != null and is_equal_approx(corrosion.left, 2.0),
			"corrosive gas tops Corrosion duration to two turns")
	t.check(not victim.has_buff("Poison"),
			"corrosive gas does not use the weaker Poison debuff")

	victim.free()

func _test_corrosive_gas_strength_merges_and_serializes(t: Object) -> void:
	var weaker: CorrosiveGas = CorrosiveGas.new()
	weaker.set_strength(3, "weak")
	var stronger: CorrosiveGas = CorrosiveGas.new()
	stronger.set_strength(7, "strong")

	weaker.merge_from_blob(stronger)
	t.check(weaker.strength == 7 and weaker.source_id == "strong",
			"corrosive gas keeps the strongest merged cloud source")
	weaker.merge_from_blob(CorrosiveGas.new().set_strength(2, "weak_again"))
	t.check(weaker.strength == 7 and weaker.source_id == "strong",
			"weaker corrosive gas cannot downgrade the cloud")

	weaker.seed(_center(), 5.0)
	var restored: CorrosiveGas = CorrosiveGas.new()
	restored.deserialize(weaker.serialize())
	t.check(restored.strength == 7 and restored.source_id == "strong",
			"corrosive gas strength/source survive serialization")

func _test_wand_seeds_corrosive_gas_instead_of_poison(t: Object) -> void:
	var cell: int = _center()
	var target: Char = _make_char(cell)
	var level := _FakeLevel.new()
	level.target_char = target
	var hero: Char = _make_hero(level)
	var wand: Wand.WandOfCorrosion = Wand.WandOfCorrosion.new()
	wand.level = 2

	wand.on_zap(hero, [cell] as Array[int])

	t.check(level.blobs.size() == 1, "wand corrosion seeds one blob")
	var gas: CorrosiveGas = level.blobs[0]["blob"] as CorrosiveGas
	t.check(gas != null, "wand corrosion seeds CorrosiveGas")
	t.check(gas != null and is_equal_approx(gas.get_density(cell), 70.0),
			"wand corrosion uses SPD seed volume 50 + 10 per level")
	t.check(gas != null and gas.strength == 4,
			"wand corrosion uses SPD strength 2 + level")
	t.check(not target.has_buff("Poison") and not target.has_buff("Corrosion"),
			"wand impact does not apply an immediate debuff before the blob tick")

	if gas != null:
		gas.tick()
	t.check(target.has_buff("Corrosion"), "seeded corrosive gas applies Corrosion on tick")
	t.check(not target.has_buff("Poison"), "wand corrosion never applies Poison")

	target.free()
	hero.free()
