class_name RejuvenatingStepsCooldown
extends Buff
## Huntress Rejuvenating Steps cooldown (upstream Talent.RejuvenatingStepsCooldown,
## a FlavourBuff): while present, stepping on short grass or embers sprouts
## nothing. Attached for 15 - 5*points turns (10/5) each time the talent fires.

func _init() -> void:
	buff_id = "RejuvenatingStepsCooldown"
	buff_name = "Rejuvenating Steps Cooldown"
	buff_type = BuffType.NEUTRAL
	icon_color = Color(0.3, 0.8, 0.3)

func description() -> String:
	return ("You have recently used this talent, and must wait before " +
		"using it again.\n\nTurns remaining: %s.") % disp_turns(time_left)
