class_name LethalMomentumTracker
extends Buff
## Warrior Lethal Momentum tracker (upstream Talent.LethalMomentumTracker, a
## 0-duration FlavourBuff). Attached in Mob.die() when a hero's killing blow
## passes the 34% + 33%-per-point roll; consumed by Hero._get_attack_delay
## (upstream Hero.attackDelay), which detaches it and returns 0 so the blow
## costs no time. Port note: upstream's 0f FlavourBuff expires once the actor
## loop resumes; duration 1.0 here gives the same one-action window because
## the tracker is consumed inside the same attack action that attached it.

const DURATION := 1.0

func _init() -> void:
	buff_id = "LethalMomentumTracker"
	buff_name = "Lethal Momentum"
	buff_type = BuffType.POSITIVE
	duration = DURATION
	time_left = DURATION
	show_in_ui = false
