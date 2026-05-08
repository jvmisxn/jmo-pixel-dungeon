class_name Fury
extends Buff
## Activates when HP is below 50%. Increases damage dealt by 50%.

func _init() -> void:
	buff_id = "Fury"
	buff_name = "Fury"
	is_debuff = false
	duration = -1  # Conditional — removed when HP goes above threshold
	icon_color = Color(1.0, 0.2, 0.2)

func modify_damage(dmg: int) -> int:
	return int(dmg * 1.5)

func on_turn() -> void:
	# Original checks HP > HT/2 (base max HP, not buffed max)
	@warning_ignore("integer_division")
	if target and target.hp > target.ht / 2:
		target.remove_buff(self)

func description() -> String:
	return "Furious! Dealing 50% more damage while HP is below half."
