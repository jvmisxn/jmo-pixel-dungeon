class_name Drowsy
extends Buff
## Drowsy: a warning buff that puts the target to sleep when it expires.
## Original: MagicalSleep applies Drowsy first (5 turns), then Sleep on expiry.
## Moving or taking damage resets the countdown.

const BASE_DURATION: float = 5.0

func _init() -> void:
	buff_id = "Drowsy"
	buff_name = "Drowsy"
	buff_type = BuffType.NEGATIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.4, 0.4, 0.8)

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_warning("%s feels drowsy..." % target.name)

func on_turn() -> void:
	if target == null:
		return
	# When countdown expires, apply Sleep
	if time_left <= 1.0:
		var sleep := SleepBuff.new()
		target.add_buff(sleep)
		if MessageLog:
			MessageLog.add_negative("%s falls into a deep sleep!" % target.name)
		target.remove_buff(self)

func on_damage_taken(amount: int, _source: Variant) -> void:
	# Taking damage resets the drowsy timer
	if amount > 0:
		time_left = duration
		if MessageLog and target:
			MessageLog.add_info("%s shakes off the drowsiness!" % target.name)

func on_move(_old_pos: int, _new_pos: int) -> void:
	# Moving resets the drowsy timer
	time_left = duration

func description() -> String:
	return "Getting sleepy... Will fall asleep in %s turns unless disturbed." % disp_turns(time_left)
