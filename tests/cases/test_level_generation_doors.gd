extends RefCounted

func _make_level() -> Level:
	var level := Level.new()
	level._init_arrays()
	return level

func _make_standard(left: int, top: int, right: int, bottom: int) -> StandardRoom:
	var room := StandardRoom.new()
	room.left = left
	room.top = top
	room.right = right
	room.bottom = bottom
	return room

func _set_room_bounds(room: Room, left: int, top: int, right: int, bottom: int) -> Room:
	room.left = left
	room.top = top
	room.right = right
	room.bottom = bottom
	return room

func _paint_pair(left_room: Room, right_room: Room) -> Level:
	var level: Level = _make_level()
	left_room.neighbors.append(right_room)
	right_room.neighbors.append(left_room)
	level.rooms = [left_room, right_room]
	StandardPainter.paint_level(level)
	return level

func _terrain_at(level: Level, x: int, y: int) -> int:
	return level.terrain_at(ConstantsData.xy_to_pos(x, y))

func run(t: Object) -> void:
	var standard: StandardRoom = _make_standard(5, 5, 9, 9)
	var vault: VaultRoom = _set_room_bounds(VaultRoom.new(), 12, 5, 16, 9) as VaultRoom
	var vault_level: Level = _paint_pair(standard, vault)
	t.check(
		_terrain_at(vault_level, 9, 7) == ConstantsData.Terrain.DOOR,
		"neighbor tunnels place a normal door at the standard-room mouth"
	)
	t.check(
		_terrain_at(vault_level, 12, 7) == ConstantsData.Terrain.LOCKED_DOOR,
		"neighbor tunnels preserve locked vault entrances"
	)
	t.check(
		_terrain_at(vault_level, 10, 7) == ConstantsData.Terrain.EMPTY
			and _terrain_at(vault_level, 11, 7) == ConstantsData.Terrain.EMPTY,
		"neighbor tunnel keeps the corridor between room doors open"
	)

	var crystal_standard: StandardRoom = _make_standard(5, 12, 9, 16)
	var crystal: CrystalVaultRoom = _set_room_bounds(CrystalVaultRoom.new(), 12, 12, 16, 16) as CrystalVaultRoom
	var crystal_level: Level = _paint_pair(crystal_standard, crystal)
	t.check(
		_terrain_at(crystal_level, 12, 14) == ConstantsData.Terrain.CRYSTAL_DOOR,
		"neighbor tunnels preserve crystal vault doors"
	)

	var secret_standard: StandardRoom = _make_standard(20, 5, 24, 9)
	var secret: SecretRoom = _set_room_bounds(SecretRoom.new(), 27, 5, 31, 9) as SecretRoom
	var secret_level: Level = _paint_pair(secret_standard, secret)
	t.check(
		_terrain_at(secret_level, 27, 7) == ConstantsData.Terrain.SECRET_DOOR,
		"neighbor tunnels preserve secret-room entrances"
	)
