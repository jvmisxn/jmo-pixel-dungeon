class_name Cripple
extends Buff
## Slows movement speed significantly.

const BASE_DURATION: float = 10.0

func _init() -> void:
	buff_id = "Cripple"
	buff_name = "Crippled"
	buff_type = BuffType.NEGATIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.6, 0.4, 0.2)

func modify_speed(speed: float) -> float:
	return speed * 0.5

func description() -> String:
	return "Movement speed halved! Hobbling along painfully."
