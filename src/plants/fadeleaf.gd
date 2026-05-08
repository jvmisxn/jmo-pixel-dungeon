class_name Fadeleaf
extends Plant
## Teleports the character that steps on it to a random passable cell.

func _init() -> void:
	plant_id = "Fadeleaf"
	plant_name = "Fadeleaf"

func _do_effect(char: Variant, level: Variant) -> void:
	if char == null or level == null:
		return

	var new_pos: int = -1
	if level.has_method("random_passable_cell"):
		new_pos = level.random_passable_cell()

	if new_pos < 0:
		return

	# Move the character
	if char.has_method("set_pos"):
		char.set_pos(new_pos)
	elif char.get("pos") != null:
		char.pos = new_pos

	if MessageLog:
		if char.get("is_hero"):
			MessageLog.add("You are teleported by the fadeleaf!")
		else:
			MessageLog.add("The %s vanishes in a puff of smoke!" % str(char.get("name")))
