class_name MindVision
extends Buff
## Reveals all characters on the current level.

const BASE_DURATION: float = 20.0

func _init() -> void:
	buff_id = "MindVision"
	buff_name = "Mind Vision"
	is_debuff = false
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(1.0, 0.8, 1.0)

func description() -> String:
	return "Can sense all creatures on this floor."
