class_name ParalyticTrap
extends Trap
## Releases paralytic gas that paralyzes the triggerer and nearby characters.

func _init() -> void:
	trap_name = "paralytic gas trap"
	color = Color(0.8, 0.8, 0.1)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A cloud of paralytic gas fills the air!")

	if level != null:
		level.add_blob(ParalyticGas.new(), pos, 5.0)
