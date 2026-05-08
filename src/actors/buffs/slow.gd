class_name Slow
extends Buff
## Slow debuff: halves speed. Original: timeScale *= 0.5f in Char.spend().

const BASE_DURATION: float = 10.0

func _init() -> void:
	buff_id = "Slow"
	buff_name = "Slowed"
	buff_type = BuffType.NEGATIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.4, 0.4, 0.6)

## NOTE: Slow does NOT modify speed() — it works through time scaling in
## spend_turn() (actions cost 2x time). This matches original Char.spend()
## where timeScale *= 0.5 for Slow. Do NOT add modify_speed() here.

