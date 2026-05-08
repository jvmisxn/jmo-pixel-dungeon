class_name ParalyticTrap
extends Trap
## Releases paralytic gas that paralyzes the triggerer and nearby characters.

func _init() -> void:
	trap_name = "paralytic gas trap"
	color = Color(0.8, 0.8, 0.1)

func _do_effect(triggerer: Variant, _level: Level) -> void:
	if MessageLog:
		MessageLog.add("A cloud of paralytic gas fills the air!")

	# Apply paralysis buff to triggerer
	if triggerer != null and triggerer.has_method("add_buff"):
		pass

	# Also affect anyone in adjacent cells
	# (handled by blob system in Phase 2)
