class_name Recharging
extends Buff
## Recharging buff: wands recharge 4x faster.

const BASE_DURATION: float = 15.0
const RECHARGE_MULTIPLIER: float = 4.0

func _init() -> void:
	buff_id = "Recharging"
	buff_name = "Recharging"
	is_debuff = false
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(1.0, 1.0, 0.0)

## Called by wand recharge logic to get the speed multiplier.
func recharge_rate() -> float:
	return RECHARGE_MULTIPLIER

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_positive("%s's wands begin recharging rapidly!" % target.name)

func on_detach() -> void:
	if MessageLog and target:
		MessageLog.add_info("%s's rapid recharging fades." % target.name)

func description() -> String:
	return "Wands recharge at %dx speed!" % int(RECHARGE_MULTIPLIER)
