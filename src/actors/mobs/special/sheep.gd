class_name Sheep
extends Mob
## Temporary passive sheep used by flock-style effects to block movement.

var turns_left: int = 8

func _init() -> void:
	super._init()
	mob_id = "sheep"
	mob_name = "Sheep"
	description = "A bewildered sheep conjured by magic. It mostly just gets in the way."
	setup(1, 0, 0, 0, 0, 0, 1.0)
	xp_value = 0
	max_level = 0
	awareness = 0.0
	aggro_range = 0
	state = AIState.PASSIVE

func act() -> void:
	if not is_alive:
		deactivate()
		return
	turns_left -= 1
	if turns_left <= 0:
		is_alive = false
		if level and level.has_method("remove_mob"):
			level.remove_mob(self)
		destroy()
		return
	spend_turn()

func take_damage(_dmg: int, _source: Variant = null) -> int:
	return 0

func _on_death(_source: Variant) -> void:
	if level and level.has_method("remove_mob"):
		level.remove_mob(self)
	destroy()

static func spawn_at(spawn_pos: int, p_level: Variant, duration_turns: int = 8) -> Sheep:
	var sheep: Sheep = Sheep.new()
	sheep.pos = spawn_pos
	sheep.level = p_level
	sheep.turns_left = duration_turns
	if p_level and p_level.has_method("add_mob"):
		p_level.add_mob(sheep)
	if TurnManager:
		TurnManager.add_actor(sheep)
	return sheep
