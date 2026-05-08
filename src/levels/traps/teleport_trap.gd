class_name TeleportTrap
extends Trap
## Teleports the triggerer to a random passable cell on the level.

func _init() -> void:
	trap_name = "teleportation trap"
	color = Color(0.2, 0.6, 1.0)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("You are teleported!")

	var new_pos: int = level.random_passable_cell()
	if new_pos < 0:
		return

	if triggerer != null and triggerer.has_method("set_pos"):
		triggerer.set_pos(new_pos)
	elif triggerer != null and triggerer.get("pos") != null:
		triggerer.pos = new_pos
