class_name Combo
extends Buff
## Tracks consecutive hits (Gladiator mechanic). Higher combo = bigger finisher.

var combo_count: int = 0
const MAX_COMBO: int = 10

func _init() -> void:
	buff_id = "Combo"
	buff_name = "Combo"
	is_debuff = false
	duration = -1
	icon_color = Color(1.0, 0.8, 0.0)

func add_hit() -> void:
	combo_count = mini(combo_count + 1, MAX_COMBO)

func reset() -> void:
	combo_count = 0

## Get the finisher damage multiplier based on combo level.
func finisher_multiplier() -> float:
	if combo_count < 2:
		return 1.0
	elif combo_count < 4:
		return 1.5  # Clobber
	elif combo_count < 6:
		return 2.0  # Slam
	elif combo_count < 8:
		return 2.5  # Crush
	else:
		return 3.0  # Fury of blows

func description() -> String:
	return "Combo: %d hits! Finisher multiplier: x%.1f" % [combo_count, finisher_multiplier()]

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["combo_count"] = combo_count
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	combo_count = int(data.get("combo_count", combo_count))
