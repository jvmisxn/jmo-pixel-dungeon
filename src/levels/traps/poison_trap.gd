class_name PoisonTrap
extends Trap
## Releases a cloud of toxic gas, poisoning the triggerer.

func _init() -> void:
	trap_name = "poison dart trap"
	color = Color(0.3, 0.8, 0.2)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A poison dart shoots from the wall!")

	if triggerer != null and triggerer.has_method("take_damage"):
		@warning_ignore("integer_division")
		var damage: int = 2 + level.depth / 2
		triggerer.take_damage(damage, "poison dart")

	# Apply poison buff
	if triggerer != null and triggerer.has_method("add_buff"):
		var poison: Poison = Poison.create(3.0 + float(level.depth))
		triggerer.add_buff(poison)
