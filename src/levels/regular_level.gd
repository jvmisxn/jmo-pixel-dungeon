class_name RegularLevel
extends Level
## Standard procedural level using the builder + room + painter pipeline.
## Mirrors Shattered PD's RegularLevel.java.
##
## Generation steps:
## 1. Choose a level feeling
## 2. Create room list (entrance, exit, standards, connections, specials, secrets)
## 3. Use LoopBuilder to arrange rooms
## 4. Use StandardPainter to paint terrain
## 5. Place traps, items, mobs

# --- Configuration (can be overridden by region subclasses) ---

## Number of standard rooms to generate.
var num_standard_rooms: int = 6
## Number of connection rooms.
var num_connection_rooms: int = 3
## Number of special rooms (0-2 depending on depth).
var num_special_rooms: int = 1
## Number of secret rooms. Original defaults to 1 per floor via secretsForFloor().
var num_secret_rooms: int = 1

# ---------------------------------------------------------------------------
# Level Creation
# ---------------------------------------------------------------------------

func _build() -> bool:
	# Step 1: Choose feeling
	_roll_feeling()

	# Step 2: Create rooms
	var room_list: Array = _create_rooms()
	if room_list.size() < 2:
		return false

	# Step 3: Build layout
	var builder: LoopBuilder = LoopBuilder.new()
	var attempts: int = 0
	var layout_ok: bool = false

	while attempts < 15 and not layout_ok:
		# Reset rooms
		for r: Variant in room_list:
			var room: Room = r as Room
			room.connected.clear()
			room.neighbors.clear()
			room.painted = false

		# Re-init map
		_init_arrays()

		layout_ok = builder.build(room_list)
		attempts += 1

	if not layout_ok:
		return false

	rooms = room_list

	# Step 4: Paint
	StandardPainter.paint_level(self)

	# Step 5: Place traps
	_place_traps()

	# Step 6: Verify entrance and exit exist
	if entrance < 0 or exit_pos < 0:
		return false

	# Step 6.5: Validate that the floor is actually traversable from the
	# entrance to the stairs down. Some room/tunnel layouts can paint a valid
	# exit room but still leave it graph-disconnected, which softlocks the run.
	build_flag_maps()
	var exit_path: Array[int] = find_path(entrance, exit_pos)
	if exit_path.is_empty():
		return false

	# Step 7: Spawn mobs
	var num_mobs: int = mob_count()
	var mob_positions: Array[int] = mob_spawn_positions(num_mobs)
	for mob_pos: int in mob_positions:
		var mob: Mob = MobFactory.create_random_mob(depth)
		mob.pos = mob_pos
		mob.level = self
		add_mob(mob)

	# Original: clear high grass at mob positions so mobs aren't hidden at spawn
	for m: Node in mobs:
		if m is Mob:
			var m_pos: int = (m as Mob).pos
			if map[m_pos] == ConstantsData.Terrain.HIGH_GRASS or map[m_pos] == ConstantsData.Terrain.FURROWED_GRASS:
				map[m_pos] = ConstantsData.Terrain.GRASS
				if m_pos >= 0 and m_pos < LEN:
					los_blocking[m_pos] = false

	# Step 8: Spawn items with heap type distribution
	# Original: 14/20 HEAP, 1/20 SKELETON, 4/20 CHEST, 1/20 MIMIC
	var num_items: int = item_count()
	var item_positions: Array[int] = item_spawn_positions(num_items)
	for item_pos: int in item_positions:
		# Original: clear high grass at item positions
		if map[item_pos] == ConstantsData.Terrain.HIGH_GRASS or map[item_pos] == ConstantsData.Terrain.FURROWED_GRASS:
			map[item_pos] = ConstantsData.Terrain.GRASS
			if item_pos >= 0 and item_pos < LEN:
				los_blocking[item_pos] = false
		var item: Item = Generator.random_item(depth)
		var heap_roll: int = randi_range(0, 19)
		if heap_roll == 0:
			# SKELETON heap (5%)
			drop_item(item_pos, item, "skeleton")
		elif heap_roll >= 1 and heap_roll <= 4:
			# CHEST heap (20%)
			drop_item(item_pos, item, "chest")
		elif heap_roll == 5 and depth > 1 and mob_at(item_pos) == null:
			# MIMIC (5%) — spawn a mimic holding the item instead of dropping
			var mimic: Mob = MobFactory.create_mob("mimic")
			if mimic != null:
				mimic.pos = item_pos
				add_mob(mimic)
			else:
				drop_item(item_pos, item, "chest")
		else:
			# Regular HEAP (70%)
			drop_item(item_pos, item)

	return true

# ---------------------------------------------------------------------------
# Feeling
# ---------------------------------------------------------------------------

func _roll_feeling() -> void:
	var roll: float = randf()
	if roll < 0.15:
		feeling = Feeling.WATER
	elif roll < 0.25:
		feeling = Feeling.GRASS
	elif roll < 0.30:
		feeling = Feeling.DARK
	elif roll < 0.33:
		feeling = Feeling.LARGE
		num_standard_rooms += 2
		num_connection_rooms += 1
	elif roll < 0.36:
		feeling = Feeling.TRAPS
	elif roll < 0.38:
		feeling = Feeling.SECRETS
		num_secret_rooms += 1
	else:
		feeling = Feeling.NONE

# ---------------------------------------------------------------------------
# Room Creation
# ---------------------------------------------------------------------------

func _create_rooms() -> Array[Room]:
	var room_list: Array[Room] = []

	# Entrance room
	var entrance_r: EntranceRoom = EntranceRoom.new()
	room_list.append(entrance_r)

	# Exit room
	var exit_r: ExitRoom = ExitRoom.new()
	room_list.append(exit_r)

	# Standard rooms
	for _i: int in range(num_standard_rooms):
		room_list.append(StandardRoom.create_random())

	# Connection rooms
	for _i: int in range(num_connection_rooms):
		room_list.append(ConnectionRoom.create_random())

	# Guaranteed shop on shop floors (6, 11, 16, 21)
	# Matches original Dungeon.shopOnLevel() which adds ShopRoom in initRooms()
	if _is_shop_floor():
		room_list.append(ShopRoom.new())

	# Special rooms (subclasses can override _create_special_rooms)
	var specials: Array[Room] = _create_special_rooms()
	room_list.append_array(specials)

	# Secret rooms
	for _i: int in range(num_secret_rooms):
		var secret: Room = _create_secret_room()
		if secret != null:
			room_list.append(secret)

	return room_list

## Create special rooms appropriate for the current depth.
## Region subclasses can override for themed rooms.
func _create_special_rooms() -> Array[Room]:
	var result: Array[Room] = []
	# Pool of special room types (weighted by depth relevance)
	var pool: Array[String] = []
	# Gardens and pools available at any depth
	pool.append("garden")
	pool.append("pool")
	pool.append("magic_well")
	# Rot gardens from depth 3+
	if depth >= 3:
		pool.append("rot_garden")
	# Libraries available from depth 3+
	if depth >= 3:
		pool.append("library")
	# Trap rooms and weak floors from depth 4+
	if depth >= 4:
		pool.append("trap_room")
		pool.append("weak_floor")
	# Laboratories and statue rooms from depth 5+
	if depth >= 5:
		pool.append("laboratory")
		pool.append("statue")
	# Armories available from depth 7+
	if depth >= 7:
		pool.append("armory")
	# Pit rooms from depth 8+
	if depth >= 8:
		pool.append("pit")
	# Vaults and crystal vaults from depth 10+
	if depth >= 10:
		pool.append("vault")
		pool.append("crystal_vault")
	# Sacrifice rooms from depth 14+
	if depth >= 14:
		pool.append("sacrifice")

	# Filter out recently used room types to ensure variety across floors
	# Matches original SpecialRoom.initForFloor() rotation system
	pool = _filter_recent_specials(pool)

	pool.shuffle()
	var used_types: Array[String] = []
	for i: int in range(mini(num_special_rooms, pool.size())):
		var room: Room = _create_special_room_by_type(pool[i])
		if room != null:
			result.append(room)
			used_types.append(pool[i])
	# Record which room types we used for future rotation
	_record_special_rooms(used_types)
	return result

## Create a specific special room by type string.
func _create_special_room_by_type(room_type: String) -> Room:
	match room_type:
		"garden":
			return GardenRoom.new()
		"pool":
			return PoolRoom.new()
		"library":
			return LibraryRoom.new()
		"laboratory":
			return LaboratoryRoom.new()
		"armory":
			return ArmoryRoom.new()
		"vault":
			return VaultRoom.new()
		"trap_room":
			return TrapRoom.new()
		"sacrifice":
			return SacrificeRoom.new()
		"statue":
			return StatueRoom.new()
		"crystal_vault":
			return CrystalVaultRoom.new()
		"weak_floor":
			return WeakFloorRoom.new()
		"magic_well":
			return MagicWellRoom.new()
		"pit":
			return PitRoom.new()
		"rot_garden":
			return RotGardenRoom.new()
	return null

## Create a secret room (hidden room with a secret door).
func _create_secret_room() -> Room:
	var roll: float = randf()
	if roll < 0.25:
		return SecretGardenRoom.new()
	elif roll < 0.50:
		return SecretLibraryRoom.new()
	elif roll < 0.75:
		return SecretWellRoom.new()
	else:
		return SecretRoom.new()

# ---------------------------------------------------------------------------
# Trap Placement
# ---------------------------------------------------------------------------

func _place_traps() -> void:
	var num_traps: int = _trap_count()

	for _i: int in range(num_traps):
		var pos: int = random_passable_cell()
		if pos < 0:
			continue
		# Don't place traps on entrance/exit
		if pos == entrance or pos == exit_pos:
			continue
		# Don't place on doors
		if ConstantsData.terrain_is_door(terrain_at(pos)):
			continue

		var trap: Trap = _create_random_trap() as Trap
		if trap != null:
			place_trap(pos, trap)
			# Original: traps are hidden by default, revealed via detection
			set_terrain(pos, ConstantsData.Terrain.SECRET_TRAP)

## Number of traps based on depth and feeling.
## Original: NormalIntRange(2, 3 + depth/5) — bell curve between 2 and 3+depth/5.
func _trap_count() -> int:
	@warning_ignore("integer_division")
	var max_traps: int = 3 + depth / 5
	# Approximate NormalIntRange with triangular distribution (two rolls averaged)
	var base_count: int = (randi_range(2, max_traps) + randi_range(2, max_traps)) / 2
	if feeling == Feeling.TRAPS:
		base_count += 3
	return base_count

## Create a random trap appropriate for the depth. Override in region levels.
func _create_random_trap() -> Trap:
	# Fallback — region subclasses override with themed traps
	var roll: float = randf()
	if roll < 0.3:
		return WornDartTrap.new()
	elif roll < 0.55:
		return PoisonTrap.new()
	elif roll < 0.7:
		return FireTrap.new()
	elif roll < 0.85:
		return AlarmTrap.new()
	else:
		return TeleportTrap.new()

# ---------------------------------------------------------------------------
# Mob Placement (called externally after level is created)
# ---------------------------------------------------------------------------

## Returns how many mobs should be on this level initially.
## Matches original SPD: floor 1 always has 8 mobs (enough XP to reach level 2).
## Other floors: 3 + (depth % 5) + random 0-2, scaled 1.33x for LARGE feeling.
func mob_count() -> int:
	# Floor 1 always spawns 8 mobs so the player can reach level 2
	if depth <= 1:
		return 8
	var mob_total: int = 3 + (depth % 5) + randi_range(0, 2)
	if feeling == Feeling.LARGE:
		mob_total = ceili(mob_total * 1.33)
	return mob_total

## Returns positions suitable for mob spawning.
## Original: spawns mobs in weighted StandardRooms, avoiding entrance FOV + 8-tile walk.
## Also has 25% chance to spawn a second mob in the same room (except floor 1).
func mob_spawn_positions(count: int) -> Array[int]:
	# Build walkable distance map from entrance (BFS, max 8 steps).
	# Original uses BOTH FOV shadowcasting (range 8) AND walkable distance (8 steps).
	# A mob is excluded if it's visible from the entrance OR within 8 walkable steps.
	_build_entrance_distance_map(8)
	# Also build entrance FOV (shadowcasting range 8) to exclude visible cells
	_build_entrance_fov(8)

	# Build weighted room list (StandardRooms only, weight = sizeFactor)
	var std_rooms: Array[Room] = []
	for room: Room in rooms:
		if room is StandardRoom and not room is EntranceRoom:
			# Larger rooms get more mob weight
			var weight: int = maxi(1, room.width() * room.height() / 25)
			for _w: int in range(weight):
				std_rooms.append(room)
	if std_rooms.is_empty():
		# Fallback
		for _i: int in range(count):
			var pos: int = random_passable_cell()
			if pos >= 0 and not _near_entrance(pos):
				return [pos]
		return []

	std_rooms.shuffle()
	var room_idx: int = 0

	var positions: Array[int] = []
	var remaining: int = count
	while remaining > 0:
		if room_idx >= std_rooms.size():
			room_idx = 0
		var room: Room = std_rooms[room_idx]
		room_idx += 1
		# Pick a random passable cell within the room's interior
		var attempts: int = 10
		var placed: bool = false
		while attempts > 0:
			attempts -= 1
			var rx: int = randi_range(room.left + 1, room.right - 1)
			var ry: int = randi_range(room.top + 1, room.bottom - 1)
			var pos: int = ConstantsData.xy_to_pos(rx, ry)
			if pos >= 0 and pos < ConstantsData.LENGTH:
				if map[pos] != ConstantsData.Terrain.WALL and not _near_entrance(pos):
					if not positions.has(pos):
						positions.append(pos)
						placed = true
						break
		if not placed and positions.size() >= count / 2:
			# Give up on this mob to avoid infinite loop
			pass
		remaining -= 1
	return positions

# ---------------------------------------------------------------------------
# Entrance Distance Helpers
# ---------------------------------------------------------------------------

## BFS distance map from entrance, up to max_dist steps.
var _entrance_dist: Array[int] = []

func _build_entrance_distance_map(max_dist: int) -> void:
	_entrance_dist.resize(ConstantsData.LENGTH)
	_entrance_dist.fill(-1)
	if entrance < 0 or entrance >= ConstantsData.LENGTH:
		return
	var queue: Array[int] = [entrance]
	_entrance_dist[entrance] = 0
	while queue.size() > 0:
		var cur: int = queue.pop_front()
		var d: int = _entrance_dist[cur]
		if d >= max_dist:
			continue
		for dir: int in ConstantsData.DIRS_4:
			var next: int = cur + dir
			if next >= 0 and next < ConstantsData.LENGTH:
				if _entrance_dist[next] < 0 and map[next] != ConstantsData.Terrain.WALL:
					_entrance_dist[next] = d + 1
					queue.append(next)

## Entrance FOV (simplified — marks cells within direct line of sight from entrance).
var _entrance_fov: Array[bool] = []

func _build_entrance_fov(fov_range: int) -> void:
	_entrance_fov.resize(ConstantsData.LENGTH)
	_entrance_fov.fill(false)
	if entrance < 0 or entrance >= ConstantsData.LENGTH:
		return
	# Use distance map as a simplified FOV (cells within walkable range)
	for pos: int in range(ConstantsData.LENGTH):
		if _entrance_dist.size() > pos and _entrance_dist[pos] >= 0 and _entrance_dist[pos] <= fov_range:
			_entrance_fov[pos] = true

## Check if a position is too close to the entrance (within walkable distance or FOV).
func _near_entrance(pos: int) -> bool:
	if pos < 0 or pos >= ConstantsData.LENGTH:
		return true
	if _entrance_dist.size() > pos and _entrance_dist[pos] >= 0 and _entrance_dist[pos] <= 8:
		return true
	if _entrance_fov.size() > pos and _entrance_fov[pos]:
		return true
	return false

# ---------------------------------------------------------------------------
# Item Placement
# ---------------------------------------------------------------------------

## Number of items to place on this level.
## Original: 3 items per floor, +1 on LARGE levels.
func item_count() -> int:
	var count: int = 3
	if feeling == Feeling.LARGE:
		count += 1
	return count

## Returns positions suitable for item spawning. Avoids entrance/exit.
func item_spawn_positions(count: int) -> Array[int]:
	var positions: Array[int] = []
	var attempts: int = 0
	while positions.size() < count and attempts < count * 20:
		attempts += 1
		var p: int = random_passable_cell()
		if p < 0:
			continue
		if p == entrance or p == exit_pos:
			continue
		if positions.has(p):
			continue
		positions.append(p)
	return positions

# ---------------------------------------------------------------------------
# Shop Floor Check
# ---------------------------------------------------------------------------

## Returns true if this depth is a shop floor (6, 11, 16, 21).
## Matches original Dungeon.shopOnLevel().
func _is_shop_floor() -> bool:
	return depth in [6, 11, 16, 21]

# ---------------------------------------------------------------------------
# Special Room Rotation (prevents repeated room types across floors)
# ---------------------------------------------------------------------------

## Static tracker for recently used special room types (rotates every 3 floors).
static var _recent_specials: Array[String] = []

## Filter out recently used special room types to ensure variety.
func _filter_recent_specials(pool: Array[String]) -> Array[String]:
	var filtered: Array[String] = []
	for room_type: String in pool:
		if room_type not in _recent_specials:
			filtered.append(room_type)
	# If everything is filtered, return the original pool
	if filtered.is_empty():
		_recent_specials.clear()
		return pool
	return filtered

## Record which special room types were used on this floor.
func _record_special_rooms(used_types: Array[String]) -> void:
	_recent_specials.append_array(used_types)
	# Keep only the last 4 entries to allow rotation
	while _recent_specials.size() > 4:
		_recent_specials.remove_at(0)

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

## Serialize the full level state for caching / save-load.
func serialize() -> Dictionary:
	return super.serialize()

## Deserialize level state from cached data.
func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
