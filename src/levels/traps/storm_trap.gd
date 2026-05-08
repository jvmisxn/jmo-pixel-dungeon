class_name StormTrap
extends Trap
## Creates an electrical storm affecting a large area.

func _init() -> void:
	trap_name = "storm trap"
	color = Color(0.8, 0.9, 1.0)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A violent storm erupts!")

	var base_damage: int = 8 + level.depth * 2

	# Large area of effect — 7x7 grid centered on trap
	var width: int = Level.W
	var storm_cells: Array[int] = []

	for dy: int in range(-3, 4):
		for dx: int in range(-3, 4):
			var cell: int = pos + dx + dy * width
			if cell >= 0 and cell < Level.LEN:
				storm_cells.append(cell)

	# Damage everyone in the storm area (including the triggerer)
	for cell: int in storm_cells:
		var mob: Variant = level.mob_at(cell)
		if mob != null and mob.has_method("take_damage"):
			# Randomize damage per strike
			var damage: int = randi_range(base_damage / 2, base_damage)
			mob.take_damage(damage, "storm trap")

		# Water tiles amplify — damage again
		var t: int = level.terrain_at(cell)
		if t == ConstantsData.Terrain.WATER:
			var water_mob: Variant = level.mob_at(cell)
			if water_mob != null and water_mob.has_method("take_damage"):
				@warning_ignore("integer_division")
				water_mob.take_damage(base_damage / 3, "storm trap")

	# Also damage the triggerer directly
	if triggerer != null and triggerer.has_method("take_damage"):
		triggerer.take_damage(base_damage, "storm trap")

	# Blind nearby characters from the flash
	for dir: int in ConstantsData.DIRS_8:
		var adj: int = pos + dir
		if adj >= 0 and adj < Level.LEN:
			var adj_mob: Variant = level.mob_at(adj)
			if adj_mob != null and adj_mob.has_method("add_buff"):
				var blind: Blindness = Blindness.new()
				blind.duration = 3.0
				blind.time_left = 3.0
				adj_mob.add_buff(blind)
