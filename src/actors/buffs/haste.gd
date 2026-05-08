class_name Haste
extends Buff
## Triples movement speed (original: speed *= 3f in Char.speed()).

const BASE_DURATION: float = 20.0

func _init() -> void:
	buff_id = "Haste"
	buff_name = "Haste"
	is_debuff = false
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.3, 1.0, 1.0)

func modify_speed(speed: float) -> float:
	return speed * 3.0

func description() -> String:
	return "Moving at triple speed! (%s remaining)" % disp_turns(time_left)
