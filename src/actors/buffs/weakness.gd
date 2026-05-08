class_name Weakness
extends Buff
## Reduces the character's effective strength by 2.
## In the original, this makes heavy equipment harder to use (excess STR penalty)
## and also halves accuracy for the hero specifically.

const BASE_DURATION: float = 50.0  # Original: 50 turns
const STR_PENALTY: int = 2

func _init() -> void:
	buff_id = "Weakness"
	buff_name = "Weakened"
	buff_type = BuffType.NEGATIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color.WHITE
