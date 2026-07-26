class_name SuckerPunchTracker
extends Buff
## Upstream Talent.SuckerPunchTracker: a permanent marker attached to an
## enemy the first time the Rogue lands a Sucker Punch surprise attack on it,
## so the bonus damage applies only once per enemy. Attached by
## Hero.attack_proc (upstream Talent.onAttackProc); serializes with the mob.

func _init() -> void:
	buff_id = "SuckerPunchTracker"
	buff_name = "Sucker Punched"
	buff_type = BuffType.NEUTRAL
	icon_color = Color(0.55, 0.45, 0.65)

func description() -> String:
	return ("This creature has already been caught off-guard by the Rogue's"
		+ " sucker punch and cannot be surprised that way again.")
