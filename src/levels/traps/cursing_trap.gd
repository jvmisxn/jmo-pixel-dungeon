class_name CursingTrap
extends Trap
## Curses a random equipped item on the hero.

func _init() -> void:
	trap_name = "cursing trap"
	color = Color(0.3, 0.0, 0.3)

func _do_effect(triggerer: Variant, _level: Level) -> void:
	if MessageLog:
		MessageLog.add("A dark energy curses your equipment!")

	if triggerer == null:
		return

	# Try to curse a random equipped item
	if triggerer.has_method("get_equipped_items"):
		var equipped: Array = triggerer.get_equipped_items()
		if equipped.size() > 0:
			var item: Variant = equipped[randi() % equipped.size()]
			if item != null and item.get("cursed") != null:
				item.cursed = true
				if MessageLog:
					MessageLog.add_negative("Your %s is cursed!" % item.name)
				return

	# Fallback: apply hex debuff if we can't curse equipment
	if triggerer.has_method("add_buff"):
		var hex_buff: Hex = Hex.new()
		hex_buff.duration = 30.0
		hex_buff.time_left = 30.0
		triggerer.add_buff(hex_buff)
