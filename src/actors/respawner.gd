class_name Respawner
extends Actor
## Level-owned scheduler actor for regular-floor replacement mobs.

const TIME_TO_RESPAWN: float = 50.0

func _init() -> void:
	super._init()

func act() -> void:
	var level_ref: Variant = level
	if level_ref != null and level_ref.has_method("respawn_mob_if_needed"):
		level_ref.respawn_mob_if_needed()
	spend_turn(TIME_TO_RESPAWN)
