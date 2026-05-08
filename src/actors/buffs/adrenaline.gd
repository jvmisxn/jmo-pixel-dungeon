class_name Adrenaline
extends Buff
## Adrenaline: doubles movement speed.
## Original: speed *= 2f in Char.speed(). Duration varies by source.
## NOT the same as AdrenalineSurge (which boosts STR).

const BASE_DURATION: float = 5.0

func _init() -> void:
	buff_id = "Adrenaline"
	buff_name = "Adrenaline"
	buff_type = BuffType.POSITIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(1.0, 0.5, 0.0)

func modify_speed(speed: float) -> float:
	return speed * 2.0

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_positive("%s surges with adrenaline!" % target.name)

func description() -> String:
	return "Moving at double speed!"
