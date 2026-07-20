class_name PitfallTrap
extends Trap
## Drops the victim to the next level (only effective in caves-like areas).

func _init() -> void:
	trap_name = "pitfall trap"
	color = Color(0.4, 0.3, 0.2)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if triggerer == null:
		return

	if MessageLog:
		MessageLog.add_negative("The floor crumbles beneath you!")

	if Chasm.can_cross(triggerer):
		return

	if triggerer.get("is_hero") == true:
		if EventBus and EventBus.has_signal("hero_fell"):
			EventBus.hero_fell.emit(triggerer)
		else:
			Chasm.apply_landing_damage(triggerer, level)
	elif triggerer.has_method("die"):
		triggerer.die("pitfall trap")
