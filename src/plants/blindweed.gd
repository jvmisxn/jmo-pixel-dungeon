class_name Blindweed
extends Plant
## Applies Blindness to the character, reducing their vision to their
## own tile and halving accuracy.

const BLIND_DURATION: float = 10.0

func _init() -> void:
	plant_id = "Blindweed"
	plant_name = "Blindweed"

func _do_effect(char: Variant, _level: Variant) -> void:
	if char == null:
		return

	if char.has_method("add_buff"):
		var blind: Blindness = Blindness.new()
		blind.set_duration(BLIND_DURATION)
		char.add_buff(blind)

	if MessageLog:
		if char.get("is_hero"):
			MessageLog.add_negative("A thick cloud of " +
				"pollen blinds you!")
		else:
			MessageLog.add("The %s stumbles blindly!" % str(char.get("name")))
