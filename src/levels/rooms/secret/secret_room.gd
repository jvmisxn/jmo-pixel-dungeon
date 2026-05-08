class_name SecretRoom
extends Room
## Secret room — hidden behind a secret door. Contains bonus loot.
## The player must search walls to discover the hidden entrance.

func _init() -> void:
	type = Type.SECRET

## Secret rooms can only have 1 connection (the secret door).
## Matches original SecretRoom.maxConnections(direction) = 1.
func max_connections(_direction: int = -1) -> int:
	return 1

func min_width() -> int:
	return 4

func min_height() -> int:
	return 4

func max_width() -> int:
	return 6

func max_height() -> int:
	return 6

func paint(level: Level) -> void:
	Painter.fill_room(level, self, ConstantsData.Terrain.WALL)
	Painter.fill_interior(level, self, ConstantsData.Terrain.EMPTY_SP)

	# Place a random reward layout
	var interior: Array[int] = interior_cells()
	if not interior.is_empty():
		# Pick a random interior cell for a special feature
		var reward_pos: int = interior[randi_range(0, interior.size() - 1)]
		var roll: float = randf()
		if roll < 0.3:
			# Pedestal with item
			level.set_terrain(reward_pos, ConstantsData.Terrain.PEDESTAL)
		elif roll < 0.5:
			# Well
			level.set_terrain(reward_pos, ConstantsData.Terrain.WELL)
		elif roll < 0.7:
			# Alchemy pot
			level.set_terrain(reward_pos, ConstantsData.Terrain.ALCHEMY)
		else:
			# Bookshelves with scrolls
			for pos: int in interior:
				if randf() < 0.4:
					level.set_terrain(pos, ConstantsData.Terrain.BOOKSHELF)

	# All doors to this room are secret doors
	for door_pos: int in connected.values():
		level.set_terrain(door_pos, ConstantsData.Terrain.SECRET_DOOR)
