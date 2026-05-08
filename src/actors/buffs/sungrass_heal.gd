class_name SungrassHealBuff
extends Buff
## Healing buff applied by Sungrass plants. Heals a small amount each turn.

const HEAL_PER_TURN: int = 2
const BASE_DURATION: float = 12.0

func _init() -> void:
	buff_id = "SungrassHeal"
	buff_name = "Herbal Healing"
	is_debuff = false
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.2, 0.8, 0.0)

func on_turn() -> void:
	if target and target.has_method("heal"):
		target.heal(HEAL_PER_TURN)
		if MessageLog:
			MessageLog.add_positive("The sungrass heals you for %d HP." % HEAL_PER_TURN)

func description() -> String:
	return "Slowly regenerating health from sungrass (%d turns left)." % int(time_left)
