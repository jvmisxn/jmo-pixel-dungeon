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
		return

	# Accumulate partial regen: 1/REGENERATION_DELAY HP per turn
	# Herbalism talent, ring of energy, etc. could modify the rate here
	partial_regen += 1.0 / REGENERATION_DELAY

	# Heal when a full HP is accumulated
	while partial_regen >= 1.0:
		partial_regen -= 1.0
		if target.hp < target.ht:
			target.heal(1)


## Check if the hero is starving (regen pauses while starving).
func _is_starving() -> bool:
	if target == null:
		return false
	if target.has_method("has_buff") and target.has_buff("Hunger"):
		var hunger: Variant = target.get_buff("Hunger") if target.has_method("get_buff") else null
		if hunger != null and hunger.has_method("is_starving"):
			return hunger.is_starving()
	return false


## Whether regen is active on the current floor.
## Paused on boss floors while the boss is alive (original behavior).
func _regen_on() -> bool:
	if GameManager == null:
		return true
	var depth: int = GameManager.depth
	# Boss floors: 5, 10, 15, 20, 25
	if depth % 5 == 0 and depth > 0:
		var level: Variant = GameManager.current_level
		if level != null and level.has_method("is_locked") and level.is_locked():
			return false
	return true
