class_name WornDartTrap
extends Trap
## Simple dart trap — low damage, common in early levels.

func _init() -> void:
	trap_name = "worn dart trap"
	color = Color(0.5, 0.5, 0.5)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A worn dart shoots out!")

	if triggerer != null and triggerer.has_method("take_damage"):
		@warning_ignore("integer_division")
		var damage: int = maxi(1, 1 + level.depth / 4)
		triggerer.take_damage(damage, "worn dart")
