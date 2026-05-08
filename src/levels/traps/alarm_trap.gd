class_name AlarmTrap
extends Trap
## Alerts all mobs on the level to the triggerer's position.

func _init() -> void:
	trap_name = "alarm trap"
	color = Color(1.0, 1.0, 0.2)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("An alarm sounds!")

	# Wake up and alert all mobs on the level
	for mob: Variant in level.mobs:
		if mob != null and mob.has_method("alert"):
			mob.alert()
		elif mob != null and mob.has_method("set_state"):
			mob.set_mob_state("hunting")
