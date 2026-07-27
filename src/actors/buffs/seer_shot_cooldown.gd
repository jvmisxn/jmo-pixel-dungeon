class_name SeerShotCooldown
extends Buff
## Cooldown tracker for the Huntress Seer Shot talent (upstream
## `Talent.SeerShotCooldown`): 20 turns must pass between reveals.

const COOLDOWN: float = 20.0

func _init() -> void:
	buff_id = "SeerShotCooldown"
	buff_name = "Seer Shot Cooldown"
	buff_type = BuffType.NEUTRAL
	duration = COOLDOWN
	time_left = COOLDOWN
	icon_color = Color(0.4, 0.6, 0.6)

func description() -> String:
	return "Seer Shot is recharging and cannot reveal another area yet."
