class_name AlarmTrap
extends Trap
## Alerts all mobs on the level to the triggerer's position.

func _init() -> void:
	trap_name = "alarm trap"
	color = Color(1.0, 1.0, 0.2)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("An alarm sounds!")

	var alert_pos: int = _triggerer.pos if _triggerer != null and _triggerer.get("pos") != null else -1
	if level.has_method("alert_all_mobs"):
		level.alert_all_mobs(alert_pos)
