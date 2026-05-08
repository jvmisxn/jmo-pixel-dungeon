class_name Daze
extends Buff
## Daze debuff: reduces accuracy by 50% and causes random movement.
## Original: halves accuracy in hit formula, causes random movement like Vertigo.

const BASE_DURATION: float = 5.0

func _init() -> void:
	buff_id = "Daze"
	buff_name = "Dazed"
	buff_type = BuffType.NEGATIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.8, 0.6, 0.3)

func modify_accuracy(acc: int) -> int:
	@warning_ignore("integer_division")
	return acc / 2

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_negative("%s is dazed!" % target.name)

func description() -> String:
	return "Dazed! Accuracy halved and movement is erratic."
