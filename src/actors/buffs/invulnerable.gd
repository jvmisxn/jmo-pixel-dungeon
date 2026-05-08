class_name Invulnerable
extends Buff
## Invulnerability buff: blocks ALL damage from specific sources.
## Original (Invulnerability.java): used by boss phases (DM-300 supercharge),
## specific abilities, and items.
## While active, isInvulnerable() returns true for all sources.

const BASE_DURATION: float = 5.0

func _init() -> void:
	buff_id = "Invulnerable"
	buff_name = "Invulnerable"
	buff_type = BuffType.POSITIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(1.0, 1.0, 0.3)

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_positive("%s becomes invulnerable!" % target.name)

func description() -> String:
	return "Invulnerable to all damage (%s turns left)." % disp_turns(time_left)
