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

	var to_spawn: int = mini(num_summons, spawn_positions.size())
	if to_spawn <= 0:
		return
	spawn_positions.shuffle()
	for i: int in range(to_spawn):
		var spawn_pos: int = spawn_positions[i]
		var mob: Variant = MobFactory.create_random_mob(level.depth) if MobFactory else null
		if mob == null:
			continue
		mob.pos = spawn_pos
		mob.level = level
		if mob.has_method("scale_to_depth"):
			mob.scale_to_depth(level.depth)
		level.add_mob(mob)
		if TurnManager:
			TurnManager.add_actor(mob)
