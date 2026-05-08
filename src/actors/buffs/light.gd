class_name Light
extends Buff
## Light buff: increases view distance by 2 (like a torch).
## Original: DURATION=300f, increases viewDistance by 4.

const BASE_DURATION: float = 300.0
const VIEW_BONUS: int = 4

func _init() -> void:
	buff_id = "Light"
	buff_name = "Illuminated"
	buff_type = BuffType.POSITIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(1.0, 1.0, 0.6)

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_positive("%s is bathed in light!" % target.name)

func on_detach() -> void:
	if MessageLog and target:
		MessageLog.add_info("The light fades around %s." % target.name)

func description() -> String:
	return "Illuminated! View distance increased by %d." % VIEW_BONUS
