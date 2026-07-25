class_name Weakness
extends Buff
## Reduces outgoing attack damage while active.

const BASE_DURATION: float = 20.0

func _init() -> void:
	buff_id = "Weakness"
	buff_name = "Weakened"
	buff_type = BuffType.NEGATIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color.WHITE

func description() -> String:
	return "Everything suddenly seems much heavier.\n\nWeakening magic reduces a character's physical strength, causing them to deal 33%% reduced damage.\n\nTurns of weakness remaining: %s." % disp_turns(time_left)
