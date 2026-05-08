class_name SleepBuff
extends Buff
## Sleep/Drowsy: character skips turns, wakes on taking damage.

func _init() -> void:
	buff_id = "Sleep"
	buff_name = "Sleeping"
	buff_type = BuffType.NEGATIVE
	duration = -1.0  # Permanent until woken
	time_left = -1.0
	icon_color = Color(0.5, 0.5, 1.0)

func modify_speed(_speed: float) -> float:
	return 0.0  # Cannot act while sleeping

func on_damage_taken(amount: int, _source: Variant) -> void:
	if amount > 0 and target:
		target.remove_buff(self)
		if MessageLog:
			MessageLog.add_info("%s wakes up!" % target.name)

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_info("%s falls asleep." % target.name)

func on_detach() -> void:
	pass  # Wake-up message handled in on_damage_taken

func description() -> String:
	return "Sleeping deeply. Taking any damage will wake the character."
