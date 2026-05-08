class_name WarpingTrap
extends Trap
## Teleports the victim to a random location and applies vertigo.

func _init() -> void:
	trap_name = "warping trap"
	color = Color(0.5, 0.0, 0.8)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("Reality warps around you!")

	if triggerer == null:
		return

	# Teleport to random passable cell
	var new_pos: int = level.random_passable_cell()
	if new_pos < 0:
		return

	if triggerer.has_method("set_pos"):
		triggerer.set_pos(new_pos)
	elif triggerer.get("pos") != null:
		triggerer.pos = new_pos

	# Apply vertigo from the disorientation
	if triggerer.has_method("add_buff"):
		var vert: Vertigo = Vertigo.new()
		vert.duration = 10.0
		vert.time_left = 10.0
		triggerer.add_buff(vert)

	# Deal minor warp sickness damage
	if triggerer.has_method("take_damage"):
		@warning_ignore("integer_division")
		var damage: int = 2 + level.depth / 3
		triggerer.take_damage(damage, "warping trap")

	if MessageLog:
		MessageLog.add_negative("You feel disoriented from the teleport!")
