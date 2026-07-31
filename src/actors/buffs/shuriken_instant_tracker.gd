class_name ShurikenInstantTracker
extends Buff
## Shuriken throw-timing window. Original: Shuriken.ShurikenInstantTracker.
## A shuriken thrown while this tracker is absent costs no time and starts
## this window at DURATION - 1 turns (one less because that throw was
## instant). While the window lasts, shuriken throws cost normal time.

const DURATION: float = 20.0

func _init() -> void:
	buff_id = "ShurikenInstantTracker"
	buff_name = "Shuriken Throw"
	buff_type = BuffType.NEUTRAL
	duration = DURATION - 1.0
	icon_color = Color(0.6, 0.6, 0.6)

func description() -> String:
	return (
		"You have recently thrown a shuriken. Your next instant shuriken "
		+ "throw becomes available when this effect ends.\n\nTurns "
		+ "remaining: %s." % disp_turns(time_left)
	)
