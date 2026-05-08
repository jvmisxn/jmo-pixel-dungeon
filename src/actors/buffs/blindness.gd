class_name Blindness
extends Buff
## Prevents the character from seeing anything beyond their own tile.
## Original: does NOT modify accuracy directly — accuracy effects come from
## the hit formula checking for the Blindness buff on the defender (not attacker).
## Vision range is reduced to 0 in Char.can_see().

const BASE_DURATION: float = 10.0

func _init() -> void:
	buff_id = "Blindness"
	buff_name = "Blinded"
	buff_type = BuffType.NEGATIVE
	duration = BASE_DURATION
	icon_color = Color(0.2, 0.2, 0.2)

func description() -> String:
	return "Cannot see beyond the current tile."
