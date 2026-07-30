class_name FocusBuff
extends Buff
## Monk Focus stance. Original: MonkEnergy.MonkAbility.Focus.FocusBuff.
## While active every incoming attack misses (upstream Char.hit treats the
## defender as INFINITE_EVASION); the first parried attack consumes the
## buff (upstream Hero.defenseVerb detaches it and reports "parried").
## Lasts until it parries — no duration.

func _init() -> void:
	buff_id = "FocusBuff"
	buff_name = "Focus"
	buff_type = BuffType.POSITIVE
	duration = -1  # Consumed on parry, never expires on its own
	announced = true
	icon_color = Color(0.25, 1.0, 0.67)  # upstream hardlight 0.25/1.5/1

## Large enough that multiplicative debuff modifiers applied after this one
## cannot pull the result back under Char.hit's infinite-evasion threshold.
func evasion_modifier(_eva: int) -> int:
	return 1000000000

## Char's miss path notifies defender buffs with amount 0. A 0 while focused
## is a parry: consume the buff (upstream Hero.defenseVerb). When a Guard
## stance is also up, guard takes the block and focus is preserved
## (upstream defenseVerb checks GuardTracker first and returns early).
func on_damage_taken(amount: int, _source: Variant) -> void:
	if amount > 0 or target == null:
		return
	if target.has_method("has_buff") and target.has_buff("GuardTracker"):
		return
	if MessageLog and target is Hero:
		MessageLog.add_positive("You parry the attack!")
	if target.has_method("remove_buff"):
		target.remove_buff(self)

func description() -> String:
	return "You are focused, ready to parry the next attack made against you."
