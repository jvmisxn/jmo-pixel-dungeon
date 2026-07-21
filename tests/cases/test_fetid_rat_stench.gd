extends RefCounted
## Fetid Rat source-fidelity coverage.

class StubLevel:
	extends RefCounted
	var blobs: Array[Dictionary] = []
	var _char: Char = null
	var _char_cell: int = -1
	func add_blob(blob: Variant, cell: int, amount: float = 1.0) -> void:
		blob.level = self
		blob.seed(cell, amount)
		blobs.append({"blob": blob, "pos": cell})
	func is_passable(_pos: int) -> bool:
		return true
	func find_char_at(cell: int) -> Variant:
		return _char if cell == _char_cell else null

func run(t: Object) -> void:
	_test_fetid_rat_stats(t)
	_test_defense_proc_seeds_stench(t)
	_test_stench_gas_paralyzes_on_tick(t)
	_test_fetid_rat_attack_applies_ooze(t)

func _test_fetid_rat_stats(t: Object) -> void:
	var rat := FetidRat.new()
	t.check(rat.hp_max == 20, "Fetid Rat matches upstream HP 20")
	t.check(rat.attack_skill == 12, "Fetid Rat matches upstream attack skill 12")
	t.check(rat.defense_skill == 5, "Fetid Rat matches upstream defense skill 5")
	t.check(rat.damage_roll_min == 1 and rat.damage_roll_max == 4,
			"Fetid Rat keeps the upstream rat damage roll")
	t.check(rat.armor_value == 1,
			"Fetid Rat keeps the base rat defense-roll bonus surface")
	t.check(rat.xp_value == 4, "Fetid Rat matches upstream EXP 4")
	t.check(rat.is_immune("stench_gas"), "Fetid Rat is immune to its own StenchGas")

func _test_defense_proc_seeds_stench(t: Object) -> void:
	var rat := FetidRat.new()
	var level := StubLevel.new()
	rat.level = level
	rat.pos = ConstantsData.xy_to_pos(10, 10)

	var returned: int = rat.defense_proc(Char.new(), 7)
	t.check(returned == 7, "Fetid Rat defense proc preserves incoming damage")
	t.check(level.blobs.size() == 1, "Fetid Rat defense proc seeds one blob")
	var gas: StenchGas = level.blobs[0]["blob"] as StenchGas
	t.check(gas != null, "Fetid Rat defense proc seeds StenchGas")
	t.check(gas != null and is_equal_approx(gas.get_density(rat.pos), 20.0),
			"Fetid Rat stench seed uses upstream volume 20")

func _test_stench_gas_paralyzes_on_tick(t: Object) -> void:
	var victim := Char.new()
	var cell: int = ConstantsData.xy_to_pos(12, 12)
	victim.pos = cell
	var level := StubLevel.new()
	level._char = victim
	level._char_cell = cell
	var gas := StenchGas.new()
	gas.level = level
	gas.seed(cell, 20.0)

	gas.tick()
	var para: Paralysis = victim.get_buff("Paralysis") as Paralysis
	t.check(para != null, "StenchGas paralyzes a character standing in it")
	t.check(para != null and is_equal_approx(para.time_left, Paralysis.DURATION / 5.0),
			"StenchGas applies SPD's one-fifth Paralysis duration")

func _test_fetid_rat_attack_applies_ooze(t: Object) -> void:
	var rat := FetidRat.new()
	var victim := Char.new()
	seed(4)
	for _i: int in range(60):
		rat.attack_proc(victim, 3)
		if victim.has_buff("Ooze"):
			break
	var ooze: Ooze = victim.get_buff("Ooze") as Ooze
	t.check(ooze != null, "Fetid Rat attack proc can apply Ooze")
	t.check(ooze != null and is_equal_approx(ooze.left, Ooze.DURATION),
			"Fetid Rat Ooze starts at the upstream Ooze duration")
