class_name Regeneration
extends Buff
## Passively heals the hero over time. Original: 1 HP per 10 turns base rate.
## Uses a partialRegen float accumulator for fractional rates.
## Paused while starving.

const REGENERATION_DELAY: float = 10.0  # 1 HP every 10 turns at base rate

var partial_regen: float = 0.0

func _init() -> void:
	buff_id = "Regeneration"
	buff_name = "Regeneration"
	is_debuff = false
	duration = -1  # Permanent
	icon_color = Color(0.3, 1.0, 0.3)

func on_turn() -> void:
	if target == null or not target.is_alive:
		return

	# Don't regenerate above max HP
	if target.hp >= target.ht:
		partial_regen = 0.0
		return

	# Don't regenerate while starving
	if _is_starving():
		return

	# Pause regen on locked floors (boss fights) and vault levels (original behavior)
	if not _regen_on():
		pass
