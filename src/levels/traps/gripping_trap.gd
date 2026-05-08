class_name GrippingTrap
extends Trap
## Roots the triggerer in place and deals minor damage.

func _init() -> void:
	trap_name = "gripping trap"
	color = Color(0.6, 0.4, 0.2)
	one_shot = false  # Gripping traps persist

func _do_effect(triggerer: Variant, _level: Level) -> void:
	if MessageLog:
		MessageLog.add("A trap grips your feet!")

	if triggerer != null and triggerer.has_method("take_damage"):
		triggerer.take_damage(1, "gripping trap")

	# Apply rooted buff
	if triggerer != null and triggerer.has_method("add_buff"):
		var rooted: Rooted = Rooted.new()
		rooted.set_duration(5.0)
		triggerer.add_buff(rooted)
