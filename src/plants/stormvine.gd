class_name Stormvine
extends Plant
## Applies Rooted and Vertigo to the target, preventing reliable movement.

const ROOT_DURATION: float = 5.0

func _init() -> void:
	plant_id = "Stormvine"
	plant_name = "Stormvine"

func _do_effect(char: Variant, _level: Variant) -> void:
	if char == null:
		return

	if char.has_method("add_buff"):
		var root: Rooted = Rooted.new()
		root.set_duration(ROOT_DURATION)
		char.add_buff(root)
		var vertigo: Vertigo = Vertigo.new()
		vertigo.set_duration(ROOT_DURATION)
		char.add_buff(vertigo)

	if MessageLog:
		if char.get("is_hero"):
			MessageLog.add_negative("Thick vines grip your " +
				"legs and the world spins!")
		else:
			MessageLog.add("Vines grip the %s!" % str(char.get("name")))
