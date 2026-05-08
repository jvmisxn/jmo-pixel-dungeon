class_name Swiftthistle
extends Plant
## Grants the Haste buff, doubling movement speed for a duration.

const HASTE_DURATION: float = 15.0

func _init() -> void:
	plant_id = "Swiftthistle"
	plant_name = "Swiftthistle"

func _do_effect(char: Variant, _level: Variant) -> void:
	if char == null:
		return

	if char.has_method("add_buff"):
		var haste: Haste = Haste.new()
		haste.set_duration(HASTE_DURATION)
		char.add_buff(haste)

	if MessageLog:
		if char.get("is_hero"):
			MessageLog.add_positive("You feel a surge of energy! " +
				"Everything seems to slow down.")
		else:
			MessageLog.add("The %s moves with unnatural speed!" % str(char.get("name")))
