class_name WeakFloorRoom
extends Room
## Weak floor room — has hidden pitfall traps.
## Floor looks normal but stepping on specific tiles drops the hero down.
## Paints normally but places SECRET_TRAP on some interior cells.

func _init() -> void:
	type = Type.SPECIAL

## Special rooms have a single entrance.
## Matches original SpecialRoom.maxConnections() = 1.
func max_connections(_direction: int = -1) -> int:
	return 1

func min_width() -> int:
	return 6

func min_height() -> int:
	return 6

func max_width() -> int:
	return 8

func max_height() -> int:
	return 8

func paint(level: Level) -> void:
	Painter.fill_room(level, self, ConstantsData.Terrain.WALL)
	Painter.fill_interior(level, self, ConstantsData.Terrain.EMPTY)

	# Place hidden traps on interior cells, leaving a safe path near doors
	var interior: Array[int] = interior_cells()
	for pos: int in interior:
		if pos == center():
			continue  # Keep center safe
		# Don't trap cells adjacent to doors
		var near_door: bool = false
		for other: Variant in connected:
			var door_pos: int = connected[other]
			if door_pos >= 0:
				var dx: int = absi((pos % ConstantsData.WIDTH) - (door_pos % ConstantsData.WIDTH))
				var dy: int = absi((pos / ConstantsData.WIDTH) - (door_pos / ConstantsData.WIDTH))
				if dx <= 1 and dy <= 1:
					near_door = true
					break
		if not near_door and randf() < 0.45:
			level.set_terrain(pos, ConstantsData.Terrain.SECRET_TRAP)

	# Place doors
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)

	painted = true
