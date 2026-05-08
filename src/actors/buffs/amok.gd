class_name Amok
extends Buff
## Enraged — attacks the nearest character regardless of allegiance.

const BASE_DURATION: float = 5.0

func _init() -> void:
	buff_id = "Amok"
	buff_name = "Enraged"
	buff_type = BuffType.NEGATIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(1.0, 0.0, 0.0)

func description() -> String:
	return "Berserk! Attacking anything nearby in a blind rage."
