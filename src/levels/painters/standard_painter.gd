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
	var carved: Dictionary[String, bool] = {}  # Track which pairs we've already tunneled

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
			var pair_key: String = _room_pair_key(room, neighbor)
			if carved.has(pair_key):
				continue
			carved[pair_key] = true

			# Find good tunnel endpoints
			var from_pos: int = _tunnel_endpoint(room, neighbor)
			var to_pos: int = _tunnel_endpoint(neighbor, room)

			Builder.build_tunnel(level, from_pos, to_pos)

			_place_tunnel_door(level, room, from_pos)
			_place_tunnel_door(level, neighbor, to_pos)


static func _room_pair_key(a: Room, b: Room) -> String:
	var a_id: int = a.get_instance_id()
	var b_id: int = b.get_instance_id()
	return "%d:%d" % [mini(a_id, b_id), maxi(a_id, b_id)]


static func _place_tunnel_door(level: Level, room: Room, pos: int) -> void:
	if pos < 0 or pos >= Level.LEN:
		return
	if _has_adjacent_door(level, pos):
		return
	var terrain: int = _tunnel_door_terrain(room)
	if terrain < 0:
		return
	if not _is_valid_doorframe(level, pos):
		return
	level.set_terrain(pos, terrain)


static func _tunnel_door_terrain(room: Room) -> int:
	if room.type == Room.Type.SECRET:
		return ConstantsData.Terrain.SECRET_DOOR
	if room is CrystalVaultRoom:
		return ConstantsData.Terrain.CRYSTAL_DOOR
	if room is VaultRoom or room is ArmoryRoom:
		return ConstantsData.Terrain.LOCKED_DOOR
	return ConstantsData.Terrain.DOOR

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
	var water_params: Dictionary = _water_params(level)
	var water_fill: float = water_params.get("fill", 0.0)
	var water_smoothness: int = water_params.get("smoothness", 0)
	if water_fill > 0.0:
		_paint_water_patches(level, water_fill, water_smoothness)

	match level.feeling:
		Level.Feeling.GRASS:
			for i: int in range(Level.LEN):
				if level.map[i] != ConstantsData.Terrain.EMPTY:
					continue
				if not _grass_allowed(level, i):
					continue
				var roll: float = randf()
				if roll < 0.12:
					level.map[i] = ConstantsData.Terrain.GRASS
				elif roll < 0.18:
					level.map[i] = ConstantsData.Terrain.HIGH_GRASS
		Level.Feeling.DARK, Level.Feeling.NONE, Level.Feeling.WATER:
			# Dark doesn't change terrain directly. Water is handled by region-style patch painting.
			return


## True unless a room containing this cell forbids grass (upstream canPlaceGrass).
static func _grass_allowed(level: Level, pos: int) -> bool:
	for room_ref: Variant in level.rooms:
		var room: Room = room_ref as Room
		if room != null and room.inside(pos) and not room.can_place_grass(pos):
			return false
	return true


static func _water_params(level: Level) -> Dictionary:
	if level is SewerLevel:
		return {
			"fill": 0.85 if level.feeling == Level.Feeling.WATER else 0.30,
			"smoothness": 5,
		}
	if level is CavesLevel:
		return {
			"fill": 0.85 if level.feeling == Level.Feeling.WATER else 0.30,
			"smoothness": 6,
		}
	if level is CityLevel:
		return {
			"fill": 0.90 if level.feeling == Level.Feeling.WATER else 0.30,
			"smoothness": 4,
		}
	return {}


static func _paint_water_patches(level: Level, fill: float, smoothness: int) -> void:
	var patch: Array[bool] = _generate_patch(ConstantsData.WIDTH, ConstantsData.HEIGHT, fill, smoothness)
	for room_ref: Variant in level.rooms:
		var room: Room = room_ref as Room
		if room == null:
			continue
		for pos: int in room.interior_cells():
			if patch[pos] and level.map[pos] == ConstantsData.Terrain.EMPTY \
					and room.can_place_water(pos):
				level.map[pos] = ConstantsData.Terrain.WATER


static func _generate_patch(width: int, height: int, fill: float, smoothness: int) -> Array[bool]:
	var patch: Array[bool] = []
	patch.resize(width * height)

	for y: int in range(height):
		for x: int in range(width):
			var pos: int = y * width + x
			var on_edge: bool = x == 0 or y == 0 or x == width - 1 or y == height - 1
			patch[pos] = false if on_edge else randf() < fill

	for _step: int in range(smoothness):
		var next_patch: Array[bool] = []
		next_patch.resize(width * height)
		for y: int in range(height):
			for x: int in range(width):
				var pos: int = y * width + x
				if x == 0 or y == 0 or x == width - 1 or y == height - 1:
					next_patch[pos] = false
					continue
				var neighbors: int = 0
				for oy: int in range(-1, 2):
					for ox: int in range(-1, 2):
						if ox == 0 and oy == 0:
							continue
						var npos: int = (y + oy) * width + (x + ox)
						if patch[npos]:
							neighbors += 1
				next_patch[pos] = neighbors >= 4
		patch = next_patch

	return patch
