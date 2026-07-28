extends RefCounted
## In-engine verification for the restored door system (audit:S08 P1):
## full LevelFactory generation must paint doors at tunnel mouths on
## regular levels, and special rooms must keep their gated entrances
## (LOCKED_DOOR for vault/armory, CRYSTAL_DOOR for crystal vaults).
## Complements the synthetic-pair coverage in test_level_generation_doors.gd.

const DOOR_TERRAINS: Array[int] = [
	ConstantsData.Terrain.DOOR,
	ConstantsData.Terrain.OPEN_DOOR,
	ConstantsData.Terrain.LOCKED_DOOR,
	ConstantsData.Terrain.CRYSTAL_DOOR,
	ConstantsData.Terrain.SECRET_DOOR,
]


func _border_cells(room: Room) -> Array[int]:
	var cells: Array[int] = []
	for x: int in range(room.left, room.right + 1):
		cells.append(ConstantsData.xy_to_pos(x, room.top))
		cells.append(ConstantsData.xy_to_pos(x, room.bottom))
	for y: int in range(room.top + 1, room.bottom):
		cells.append(ConstantsData.xy_to_pos(room.left, y))
		cells.append(ConstantsData.xy_to_pos(room.right, y))
	return cells


const SEALED_BORDER_TERRAINS: Array[int] = [
	ConstantsData.Terrain.WALL,
	ConstantsData.Terrain.WALL_DECO,
	ConstantsData.Terrain.BARRICADE,
	ConstantsData.Terrain.DOOR,
	ConstantsData.Terrain.OPEN_DOOR,
	ConstantsData.Terrain.LOCKED_DOOR,
	ConstantsData.Terrain.CRYSTAL_DOOR,
	ConstantsData.Terrain.SECRET_DOOR,
]


func _border_breaches(level: Level, room: Room) -> Array[int]:
	var breaches: Array[int] = []
	for cell: int in _border_cells(room):
		if level.terrain_at(cell) not in SEALED_BORDER_TERRAINS:
			breaches.append(cell)
	return breaches


func _border_has_terrain(level: Level, room: Room, terrain: int) -> bool:
	for cell: int in _border_cells(room):
		if level.terrain_at(cell) == terrain:
			return true
	return false


func _count_doors(level: Level) -> int:
	var count: int = 0
	for i: int in range(Level.LEN):
		if level.map[i] in DOOR_TERRAINS:
			count += 1
	return count


func _free_mobs(level: Level) -> void:
	for mob: Variant in level.mobs:
		if mob != null and is_instance_valid(mob):
			(mob as Node).free()
	level.mobs.clear()


func run(t: Object) -> void:
	var prev_depth: int = GameManager.depth
	var prev_limited: Dictionary = GameManager.limited_drops.duplicate(true)
	GameManager.limited_drops.clear()

	seed(24680)
	for depth: int in [1, 2, 4, 6]:
		GameManager.depth = depth
		var level: Level = LevelFactory.create_for_depth(depth)
		t.check(level != null and not level.rooms.is_empty(),
			"depth %d generates a room-based regular level" % depth)

		var doors: int = _count_doors(level)
		t.check(doors > 0,
			"depth %d paints at least one door (got %d)" % [depth, doors])

		for room_ref: Variant in level.rooms:
			var room: Room = room_ref as Room
			if room == null:
				continue
			var gated: bool = (room is CrystalVaultRoom or room is VaultRoom
				or room is ArmoryRoom or room.type == Room.Type.SECRET)
			if gated:
				# Every gated room that survives into level.rooms is now
				# guaranteed placed and in bounds (LoopBuilder discards failed
				# placements — audit:S08 secret-room fix), so no out-of-bounds
				# skip is needed. Tunnel carving must never open extra wall
				# cells on a gated room's border (audit:S08 breach fix).
				t.check(room.in_bounds(),
					"depth %d gated room is in bounds L=%d T=%d R=%d B=%d"
						% [depth, room.left, room.top, room.right, room.bottom])
				var breaches: Array[int] = _border_breaches(level, room)
				t.check(breaches.is_empty(),
					"depth %d gated room border intact (breaches: %s)" % [depth, str(breaches)])
			if room is CrystalVaultRoom:
				t.check(_border_has_terrain(level, room, ConstantsData.Terrain.CRYSTAL_DOOR),
					"depth %d crystal vault is sealed by a crystal door" % depth)
			elif room is VaultRoom or room is ArmoryRoom:
				t.check(_border_has_terrain(level, room, ConstantsData.Terrain.LOCKED_DOOR),
					"depth %d vault/armory is sealed by a locked door" % depth)
			elif room.type == Room.Type.SECRET:
				# Every placed secret room must be reachable behind a secret
				# door — a tunnel-mouth secret door counts even when the room
				# was attached as a neighbor (connected stays empty). Isolated
				# secret rooms were the audit:S08 placement bug, now fixed.
				t.check(_border_has_terrain(level, room, ConstantsData.Terrain.SECRET_DOOR),
					"depth %d secret room is hidden behind a secret door" % depth)

		_free_mobs(level)

	GameManager.depth = prev_depth
	GameManager.limited_drops = prev_limited
