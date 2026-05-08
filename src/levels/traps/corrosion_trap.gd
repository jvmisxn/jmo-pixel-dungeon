class_name CorrosionTrap
extends Trap
## Creates a corrosive gas cloud that deals damage over time to anyone in range.

func _init() -> void:
	trap_name = "corrosion trap"
	color = Color(0.6, 0.1, 0.6)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("Corrosive gas billows from the trap!")

	# Apply ooze (corrosive damage over time) to the triggerer
	if triggerer != null and triggerer.has_method("add_buff"):
		var ooze: Ooze = Ooze.new()
		triggerer.add_buff(ooze)

	# Spread corrosion to adjacent cells — damage any mob standing there
	var affected_cells: Array[int] = [pos]
	for dir: int in ConstantsData.DIRS_8:
		var adj: int = pos + dir
		if adj >= 0 and adj < Level.LEN and level.is_passable(adj):
			affected_cells.append(adj)

	for cell: int in affected_cells:
		if cell == pos:
			continue
		var mob: Variant = level.mob_at(cell)
		if mob != null and mob.has_method("add_buff"):
			var ooze2: Ooze = Ooze.new()
			mob.add_buff(ooze2)

	# Deal initial corrosion damage
	if triggerer != null and triggerer.has_method("take_damage"):
		var damage: int = 2 + level.depth
		triggerer.take_damage(damage, "corrosion trap")
