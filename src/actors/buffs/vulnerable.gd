class_name Vulnerable
extends Buff
## Vulnerable debuff: increases damage taken by 33%.
## Original: applied AFTER armor reduction, multiplying effective damage by 1.33x.
## This is NOT an armor reduction — it amplifies post-armor damage.

const BASE_DURATION: float = 5.0
const DAMAGE_MULTIPLIER: float = 1.33

func _init() -> void:
	buff_id = "Vulnerable"
	buff_name = "Vulnerable"
	buff_type = BuffType.NEGATIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(1.0, 0.3, 0.3)

## NOTE: The damage amplification should be applied in the damage pipeline
## AFTER armor reduction, not as an armor modifier. The combat system should
## check for Vulnerable and multiply post-armor damage by 1.33.
## This is a marker buff — the actual logic lives in char.gd's take_damage().

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_negative("%s becomes vulnerable!" % target.name)

func description() -> String:
	return "Taking %.0f%% more damage." % ((DAMAGE_MULTIPLIER - 1.0) * 100.0)
