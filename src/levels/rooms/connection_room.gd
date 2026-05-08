class_name ConnectionRoom
extends Room
## Connection room — small rooms used as hallway junctions and tunnels
## between standard rooms. Mirrors Shattered PD's ConnectionRoom.java.

enum ConnectionType { TUNNEL, SMALL, STANDARD }

var connection_type: ConnectionType = ConnectionType.TUNNEL

func _init() -> void:
	type = Type.CONNECTION

# ---------------------------------------------------------------------------
# Size Requirements — connections are small
# ---------------------------------------------------------------------------

func min_width() -> int:
	match connection_type:
		ConnectionType.TUNNEL: return 3
		ConnectionType.SMALL: return 4
		ConnectionType.STANDARD: return 5
	return 3

func min_height() -> int:
	match connection_type:
		ConnectionType.TUNNEL: return 3
		ConnectionType.SMALL: return 4
		ConnectionType.STANDARD: return 5
	return 3

func max_width() -> int:
	match connection_type:
		ConnectionType.TUNNEL: return 3
		ConnectionType.SMALL: return 5
		ConnectionType.STANDARD: return 6
	return 3

func max_height() -> int:
	match connection_type:
		ConnectionType.TUNNEL: return 3
		ConnectionType.SMALL: return 5
		ConnectionType.STANDARD: return 6
	return 3

# ---------------------------------------------------------------------------
# Painting
# ---------------------------------------------------------------------------

func paint(level: Level) -> void:
	# Walls on border
	for pos: int in all_cells():
		level.set_terrain(pos, ConstantsData.Terrain.WALL)

	# Empty interior
	for pos: int in interior_cells():
		level.set_terrain(pos, ConstantsData.Terrain.EMPTY)

	# Place doors
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)

	painted = true

## Create a random connection room weighted toward tunnels.
static func create_random() -> ConnectionRoom:
	var room: ConnectionRoom = ConnectionRoom.new()
	var roll: float = randf()
	if roll < 0.5:
		room.connection_type = ConnectionType.TUNNEL
	elif roll < 0.8:
		room.connection_type = ConnectionType.SMALL
	else:
		room.connection_type = ConnectionType.STANDARD
	return room
