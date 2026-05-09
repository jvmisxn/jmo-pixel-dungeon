class_name StandardPainter
extends Painter
## Paints all rooms in a level using their own paint() methods,
## then carves tunnels between rooms that need them, and applies
## region-specific decorations.

# ---------------------------------------------------------------------------
# Main Paint Entry Point
# ---------------------------------------------------------------------------

## Paint the entire level: rooms, tunnels, decorations.
static func paint_level(level: Level) -> void:
	# Step 1: Paint each room
	for room_ref: Variant in level.rooms:
		var room: Room = room_ref as Room
		if room != null and not room.painted:
			room.paint(level)

	# Step 2: Carve tunnels between rooms that are neighbors but not directly connected
	_carve_tunnels(level)

	# Step 3: Apply wall decorations
	_decorate_walls(level)

	# Step 4: Apply region-specific water/grass patches based on feeling
	_apply_feeling(level)

	# Step 5: Rebuild passable/vision caches
	level.build_flag_maps()

# ---------------------------------------------------------------------------
# Tunnel Carving
# ---------------------------------------------------------------------------

static func _carve_tunnels(level: Level) -> void:
	var carved: Dictionary[int, bool] = {}  # Track which pairs we've already tunneled

	for room: Room in level.rooms:
		if room == null:
			continue
		for neighbor_ref: Room in room.neighbors:
			var neighbor: Room = neighbor_ref as Room
			if neighbor == null:
				continue
			# Skip if already connected with a door
			if room.is_connected_to(neighbor):
				continue
			# Skip if we already carved this pair
			var pair_key: int = mini(room.get_instance_id(), neighbor.get_instance_id()) * 100000 + maxi(room.get_instance_id(), neighbor.get_instance_id())
			if carved.has(pair_key):
				continue
			carved[pair_key] = true

			# Find good tunnel endpoints
			var from_pos: int = _tunnel_endpoint(room, neighbor)
			var to_pos: int = _tunnel_endpoint(neighbor, room)

			Builder.build_tunnel(level, from_pos, to_pos)

			# NOTE: Doors are placed by each Room's paint() method using its
			# `connected` dictionary. The tunnel just carves empty space between
			# rooms. Do NOT place extra doors here — doing so creates orphan
			# doors in walls that lead nowhere.

## Check if the position forms a valid doorframe — walls on two opposite sides
## (N+S or E+W). A door with open space on 3 sides is pointless.
static func _is_valid_doorframe(level: Level, pos: int) -> bool:
	var n: int = pos + ConstantsData.DIR_N
	var s: int = pos + ConstantsData.DIR_S
	var e: int = pos + ConstantsData.DIR_E
	var w: int = pos + ConstantsData.DIR_W
	var n_wall: bool = (n >= 0 and n < Level.LEN and _is_solid(level.map[n]))
	var s_wall: bool = (s >= 0 and s < Level.LEN and _is_solid(level.map[s]))
	var e_wall: bool = (e >= 0 and e < Level.LEN and _is_solid(level.map[e]))
	var w_wall: bool = (w >= 0 and w < Level.LEN and _is_solid(level.map[w]))
	# Valid doorframe: walls on opposite sides forming a passage
	return (n_wall and s_wall) or (e_wall and w_wall)


## Check if a terrain type is solid (wall-like) for doorframe validation.
static func _is_solid(terrain: int) -> bool:
	return terrain == ConstantsData.Terrain.WALL or terrain == ConstantsData.Terrain.WALL_DECO or terrain == ConstantsData.Terrain.SECRET_DOOR or terrain == ConstantsData.Terrain.BARRICADE


## Check if any cardinal neighbor of pos is already a door.
static func _has_adjacent_door(level: Level, pos: int) -> bool:
	for dir: int in ConstantsData.DIRS_4:
		var n: int = pos + dir
		if n >= 0 and n < Level.LEN:
			var t: int = level.map[n]
			if t == ConstantsData.Terrain.DOOR or t == ConstantsData.Terrain.OPEN_DOOR or t == ConstantsData.Terrain.LOCKED_DOOR:
				return true
	return false


## Find the best point on the border of [room] facing [target].
static func _tunnel_endpoint(room: Room, target: Room) -> int:
	var tcx: int = target.center_x()
	var tcy: int = target.center_y()
	var rcx: int = room.center_x()
	var rcy: int = room.center_y()

	# Determine which side of the room faces the target
	var dx: int = tcx - rcx
	var dy: int = tcy - rcy

	if absi(dx) > absi(dy):
		# Target is primarily to the left or right
		var wall_x: int = room.right if dx > 0 else room.left
		var best_y: int = clampi(tcy, room.top + 1, room.bottom - 1)
		return best_y * ConstantsData.WIDTH + wall_x
	else:
		# Target is primarily above or below
		var wall_y: int = room.bottom if dy > 0 else room.top
		var best_x: int = clampi(tcx, room.left + 1, room.right - 1)
		return wall_y * ConstantsData.WIDTH + best_x

# ---------------------------------------------------------------------------
# Wall Decoration
# ---------------------------------------------------------------------------

static func _decorate_walls(level: Level) -> void:
	for i: int in range(Level.LEN):
		if level.map[i] == ConstantsData.Terrain.WALL:
			# Check if this wall is adjacent to a floor tile — if so, it's visible
			# and gets a chance to be decorated
			var has_floor_neighbor: bool = false
			for dir: int in ConstantsData.DIRS_4:
				var n: int = i + dir
				if n >= 0 and n < Level.LEN:
					var t: int = level.map[n]
					if t != ConstantsData.Terrain.WALL and t != ConstantsData.Terrain.CHASM:
						has_floor_neighbor = true
						break
			if has_floor_neighbor and randf() < 0.15:
				level.map[i] = ConstantsData.Terrain.WALL_DECO

# ---------------------------------------------------------------------------
# Level Feeling Effects
# ---------------------------------------------------------------------------

## Apply water/grass patches based on the level's feeling.
static func _apply_feeling(level: Level) -> void:
	if level.feeling == Level.Feeling.NONE:
		return

	var target_terrain: int = ConstantsData.Terrain.EMPTY
	var fill_chance: float = 0.0

	match level.feeling:
		Level.Feeling.WATER:
			target_terrain = ConstantsData.Terrain.WATER
			fill_chance = 0.20
		Level.Feeling.GRASS:
			target_terrain = ConstantsData.Terrain.HIGH_GRASS
			fill_chance = 0.15
		Level.Feeling.DARK:
			# Dark feeling doesn't change terrain, handled by fog of war
			return

	for i: int in range(Level.LEN):
		if level.map[i] == ConstantsData.Terrain.EMPTY and randf() < fill_chance:
			level.map[i] = target_terrain
