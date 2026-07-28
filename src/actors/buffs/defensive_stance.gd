class_name DefensiveStance
extends Buff
## Duelist Quarterstaff Defensive Stance. Original:
## Quarterstaff.DefensiveStance (FlavourBuff): while active the hero's
## evasion is tripled (Hero.defenseSkill evasion *= 3).

const EVASION_FACTOR: int = 3

func _init() -> void:
	buff_id = "DefensiveStance"
	buff_name = "Defensive Stance"
	buff_type = BuffType.POSITIVE
	announced = true
	icon_color = Color(0.4, 0.75, 1.0)

func evasion_modifier(eva: int) -> int:
	return eva * EVASION_FACTOR

func description() -> String:
	return "You are in a defensive stance, greatly boosting your evasion."
