class_name Healing
extends Buff
## Gradual healing pool. Original: Healing buff. Each turn heals
## round(percent_per_tick * healing_left) + flat_per_tick HP, clamped
## between 1 and the remaining pool, then detaches once the pool is spent.

var healing_left: int = 0
var percent_per_tick: float = 0.0
var flat_per_tick: int = 0

func _init() -> void:
	buff_id = "Healing"
	buff_name = "Healing"
	buff_type = BuffType.POSITIVE
	duration = -1  # Ends when the healing pool runs out, not on a timer
	icon_color = Color(0.9, 0.3, 0.3)

## Configure the pool. Upstream: Healing.setHeal(amount, percent, flat).
func set_heal(amount: int, percent: float, flat: int) -> void:
	healing_left = amount
	percent_per_tick = percent
	flat_per_tick = flat

func heal_per_tick() -> int:
	return clampi(roundi(percent_per_tick * float(healing_left)) + flat_per_tick,
			1, healing_left)

func on_turn() -> void:
	if healing_left <= 0:
		return
	var tick: int = heal_per_tick()
	if target != null and target.has_method("heal"):
		target.heal(tick)
	healing_left -= tick

func is_expired() -> bool:
	return healing_left <= 0

func description() -> String:
	return "Magical energies are mending this character's wounds. %d healing remains." % healing_left

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["healing_left"] = healing_left
	data["percent_per_tick"] = percent_per_tick
	data["flat_per_tick"] = flat_per_tick
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	healing_left = int(data.get("healing_left", healing_left))
	percent_per_tick = float(data.get("percent_per_tick", percent_per_tick))
	flat_per_tick = int(data.get("flat_per_tick", flat_per_tick))
