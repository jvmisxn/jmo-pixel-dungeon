class_name EmpoweredStrikeTracker
extends Buff
## Battlemage Empowered Strike tracker (upstream Talent.EmpoweredStrikeTracker,
## a FlavourBuff). Granted for 10 turns when the Battlemage zaps his staff's
## imbued wand; consumed by his next melee strike with the staff, which deals
## bonus damage (Hero.attack_proc applies 1 + points/6, Math.round semantics).
## Upstream's delayedDetach exists only for blast-wave on-hit resolution,
## which the port's generic staff on-hit doesn't have.

const DURATION := 10.0

func _init() -> void:
	buff_id = "EmpoweredStrikeTracker"
	buff_name = "Empowered Strike"
	buff_type = BuffType.POSITIVE
	duration = DURATION
	show_in_ui = false
