class_name Levitation
extends Buff
## Allows floating over chasms and traps. Immune to gripping/rooted.

const BASE_DURATION: float = 20.0

func _init() -> void:
	buff_id = "Levitation"
	buff_name = "Levitating"
	is_debuff = false
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.8, 0.8, 1.0)

func description() -> String:
	return "Floating above the ground. Immune to traps and chasms."
