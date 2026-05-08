class_name PitfallTrap
extends Trap
## Drops the victim to the next level (only effective in caves-like areas).

func _init() -> void:
	trap_name = "pitfall trap"
	color = Color(0.4, 0.3, 0.2)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if triggerer == null:
		return

	# Convert tile to chasm
	level.set_terrain(pos, ConstantsData.Terrain.CHASM)

	# Deal fall damage
	if triggerer.has_method("take_damage"):
		var damage: int = randi_range(level.depth, level.depth * 2)
		triggerer.take_damage(damage, "pitfall trap")

	if MessageLog:
		MessageLog.add_negative("The floor crumbles beneath you!")

	# Apply cripple from the landing
	if triggerer.has_method("add_buff"):
		var crip: Cripple = Cripple.new()
		crip.duration = 8.0
		crip.time_left = 8.0
		triggerer.add_buff(crip)

	# Teleport to next depth entrance (simulating falling)
	# In actual implementation, this would trigger a depth change
	# For now, teleport to a random passable cell as a proxy
	var new_pos: int = level.random_passable_cell()
	if new_pos >= 0:
		if triggerer.has_method("set_pos"):
			triggerer.set_pos(new_pos)
		elif triggerer.get("pos") != null:
			triggerer.pos = new_pos
