class_name GuardianTrap
extends Trap
## Summons a guardian mob to protect the area.

func _init() -> void:
	trap_name = "guardian trap"
	color = Color(0.4, 0.6, 0.8)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A guardian materializes!")

	# Find a valid spawn position adjacent to the trap
	var spawn_pos: int = -1
	var candidates: Array[int] = []

	for dir: int in ConstantsData.DIRS_8:
		var adj: int = pos + dir
		if adj >= 0 and adj < Level.LEN and level.is_passable(adj):
			if level.mob_at(adj) == null:
				candidates.append(adj)

	if candidates.is_empty():
		# Try the trap position itself
		if level.mob_at(pos) == null:
			spawn_pos = pos
		else:
			if MessageLog:
				MessageLog.add("The guardian fails to materialize.")
			return
	else:
		spawn_pos = candidates[randi() % candidates.size()]

	# Spawn guardian mob via the level's spawn system
	if level.has_method("spawn_mob"):
		level.spawn_mob("guardian", spawn_pos)
