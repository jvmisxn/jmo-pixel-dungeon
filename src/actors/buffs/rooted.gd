class_name Rooted
extends Buff
## Prevents all movement but allows other actions.

const BASE_DURATION: float = 5.0

func _init() -> void:
	buff_id = "Rooted"
	buff_name = "Rooted"
	buff_type = BuffType.NEGATIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.2, 0.6, 0.0)

func description() -> String:
	return "Cannot move, but can still attack and use items."
