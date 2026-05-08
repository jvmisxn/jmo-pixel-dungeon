class_name SummoningTrap
extends Trap
## Summons hostile mobs near the triggerer.

func _init() -> void:
	trap_name = "summoning trap"
	color = Color(0.7, 0.2, 0.9)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("The trap releases a summoning pulse!")

	# Summon 2-3 mobs near the trap position
	var num_summons: int = randi_range(2, 3)
	var spawn_positions: Array[int] = []

	for dir: int in ConstantsData.DIRS_8:
		var adj: int = pos + dir
		if adj >= 0 and adj < Level.LEN and level.is_passable(adj):
			if level.mob_at(adj) == null:
				spawn_positions.append(adj)

	# Mob spawning will be handled by the actor system in Phase 2
	# For now, log the positions
	var _to_spawn: int = mini(num_summons, spawn_positions.size())
