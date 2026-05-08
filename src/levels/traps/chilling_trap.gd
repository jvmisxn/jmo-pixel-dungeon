class_name ChillingTrap
extends Trap
## Applies Chill/Frozen debuff to the victim.

func _init() -> void:
	trap_name = "chilling trap"
	color = Color(0.4, 0.7, 1.0)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("Freezing air blasts from the floor!")

	# Apply frozen debuff
	if triggerer != null and triggerer.has_method("add_buff"):
		var freeze: Frozen = Frozen.new()
		@warning_ignore("integer_division")
		var dur: float = 3.0 + float(level.depth) / 2.0
		freeze.duration = dur
		freeze.time_left = dur
		triggerer.add_buff(freeze)

	# Deal cold damage
	if triggerer != null and triggerer.has_method("take_damage"):
		@warning_ignore("integer_division")
		var damage: int = 2 + level.depth / 2
		triggerer.take_damage(damage, "chilling trap")
