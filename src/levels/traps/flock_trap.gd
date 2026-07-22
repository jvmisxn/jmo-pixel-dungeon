class_name FlockTrap
extends Trap
## Spawns several sheep (passive mobs) that block movement.

func _init() -> void:
	trap_name = "flock trap"
	color = Color(0.9, 0.9, 0.9)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A flock of magical sheep appears!")

	# Spawn sheep in adjacent passable cells
	var spawn_cells: Array[int] = []
	for dir: int in ConstantsData.DIRS_8:
		var adj: int = pos + dir
		if level.adjacent(pos, adj) and level.is_passable(adj):
			if level.mob_at(adj) == null:
				spawn_cells.append(adj)

	# Spawn 3-5 sheep
	var num_sheep: int = mini(randi_range(3, 5), spawn_cells.size())
	spawn_cells.shuffle()

	for i: int in range(num_sheep):
		var cell: int = spawn_cells[i]
		# Sheep mob spawning handled by the actor system
		# For now, place a passive blocker marker
		if level.has_method("spawn_mob"):
			level.spawn_mob("sheep", cell)
