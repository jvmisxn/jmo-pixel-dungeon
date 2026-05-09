class_name Level
extends RefCounted
## Base Level class for all dungeon levels.
## Holds tile data, visibility state, items, mobs, and provides FOV updates.
## Mirrors Shattered PD's Level.java.

# --- Signals (emitted via EventBus instead, since RefCounted can't use signals easily) ---

# --- Constants ---
const W: int = 32  # alias for ConstantsData.WIDTH
const H: int = 32
const LEN: int = W * H

# --- Tile Data ---
## The terrain map — flat array of ConstantsData.Terrain values.
var map: Array[int] = []
## Which cells have been visited (stepped on or adjacent to hero).
var visited: Array[bool] = []
## Which cells have been revealed by magic mapping / scroll.
var mapped: Array[bool] = []
## Which cells are currently visible (recomputed each hero move).
var visible: Array[bool] = []
## Passable cache — updated from map when terrain changes.
var passable: Array[bool] = []
## Vision-blocking cache — updated from map when terrain changes.
var los_blocking: Array[bool] = []
## Discoverable cells — true for any cell adjacent to a non-wall cell.
## Used by the sense range (blinded heroes, MagicalSight) to determine what
## can be sensed. Matches original Level.discoverable[] computed in cleanWalls().
var discoverable: Array[bool] = []

# --- Godot AStar2D pathfinding graph (C++ optimized) ---
var astar: AStar2D = AStar2D.new()
var _astar_built: bool = false

# --- Positions ---
var entrance: int = -1
var exit_pos: int = -1  # "exit" is a GDScript keyword-adjacent, use exit_pos

# --- Depth ---
var depth: int = 1

# --- Entity Lists ---
## Items on the ground. Each entry: { "pos": int, "item": Variant }
var heaps: Array[Dictionary] = []
## Mob references. Populated by the actor system.
var mobs: Array[Node] = []
## Active blobs (gas clouds, fire, etc.). Each: { "pos": int, "blob": Variant }
var blobs: Array[Dictionary] = []
## Armed bombs waiting to detonate. Each entry:
## { "pos": int, "bomb": Variant, "turns_left": int }
var pending_bombs: Array[Dictionary] = []
## Traps placed on the level. Key: pos (int) -> trap object.
var traps: Dictionary[int, RefCounted] = {}
## Plants placed on the level. Key: pos (int) -> plant object.
var plants: Dictionary[int, RefCounted] = {}

# --- Room data (set by level generators) ---
var rooms: Array[Room] = []

# --- Feeling ---
enum Feeling { NONE, CHASM, WATER, GRASS, DARK, LARGE, TRAPS, SECRETS }
var feeling: Feeling = Feeling.NONE

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func _init() -> void:
	_init_arrays()

## Generate the level for the given depth. Called by LevelFactory.
func create(p_depth: int) -> bool:
	depth = p_depth
	var success: bool = _build()
	if success:
		build_flag_maps()
	return success

## Override in subclasses to generate level content.
func _build() -> bool:
	return true

func _init_arrays() -> void:
	map.resize(LEN)
	map.fill(ConstantsData.Terrain.WALL)
	visited.resize(LEN)
	visited.fill(false)
	mapped.resize(LEN)
	mapped.fill(false)
	visible.resize(LEN)
	visible.fill(false)
	passable.resize(LEN)
	passable.fill(false)
	los_blocking.resize(LEN)
	los_blocking.fill(true)
	discoverable.resize(LEN)
	discoverable.fill(false)

## Call after map generation or terrain changes to rebuild passable/los caches.
## Also forces border cells (first/last row, first/last column) to be
## impassable and LOS-blocking, matching original Level.buildFlagMaps().
func build_flag_maps() -> void:
	for i: int in range(LEN):
		var t: int = map[i]
		passable[i] = ConstantsData.terrain_is_passable(t)
		los_blocking[i] = ConstantsData.terrain_blocks_vision(t)
	# Force borders impassable/blocking (original clamps edges to prevent
	# pathfinding or vision through map boundaries).
	var last_row: int = LEN - W
	for i: int in range(W):
		passable[i] = false
		los_blocking[i] = true
		passable[last_row + i] = false
		los_blocking[last_row + i] = true
	for i: int in range(W, last_row, W):
		passable[i] = false
		los_blocking[i] = true
		passable[i + W - 1] = false
		los_blocking[i + W - 1] = true
	# Compute discoverable (original Level.cleanWalls())
	_clean_walls()
	# Build AStar2D graph from passable data (C++ pathfinding)
	_build_astar()
	_astar_built = true


## Build the AStar2D graph from the passable[] array.
## Uses Godot's C++ pathfinding engine — far faster than GDScript BFS/A*.
func _build_astar() -> void:
	astar.clear()
	astar.reserve_space(LEN)
	# Add all points; disable impassable ones
	for i: int in range(LEN):
		var x: int = i % W
		@warning_ignore("integer_division")
		var y: int = i / W
		astar.add_point(i, Vector2(x, y))
		if not passable[i]:
			astar.set_point_disabled(i, true)
	# Connect 8-directional neighbors (only right/down/diags to avoid duplicates)
	for i: int in range(LEN):
		if not passable[i]:
			continue
		var x: int = i % W
		@warning_ignore("integer_division")
		var y: int = i / W
		for d: Array in [[1, 0], [0, 1], [1, 1], [1, -1]]:
			var nx: int = x + d[0]
			var ny: int = y + d[1]
			if nx < 0 or nx >= W or ny < 0 or ny >= H:
				continue
			var ni: int = ny * W + nx
			if not passable[ni]:
				continue
			# Diagonal: prevent corner-cutting through walls
			if d[0] != 0 and d[1] != 0:
				var adj_h: int = y * W + nx
				var adj_v: int = ny * W + x
				if not passable[adj_h] or not passable[adj_v]:
					continue
			astar.connect_points(i, ni)


## Update a single cell in the AStar2D graph after terrain changes.
## Skipped during level generation — _build_astar() creates the full graph afterwards.
func _update_astar_cell(cell_pos: int) -> void:
	if not _astar_built or cell_pos < 0 or cell_pos >= LEN:
		return
	astar.set_point_disabled(cell_pos, not passable[cell_pos])
	# Rebuild connections for this cell and immediate neighbors
	var cx: int = cell_pos % W
	@warning_ignore("integer_division")
	var cy: int = cell_pos / W
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var nx: int = cx + dx
			var ny: int = cy + dy
			if nx < 0 or nx >= W or ny < 0 or ny >= H:
				continue
			var ni: int = ny * W + nx
			if not passable[ni]:
				continue
			# Check each neighbor pair for ni
			for d2y: int in range(-1, 2):
				for d2x: int in range(-1, 2):
					if d2x == 0 and d2y == 0:
						continue
					var nnx: int = nx + d2x
					var nny: int = ny + d2y
					if nnx < 0 or nnx >= W or nny < 0 or nny >= H:
						continue
					var nni: int = nny * W + nnx
					var should_connect: bool = passable[ni] and passable[nni]
					if d2x != 0 and d2y != 0 and should_connect:
						var adj_h: int = ny * W + nnx
						var adj_v: int = nny * W + nx
						if not passable[adj_h] or not passable[adj_v]:
							should_connect = false
					if should_connect:
						if not astar.are_points_connected(ni, nni):
							astar.connect_points(ni, nni)
					else:
						if astar.are_points_connected(ni, nni):
							astar.disconnect_points(ni, nni)


## Compute discoverable[] — a cell is discoverable if any of its 9 neighbors
## (including itself) is a non-wall cell. This allows blinded/sensed heroes
## to "feel" room edges. Matches original Level.cleanWalls().
func _clean_walls() -> void:
	discoverable.resize(LEN)
	for i: int in range(LEN):
		var d: bool = false
		for j: int in range(ConstantsData.DIRS_8.size()):
			var n: int = i + ConstantsData.DIRS_8[j]
			if n >= 0 and n < LEN and map[n] != ConstantsData.Terrain.WALL and map[n] != ConstantsData.Terrain.WALL_DECO:
				d = true
				break
		# Also check the cell itself (neighbours9 includes self)
		if not d and map[i] != ConstantsData.Terrain.WALL and map[i] != ConstantsData.Terrain.WALL_DECO:
			d = true
		discoverable[i] = d

# ---------------------------------------------------------------------------
# FOV
# ---------------------------------------------------------------------------

## Recompute visibility from a position (usually the hero's pos).
## view_dist overrides the default VIEW_DISTANCE (e.g. Huntress +2).
## Handles Blindness/Shadows (no shadowcasting, sense-only), MindVision
## (overlay mob neighborhoods through walls), Warden grass vision, and
## SmokeScreen LOS blocking — matching original Level.updateFieldOfView().
func update_fov(hero_pos: int, view_dist: int = -1) -> void:
	if view_dist < 0:
		view_dist = ConstantsData.VIEW_DISTANCE

	var hero: Variant = GameManager.hero if GameManager else null

	# Sighted check: original checks Blindness AND Shadows AND isAlive
	var sighted: bool = view_dist > 0
	if sighted and hero != null and hero.has_method("has_buff"):
		if hero.has_buff("Shadows"):
			sighted = false

	if sighted:
		# Build a potentially modified blocking array
		var blocking: Array[bool] = los_blocking

		# Warden see-through-grass: original strips HIGH_GRASS and FURROWED_GRASS
		# from the blocking array for Warden subclass
		var need_modified_blocking: bool = false
		if hero != null and hero.get("sub_class") == "WARDEN":
			need_modified_blocking = true
		# SmokeScreen blob LOS blocking: adds smoke cells as blocking
		var has_smoke: bool = false
		for blob_entry: Dictionary in blobs:
			var b: Variant = blob_entry.get("blob")
			if b != null and b.get("blob_id") == "smoke_screen":
				has_smoke = true
				need_modified_blocking = true
				break

		if need_modified_blocking:
			blocking = los_blocking.duplicate()
			# Warden: remove grass blocking
			if hero != null and hero.get("sub_class") == "WARDEN":
				for i: int in range(blocking.size()):
					if blocking[i] and (map[i] == ConstantsData.Terrain.HIGH_GRASS or map[i] == ConstantsData.Terrain.FURROWED_GRASS):
						blocking[i] = false
			# SmokeScreen: add smoke cells as blocking (only for non-ally characters)
			if has_smoke:
				for blob_entry: Dictionary in blobs:
					var b: Variant = blob_entry.get("blob")
					if b != null and b.get("blob_id") == "smoke_screen":
						var smoke_pos: int = blob_entry.get("pos", -1)
						if smoke_pos >= 0 and smoke_pos < LEN and not blocking[smoke_pos]:
							blocking[smoke_pos] = true

		visible = ShadowCaster.cast_fov(hero_pos, blocking, W, view_dist)
	else:
		# Blinded/Shadowed: no shadowcasting vision at all
		visible.resize(LEN)
		visible.fill(false)
		if hero_pos >= 0 and hero_pos < LEN:
			visible[hero_pos] = true

	# Sense range: determines what a blinded/enhanced hero can perceive.
	# Original uses ShadowCaster.rounding for circular shape and discoverable[].
	var sense: int = 1
	if hero != null and hero.has_method("has_buff"):
		if hero.has_buff("MagicalSight"):
			sense = maxi(sense, 8)  # MagicalSight.DISTANCE = 8

	# Use rounding table for circular sense range (matches original)
	if not sighted or sense > 1:
		ShadowCaster._init_rounding()
		var hx: int = hero_pos % W
		var hy: int = hero_pos / W
		# Clamp sense to ShadowCaster.MAX_DISTANCE
		var s: int = mini(sense, ShadowCaster.MAX_DISTANCE)
		var rounding: Array = ShadowCaster._rounding

		for y_pos: int in range(maxi(0, hy - s), mini(H - 1, hy + s) + 1):
			var abs_dy: int = absi(hy - y_pos)
			var left: int
			var right: int
			# Use the rounding table to compute the circular left/right extent
			if s > 0 and abs_dy <= s:
				var round_at_s: Array = rounding[s]
				if round_at_s[abs_dy] < abs_dy:
					left = hx - round_at_s[abs_dy]
				else:
					var l: int = s
					while l > 0 and round_at_s[l] < round_at_s[abs_dy]:
						l -= 1
					left = hx - l
				right = mini(W - 1, hx + hx - left)
				left = maxi(0, left)
			else:
				continue
			# Copy discoverable cells into visible in this row
			var pos: int = left + y_pos * W
			for _x: int in range(left, right + 1):
				if pos >= 0 and pos < LEN and discoverable[pos]:
					visible[pos] = true
				pos += 1

	# --- MindVision & Awareness (hero-only) ---
	# Original composites into heroMindFov then merges into fieldOfView.
	if hero != null and hero.has_method("has_buff") and hero.get("is_alive") == true:
		if hero.has_buff("MindVision"):
			for mob: Variant in mobs:
				if mob is Object and mob.get("is_alive") == true:
					var mob_pos: int = mob.get("pos")
					if mob_pos >= 0 and mob_pos < LEN:
						# Reveal the mob and its 8 neighbors (NEIGHBOURS9)
						for dir: int in ConstantsData.DIRS_8:
							var n: int = mob_pos + dir
							if n >= 0 and n < LEN:
								visible[n] = true
						visible[mob_pos] = true

		# Awareness buff: reveal heap neighborhoods (original Awareness buff)
		if hero.has_buff("Awareness"):
			for heap: Dictionary in heaps:
				var hp: int = heap.get("pos", -1)
				if hp >= 0 and hp < LEN:
					for dir: int in ConstantsData.DIRS_8:
						var n: int = hp + dir
						if n >= 0 and n < LEN:
							visible[n] = true
					visible[hp] = true

	# Reveal walls adjacent to any visible non-wall cell so room boundaries
	# render cleanly.
	_reveal_adjacent_walls()
	# Mark newly visible NON-WALL cells as visited.
	for i: int in range(LEN):
		if visible[i] and not los_blocking[i]:
			visited[i] = true
	# Now mark walls as visited only if they border a visited floor cell.
	_update_wall_visited()

	# Track heap visibility (original marks heap.seen when entering FOV)
	for heap: Dictionary in heaps:
		var hp: int = heap.get("pos", -1)
		if hp >= 0 and hp < LEN and visible[hp]:
			heap["seen"] = true

## Walls adjacent to a visible non-wall cell are also marked visible.
## Without this, room edges look jagged and walls disappear into fog.
func _reveal_adjacent_walls() -> void:
	# Collect which walls to reveal (don't modify visible[] while iterating)
	var walls_to_reveal: Array[int] = []
	for pos: int in range(LEN):
		if not visible[pos]:
			continue
		if los_blocking[pos]:
			continue  # Only spread from non-blocking (floor) cells
		var x: int = pos % W
		var y: int = pos / W
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx: int = x + dx
				var ny: int = y + dy
				if nx < 0 or nx >= W or ny < 0 or ny >= H:
					continue
				var npos: int = ny * W + nx
				if not visible[npos] and los_blocking[npos]:
					walls_to_reveal.append(npos)
	for npos: int in walls_to_reveal:
		visible[npos] = true

## Mark wall cells as visited only if they are adjacent to a visited floor cell.
## This prevents room outlines from being permanently revealed when the hero
## merely sees them at a distance through a corridor.
func _update_wall_visited() -> void:
	for pos: int in range(LEN):
		if visited[pos] or not los_blocking[pos]:
			continue
		# Check if any non-wall neighbor is visited
		var x: int = pos % W
		var y: int = pos / W
		var has_visited_neighbor: bool = false
		for dy: int in range(-1, 2):
			if has_visited_neighbor:
				break
			for dx: int in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx: int = x + dx
				var ny: int = y + dy
				if nx < 0 or nx >= W or ny < 0 or ny >= H:
					continue
				var npos: int = ny * W + nx
				if visited[npos] and not los_blocking[npos]:
					has_visited_neighbor = true
					break
		if has_visited_neighbor:
			visited[pos] = true

# ---------------------------------------------------------------------------
# Terrain Queries
# ---------------------------------------------------------------------------

func terrain_at(pos: int) -> int:
	if pos < 0 or pos >= LEN:
		return ConstantsData.Terrain.CHASM
	return map[pos]

func set_terrain(pos: int, terrain: int) -> void:
	if pos < 0 or pos >= LEN:
		return
	map[pos] = terrain
	passable[pos] = ConstantsData.terrain_is_passable(terrain)
	los_blocking[pos] = ConstantsData.terrain_blocks_vision(terrain)
	_update_astar_cell(pos)

func is_passable(pos: int) -> bool:
	if pos < 0 or pos >= LEN:
		return false
	return passable[pos]

## Find a random passable cell.
func random_passable_cell() -> int:
	var attempts: int = 0
	while attempts < 1000:
		var pos: int = randi_range(0, LEN - 1)
		if passable[pos] and pos != entrance and pos != exit_pos:
			return pos
		attempts += 1
	return -1

## Find a random cell matching a terrain type.
func random_cell_of_type(terrain: int) -> int:
	var candidates: Array[int] = []
	for i: int in range(LEN):
		if map[i] == terrain:
			candidates.append(i)
	if candidates.is_empty():
		return -1
	return candidates[randi_range(0, candidates.size() - 1)]

# ---------------------------------------------------------------------------
# Heaps (items on ground)
# ---------------------------------------------------------------------------

## Drop an item at a position. Returns the heap dictionary.
func drop_item(pos: int, item: Variant, heap_type: String = "heap") -> Dictionary:
	var heap: Dictionary = { "pos": pos, "item": item, "type": heap_type }
	heaps.append(heap)
	return heap

## Pick up (remove) and return the first item at a position, or null.
func pickup_item(pos: int) -> Variant:
	for i: int in range(heaps.size()):
		if heaps[i]["pos"] == pos:
			var item: Variant = heaps[i]["item"]
			heaps.remove_at(i)
			return item
	return null

## Get all heaps at a position.
func heaps_at(pos: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for h: Dictionary in heaps:
		if h["pos"] == pos:
			result.append(h)
	return result

# ---------------------------------------------------------------------------
# Traps
# ---------------------------------------------------------------------------

func place_trap(pos: int, trap: Variant) -> void:
	traps[pos] = trap
	if trap.has_method("set_pos"):
		trap.set_pos(pos)
	# Terrain is set by the caller (TRAP or SECRET_TRAP).

func trap_at(pos: int) -> Variant:
	return traps.get(pos)

# ---------------------------------------------------------------------------
# Mob Management
# ---------------------------------------------------------------------------

## Return the mob occupying a cell, or null.
func mob_at(pos: int) -> Variant:
	for mob: Variant in mobs:
		if mob is Object and mob.get("pos") == pos:
			return mob
	return null

## Add a mob to this level's mob list.
func add_mob(mob: Variant) -> void:
	if mob not in mobs:
		mobs.append(mob)
		if mob is Object:
			mob.set("level", self)

## Remove a mob from this level.
func remove_mob(mob: Variant) -> void:
	var idx: int = mobs.find(mob)
	if idx >= 0:
		mobs.remove_at(idx)

## Find any character (hero or mob) at the given position.
func find_char_at(pos: int) -> Variant:
	# Check heroes
	var hero_list: Array = get_heroes()
	for h: Variant in hero_list:
		if h is Object and h.get("pos") == pos:
			return h
	# Check mobs
	return mob_at(pos)

## Get all hero characters on this level (multiplayer-ready).
func get_heroes() -> Array[Char]:
	var result: Array[Char] = []
	if GameManager:
		for h: Node in GameManager.heroes:
			if h is Char:
				result.append(h as Char)
	return result

## Alias for Actor.can_see() compatibility.
func has_los(origin: int, target: int) -> bool:
	return is_visible_from(origin, target)

## Returns true if pos is visible from origin (uses ShadowCaster LOS check).
func is_visible_from(origin: int, target: int) -> bool:
	if origin == target:
		return true
	# Quick distance check
	var dist: int = maxi(
		absi((origin % W) - (target % W)),
		absi((origin / W) - (target / W))
	)
	if dist > ConstantsData.VIEW_DISTANCE:
		return false
	# Use the LOS blocking array for a direct line check
	var fov: Array[bool] = ShadowCaster.cast_fov(origin, los_blocking, W, dist + 1)
	if target >= 0 and target < fov.size():
		return fov[target]
	return false

## Trigger a trap at a given position against a character.
func trigger_trap(pos: int, victim: Variant) -> void:
	var trap: Variant = traps.get(pos)
	if trap == null:
		return
	if trap.has_method("activate"):
		trap.activate(victim, self)
	# Mark terrain as inactive
	set_terrain(pos, ConstantsData.Terrain.INACTIVE_TRAP)
	if GameManager:
		GameManager.record_stat("traps_triggered")

## Unlock the exit (boss levels — open all locked doors blocking the exit path).
func unlock_exit() -> void:
	# Scan the entire level for LOCKED_DOORs and open them all.
	# Boss levels typically have only one locked door blocking the exit corridor.
	for i: int in range(LEN):
		if map[i] == ConstantsData.Terrain.LOCKED_DOOR:
			set_terrain(i, ConstantsData.Terrain.OPEN_DOOR)
	if EventBus:
		EventBus.door_opened.emit(exit_pos)

## Returns true if two positions are adjacent (within 1 step, 8-directional).
func adjacent(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= LEN or b >= LEN:
		return false
	var ax: int = a % W
	var ay: int = a / W
	var bx: int = b % W
	var by: int = b / W
	return absi(ax - bx) <= 1 and absi(ay - by) <= 1 and a != b

## Chebyshev distance between two cell positions.
func distance(a: int, b: int) -> int:
	var ax: int = a % W
	var ay: int = a / W
	var bx: int = b % W
	var by: int = b / W
	return maxi(absi(ax - bx), absi(ay - by))

## Return an array of valid cell indices adjacent to the given cell.
func get_neighbors(cell: int) -> Array[int]:
	return Pathfinder.get_neighbors(cell, W, LEN)

## Find the shortest path between two cells using Godot's AStar2D (C++).
## Returns Array[int] of cell indices from start (exclusive) to goal (inclusive),
## or empty array if no path exists. Temporarily enables goal cell if disabled
## (e.g. occupied by an enemy the hero wants to attack).
func find_path(from_pos: int, to_pos: int) -> Array[int]:
	if from_pos < 0 or from_pos >= LEN or to_pos < 0 or to_pos >= LEN:
		return []
	if from_pos == to_pos:
		return []
	# Temporarily enable endpoints in case they're disabled (occupied cells)
	var from_was_disabled: bool = astar.is_point_disabled(from_pos)
	var to_was_disabled: bool = astar.is_point_disabled(to_pos)
	if from_was_disabled:
		astar.set_point_disabled(from_pos, false)
	if to_was_disabled:
		astar.set_point_disabled(to_pos, false)
	var id_path: PackedInt64Array = astar.get_id_path(from_pos, to_pos)
	# Restore disabled state
	if from_was_disabled:
		astar.set_point_disabled(from_pos, true)
	if to_was_disabled:
		astar.set_point_disabled(to_pos, true)
	if id_path.is_empty():
		return []
	# Convert to Array[int], skip the first element (start pos)
	var result: Array[int] = []
	for i: int in range(1, id_path.size()):
		result.append(id_path[i] as int)
	return result

## Find just the next step toward a goal cell. Returns -1 if no path.
func find_step(from_pos: int, to_pos: int) -> int:
	var path: Array[int] = find_path(from_pos, to_pos)
	if path.is_empty():
		return -1
	return path[0]

## Alias for terrain_at (used by actor system).
func get_terrain(pos: int) -> int:
	return terrain_at(pos)

## Return a duplicate of the mobs array (used by scrolls/effects that iterate mobs).
func get_mobs() -> Array[Node]:
	return mobs.duplicate()

## Return a duplicate of the heaps array (used by scrolls like Divination).
func get_heaps() -> Array[Dictionary]:
	return heaps.duplicate()

## Reveal the entire map (set all visited to true, reveal secret doors).
func reveal_all() -> void:
	for i: int in range(LEN):
		visited[i] = true
		mapped[i] = true
		if map[i] == ConstantsData.Terrain.SECRET_DOOR:
			set_terrain(i, ConstantsData.Terrain.DOOR)

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

## Serialize the full level state for caching / save-load.

# ---------------------------------------------------------------------------
# Missing Methods (added Run 15)
# ---------------------------------------------------------------------------

## Get all characters (hero + mobs) at the given cell positions.
func get_chars_at_positions(positions: Array[int]) -> Array[Char]:
	var result: Array[Char] = []
	for p: int in positions:
		var ch: Char = find_char_at(p) as Char
		if ch != null:
			result.append(ch)
	return result

## Destroy breakable terrain at a cell (bomb explosions, etc.).
func destroy_terrain(cell: int) -> void:
	if cell < 0 or cell >= LEN:
		return
	var t: int = terrain_at(cell)
	# Only destroy certain terrain types
	match t:
		ConstantsData.Terrain.DOOR, ConstantsData.Terrain.OPEN_DOOR:
			set_terrain(cell, ConstantsData.Terrain.EMBERS)
		ConstantsData.Terrain.BARRICADE:
			set_terrain(cell, ConstantsData.Terrain.EMBERS)
		ConstantsData.Terrain.HIGH_GRASS:
			set_terrain(cell, ConstantsData.Terrain.GRASS)
		ConstantsData.Terrain.BOOKSHELF:
			set_terrain(cell, ConstantsData.Terrain.EMPTY)
		# Walls, chasms, entrance, exit are indestructible

## Add a blob effect at a cell position.
func add_blob(blob: Variant, cell: int) -> void:
	if blob == null or cell < 0 or cell >= LEN:
		return
	if blob.has_method("seed"):
		blob.seed(cell, 1)
	var entry: Dictionary = {"blob": blob, "pos": cell}
	blobs.append(entry)

## Arm a bomb on the floor so it detonates after a fixed number of hero rounds.
func arm_bomb(cell: int, bomb: Variant, turns_left: int) -> void:
	if bomb == null or cell < 0 or cell >= LEN:
		return
	pending_bombs.append({
		"pos": cell,
		"bomb": bomb,
		"turns_left": maxi(1, turns_left),
	})
	if MessageLog:
		var bomb_name: String = bomb.get("item_name") if bomb.get("item_name") != null else "bomb"
		MessageLog.add_warning("The %s starts hissing!" % bomb_name)

## Advance all armed bomb fuses by one hero round. Returns true if any bomb
## detonated so the caller can refresh visuals immediately.
func tick_pending_bombs() -> bool:
	if pending_bombs.is_empty():
		return false
	var remaining: Array[Dictionary] = []
	var detonated_any: bool = false
	for entry: Dictionary in pending_bombs:
		var bomb: Variant = entry.get("bomb")
		var cell: int = int(entry.get("pos", -1))
		var turns_left: int = int(entry.get("turns_left", 1)) - 1
		if bomb == null or cell < 0 or cell >= LEN:
			continue
		if turns_left <= 0:
			detonated_any = true
			if bomb.has_method("detonate"):
				bomb.detonate(cell, self)
		else:
			entry["turns_left"] = turns_left
			remaining.append(entry)
	pending_bombs = remaining
	return detonated_any

## Alert all mobs on the level to a position (alarm traps, noisemaker bombs).
func alert_all_mobs(alert_pos: int) -> void:
	for mob: Variant in mobs:
		if mob != null and is_instance_valid(mob):
			if mob.has_method("alert"):
				mob.alert(alert_pos)
			else:
				mob.state = Mob.AIState.HUNTING

## Get sign text for a cell position. Signs are decoration; return flavor text.
func get_sign_text(sign_pos: int) -> String:
	# Signs could be stored per-level; for now return generic text
	if terrain_at(sign_pos) == ConstantsData.Terrain.SIGN:
		var texts: Array[String] = [
			"Beware of falling rocks.",
			"Do not feed the crabs.",
			"The walls have eyes.",
			"Turn back while you still can.",
			"Abandon all hope, ye who enter here.",
			"Watch your step.",
		]
		# Use position as seed for consistent text per sign
		return texts[sign_pos % texts.size()]
	return ""

## Reveal all secret doors and hidden traps on this level.
func reveal_all_secrets() -> void:
	for i: int in range(LEN):
		var t: int = terrain_at(i)
		if t == ConstantsData.Terrain.SECRET_DOOR:
			set_terrain(i, ConstantsData.Terrain.DOOR)
		elif t == ConstantsData.Terrain.SECRET_TRAP:
			set_terrain(i, ConstantsData.Terrain.TRAP)

## Reveal secrets and traps in a radius around a position.
func reveal_around(center: int, radius: int) -> void:
	var cx: int = center % ConstantsData.WIDTH
	var cy: int = center / ConstantsData.WIDTH
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var nx: int = cx + dx
			var ny: int = cy + dy
			if nx < 0 or nx >= ConstantsData.WIDTH or ny < 0 or ny >= ConstantsData.HEIGHT:
				continue
			var cell: int = ny * ConstantsData.WIDTH + nx
			var t: int = terrain_at(cell)
			if t == ConstantsData.Terrain.SECRET_DOOR:
				set_terrain(cell, ConstantsData.Terrain.DOOR)
				if MessageLog:
					MessageLog.add("You sense a hidden door nearby!")
			elif t == ConstantsData.Terrain.SECRET_TRAP:
				set_terrain(cell, ConstantsData.Terrain.TRAP)

## Reveal a rectangular area on the map (for mapping scrolls, stones).
func reveal_area(center: int, radius: int) -> void:
	var cx: int = center % ConstantsData.WIDTH
	var cy: int = center / ConstantsData.WIDTH
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var nx: int = cx + dx
			var ny: int = cy + dy
			if nx < 0 or nx >= ConstantsData.WIDTH or ny < 0 or ny >= ConstantsData.HEIGHT:
				continue
			var cell: int = ny * ConstantsData.WIDTH + nx
			if cell >= 0 and cell < LEN:
				mapped[cell] = true
				visited[cell] = true
