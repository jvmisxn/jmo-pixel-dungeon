class_name Stamina
extends Buff
## Stamina buff: increases movement speed by 50%.
## Original: FlavourBuff with DURATION=100f, grants +50% speed via Char.speed().

const BASE_DURATION: float = 100.0
const SPEED_MULTIPLIER: float = 1.5

func _init() -> void:
	buff_id = "Stamina"
	buff_name = "Stamina"
	is_debuff = false
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.9, 0.8, 0.2)

func modify_speed(speed: float) -> float:
	return speed * SPEED_MULTIPLIER

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_positive("%s braces with stamina!" % target.name)

func on_detach() -> void:
	if MessageLog and target:
		MessageLog.add_info("%s's stamina fades." % target.name)

func description() -> String:
	return "Moving 50%% faster! (%s remaining)" % disp_turns(time_left)
