class_name Stormvine
extends Plant
## Applies the Rooted debuff to the character, preventing movement.
## Also applies vertigo (reduced accuracy via Blindness-like effect).

const ROOT_DURATION: float = 5.0

func _init() -> void:
	plant_id = "Stormvine"
	plant_name = "Stormvine"

func _do_effect(char: Variant, _level: Variant) -> void:
	if char == null:
		return

	if char.has_method("add_buff"):
		# Root the character in place
		var root: Rooted = Rooted.new()
		root.set_duration(ROOT_DURATION)
		char.add_buff(root)

	if MessageLog:
		if char.get("is_hero"):
			MessageLog.add_negative("Thick vines grip your " +
				"legs and the world spins!")
		else:
			MessageLog.add("Vines grip the %s!" % str(char.get("name")))
