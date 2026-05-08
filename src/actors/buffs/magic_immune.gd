class_name MagicImmune
extends Buff
## Magic Immunity: blocks all magic damage for a short duration.

const BASE_DURATION: float = 5.0

func _init() -> void:
	buff_id = "MagicImmune"
	buff_name = "Magic Immune"
	is_debuff = false
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.6, 0.9, 1.0)

## Check if a damage source is magical. Called by damage processing logic.
func blocks_magic() -> bool:
	return true

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_positive("%s is immune to magic!" % target.name)

func on_detach() -> void:
	if MessageLog and target:
		MessageLog.add_info("%s's magic immunity fades." % target.name)

func description() -> String:
	return "Immune to all magical effects and damage."
