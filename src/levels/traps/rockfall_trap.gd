class_name RockfallTrap
extends Trap
## Deals physical damage and cripples the victim from falling rocks.

func _init() -> void:
	trap_name = "rockfall trap"
	color = Color(0.5, 0.4, 0.3)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("Rocks crash down from above!")

	if triggerer == null:
		return

	# Deal physical damage
	if triggerer.has_method("take_damage"):
		var damage: int = randi_range(level.depth, level.depth * 2 + 5)
		triggerer.take_damage(damage, "rockfall trap")

	# Apply cripple (leg injury from falling rocks)
	if triggerer.has_method("add_buff"):
		var crip: Cripple = Cripple.new()
		@warning_ignore("integer_division")
		var dur: float = 5.0 + float(level.depth) / 2.0
		crip.duration = dur
		crip.time_left = dur
		triggerer.add_buff(crip)

	# Also damage mobs in adjacent cells (rocks scatter)
	for dir: int in ConstantsData.DIRS_4:
		var adj: int = pos + dir
		if level.adjacent(pos, adj):
			var mob: Variant = level.mob_at(adj)
			if mob != null and mob.has_method("take_damage"):
				@warning_ignore("integer_division")
				var splash_damage: int = level.depth / 2 + 2
				mob.take_damage(splash_damage, "rockfall trap")
