class_name Bless
extends Buff
## Bless buff: increases accuracy and evasion by 20%. Does NOT boost damage.

const BASE_DURATION: float = 30.0
const BONUS_FACTOR: float = 1.25

func _init() -> void:
	buff_id = "Bless"
	buff_name = "Blessed"
	is_debuff = false
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(1.0, 1.0, 0.6)

func modify_accuracy(acc: int) -> int:
	return int(acc * BONUS_FACTOR)

func modify_evasion(eva: int) -> int:
	return int(eva * BONUS_FACTOR)

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_positive("%s is blessed!" % target.name)

func on_detach() -> void:
	if MessageLog and target:
		MessageLog.add_info("The blessing fades from %s." % target.name)

func description() -> String:
	return "Accuracy and evasion increased by 25%%."
