extends RefCounted
## Regression coverage for the secret-room placement gap (audit:S08 P2).
##
## A secret room whose branch placement failed used to keep whatever bounds
## the last placement attempt left behind and still get painted, producing
## out-of-bounds rooms (seed 1015 depth 4 gave left=-5), map-edge-flush rooms
## (seed 1016), and in-bounds-but-isolated rooms with no door / unreachable
## loot (seeds 1015/1071). LoopBuilder now discards rooms it never placed, so
## every SecretRoom that survives into level.rooms must be:
##   (a) fully in bounds,
##   (b) not flush against the map edge (its border can hold a door), and
##   (c) reachable via at least one door/opening on its border.

const DOOR_TERRAINS: Array[int] = [
	ConstantsData.Terrain.DOOR,
	ConstantsData.Terrain.OPEN_DOOR,
	ConstantsData.Terrain.LOCKED_DOOR,
	ConstantsData.Terrain.CRYSTAL_DOOR,
	ConstantsData.Terrain.SECRET_DOOR,
]

# Known-bad seeds surfaced by the 2026-07-27 200-seed scan.
const EXPLICIT_BAD_SEEDS: Array[int] = [1015, 1016, 1071]
const EXPLICIT_DEPTHS: Array[int] = [2, 3, 4, 6]

# Range scan mirroring the repo's existing multi-seed scan style.
const SCAN_START: int = 1000
const SCAN_COUNT: int = 150
const SCAN_DEPTHS: Array[int] = [2, 3, 4, 6]


func _border_door_count(level: Level, room: Room) -> int:
	var count: int = 0
	var w: int = ConstantsData.WIDTH
	for x: int in range(room.left, room.right + 1):
		for y: int in [room.top, room.bottom]:
			var pos: int = y * w + x
			if pos >= 0 and pos < Level.LEN and level.map[pos] in DOOR_TERRAINS:
				count += 1
	for y: int in range(room.top + 1, room.bottom):
		for x: int in [room.left, room.right]:
			var pos: int = y * w + x
			if pos >= 0 and pos < Level.LEN and level.map[pos] in DOOR_TERRAINS:
				count += 1
	return count


func _in_bounds(room: Room) -> bool:
	return room.in_bounds()


func _edge_flush(room: Room) -> bool:
	# A room whose border sits on the map's outer ring cannot hold a door
	# and would be clipped by the always-wall level edge.
	return room.left <= 0 or room.top <= 0 \
		or room.right >= ConstantsData.WIDTH - 1 \
		or room.bottom >= ConstantsData.HEIGHT - 1


func _free_mobs(level: Level) -> void:
	for mob: Variant in level.mobs:
		if mob != null and is_instance_valid(mob):
			(mob as Node).free()
	level.mobs.clear()


## Validate every secret room on one generated level. Returns a describing
## string of the first defect found, or "" when all secret rooms are healthy.
func _validate_level(level: Level) -> String:
	if level == null:
		return ""
	for room_ref: Variant in level.rooms:
		var room: Room = room_ref as Room
		if room == null or room.type != Room.Type.SECRET:
			continue
		if not _in_bounds(room):
			return "out-of-bounds L=%d T=%d R=%d B=%d" % [room.left, room.top, room.right, room.bottom]
		if _edge_flush(room):
			return "edge-flush L=%d T=%d R=%d B=%d" % [room.left, room.top, room.right, room.bottom]
		if _border_door_count(level, room) <= 0:
			return "isolated (no border door) L=%d T=%d R=%d B=%d conns=%d" % [
				room.left, room.top, room.right, room.bottom, room.connected.size()]
	return ""


func run(t: Object) -> void:
	var prev_depth: int = GameManager.depth
	var prev_limited: Dictionary = GameManager.limited_drops.duplicate(true)
	GameManager.limited_drops.clear()

	# --- Explicit known-bad seeds: one check per (seed, depth) so a
	#     regression pinpoints exactly which case broke. ---
	for sd: int in EXPLICIT_BAD_SEEDS:
		for depth: int in EXPLICIT_DEPTHS:
			seed(sd)
			GameManager.depth = depth
			var level: Level = LevelFactory.create_for_depth(depth)
			var defect: String = _validate_level(level)
			t.check(defect == "",
				"seed %d depth %d: all secret rooms in-bounds/off-edge/reachable (%s)"
					% [sd, depth, defect])
			_free_mobs(level)

	# --- Range scan: aggregate so the whole sweep is a handful of checks. ---
	var total_secret: int = 0
	var levels_scanned: int = 0
	var first_defect: String = ""
	var bad_count: int = 0
	for i: int in range(SCAN_COUNT):
		var sd: int = SCAN_START + i
		var depth: int = SCAN_DEPTHS[i % SCAN_DEPTHS.size()]
		seed(sd)
		GameManager.depth = depth
		var level: Level = LevelFactory.create_for_depth(depth)
		levels_scanned += 1
		for room_ref: Variant in level.rooms:
			var room: Room = room_ref as Room
			if room != null and room.type == Room.Type.SECRET:
				total_secret += 1
		var defect: String = _validate_level(level)
		if defect != "":
			bad_count += 1
			if first_defect == "":
				first_defect = "seed %d depth %d: %s" % [sd, depth, defect]
		_free_mobs(level)

	t.check(levels_scanned == SCAN_COUNT,
		"range scan generated %d levels" % SCAN_COUNT)
	t.check(total_secret > 0,
		"range scan produced at least one secret room to validate (got %d)" % total_secret)
	t.check(bad_count == 0,
		"range scan: 0/%d levels have a bad secret room (first: %s)"
			% [levels_scanned, first_defect])

	GameManager.depth = prev_depth
	GameManager.limited_drops = prev_limited
