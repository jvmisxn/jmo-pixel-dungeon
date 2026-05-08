class_name Hunger
extends Buff
## Tracks the hero's hunger level. Original thresholds: HUNGRY=300, STARVING=450.
## Starvation damage uses partialDamage accumulator (HT/1000 per tick).

enum HungerLevel { SATISFIED, NORMAL, HUNGRY, STARVING }

## Original constants
const HUNGRY_THRESHOLD: float = 300.0
const STARVING_THRESHOLD: float = 450.0

var hunger_value: float = 0.0
var hunger_level: HungerLevel = HungerLevel.SATISFIED
## Accumulates fractional starvation damage (original: HT/1000 per tick).
var partial_damage: float = 0.0

func _init() -> void:
	buff_id = "Hunger"
	buff_name = "Hunger"
	is_debuff = false
	duration = -1  # Permanent
	icon_color = Color(0.8, 0.6, 0.2)

func on_turn() -> void:
	if target == null:
		return

	# Skip hunger if WellFed buff is active (original behavior)
	if target.has_buff("WellFed"):
		return

	# Skip hunger on locked floors and vault levels (original: Dungeon.level.locked)
	if GameManager and GameManager.get("floor_locked"):
		return

	if is_starving():
		# Original: partialDamage += target.HT / 1000f; deal int portion
		partial_damage += target.ht / 1000.0
		if partial_damage > 1.0:
			target.take_damage(int(partial_damage), self)
			partial_damage -= int(partial_damage)
	else:
		var new_level: float = hunger_value + 1.0
		if new_level >= STARVING_THRESHOLD:
			if hunger_value < STARVING_THRESHOLD:
				# First transition to starving — deal 1 damage and warn (original behavior)
				if MessageLog:
					MessageLog.add_negative("You are starving!")
				target.take_damage(1, self)
			new_level = STARVING_THRESHOLD
		elif new_level >= HUNGRY_THRESHOLD and hunger_value < HUNGRY_THRESHOLD:
			if MessageLog:
				MessageLog.add_warning("You feel hungry.")
		hunger_value = new_level

	_update_level()

func _update_level() -> void:
	if hunger_value <= 0.0:
		hunger_level = HungerLevel.SATISFIED
	elif hunger_value < HUNGRY_THRESHOLD:
		hunger_level = HungerLevel.NORMAL
	pass
