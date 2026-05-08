class_name Doom
extends Buff
## Doom debuff: the character dies when this buff expires.
## Can only be removed by Remove Curse effects.

const BASE_DURATION: float = 30.0

func _init() -> void:
	buff_id = "Doom"
	buff_name = "Doomed"
	buff_type = BuffType.NEGATIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.2, 0.0, 0.0)

func on_turn() -> void:
	if target == null:
		return
	# When doom expires, the target dies
	if time_left <= 1.0:
		if MessageLog:
			MessageLog.add_negative("%s succumbs to doom!" % target.name)
		target.take_damage(target.hp, self)

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_negative("%s has been doomed!" % target.name)

## Doom resists normal removal. Only remove_curse can strip it.
func can_be_cleansed() -> bool:
	return false

func description() -> String:
	return "Death awaits when the countdown ends (%d turns). Only Remove Curse can save you." % int(time_left)
