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
		for _attempt: int in range(12):
			new_pos = level.random_passable_cell()
			if new_pos < 0:
				continue
			if level.has_method("find_char_at") and level.find_char_at(new_pos) != null:
				continue
			if level.get("exit_pos") != null and new_pos == level.exit_pos:
				continue
			break

	if new_pos < 0:
		return

	# Move the character
	if char.has_method("set_pos"):
		char.set_pos(new_pos)
	elif char.get("pos") != null:
		char.pos = new_pos
	if char.get("is_hero") and EventBus:
		EventBus.hero_moved_detailed.emit(char, new_pos)
		var focused_hero: Variant = GameManager.get_local_hero() if GameManager and GameManager.has_method("get_local_hero") else (GameManager.hero if GameManager else null)
		if focused_hero == char:
			EventBus.hero_moved.emit(new_pos)

	if MessageLog:
		if char.get("is_hero"):
			MessageLog.add("You are teleported by the fadeleaf!")
		else:
			MessageLog.add("The %s vanishes in a puff of smoke!" % str(char.get("name")))
