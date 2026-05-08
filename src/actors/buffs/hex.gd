class_name Hex
extends Buff
## Hex debuff: reduces accuracy and evasion by 20%.

const BASE_DURATION: float = 10.0
const PENALTY_FACTOR: float = 0.8

func _init() -> void:
	buff_id = "Hex"
	buff_name = "Hexed"
	buff_type = BuffType.NEGATIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.4, 0.0, 0.4)

func modify_accuracy(acc: int) -> int:
	return int(acc * PENALTY_FACTOR)

func modify_evasion(eva: int) -> int:
	return int(eva * PENALTY_FACTOR)

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_negative("%s has been hexed!" % target.name)

func description() -> String:
	return "Accuracy and evasion reduced by 20%."
