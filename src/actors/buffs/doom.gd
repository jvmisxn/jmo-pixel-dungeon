class_name Doom
extends Buff
## Doom debuff: the character takes amplified damage until Remove Curse.
## Can only be removed by Remove Curse effects.

func _init() -> void:
	buff_id = "Doom"
	buff_name = "Doomed"
	buff_type = BuffType.NEGATIVE
	duration = -1.0
	time_left = -1.0
	icon_color = Color(0.2, 0.0, 0.0)

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_negative("%s has been doomed!" % target.name)

## Doom resists normal removal. Only remove_curse can strip it.
func can_be_cleansed() -> bool:
	return false

func description() -> String:
	return "The doomed take 67% more damage. Only Remove Curse can save you."
