class_name Sorrowmoss
extends Plant
## Applies Poison to the character that steps on it. The poison duration
## scales slightly with dungeon depth.

const BASE_POISON: float = 4.0
const POISON_PER_DEPTH: float = 0.5

func _init() -> void:
	plant_id = "Sorrowmoss"
	plant_name = "Sorrowmoss"

func _do_effect(char: Variant, level: Variant) -> void:
	if char == null:
		return

	var depth: int = 1
	if level and level.get("depth") != null:
		depth = level.depth

	var poison_amount: float = BASE_POISON + depth * POISON_PER_DEPTH

	if char.has_method("add_buff"):
		var poison: Poison = Poison.create(poison_amount)
		char.add_buff(poison)

	if MessageLog:
		if char.get("is_hero"):
			MessageLog.add_negative("Toxic spores cloud around you!")
		else:
			MessageLog.add("Toxic spores surround the %s!" % str(char.get("name")))
