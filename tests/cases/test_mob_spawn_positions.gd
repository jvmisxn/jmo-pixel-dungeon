extends RefCounted

class SpawnLevel:
	extends RegularLevel

	var fallback_positions: Array[int] = []
	var fallback_index: int = 0
	var ignore_entrance: bool = true

	func random_passable_cell() -> int:
		if fallback_positions.is_empty():
			return -1
		var pos: int = fallback_positions[fallback_index % fallback_positions.size()]
		fallback_index += 1
		return pos

	func _near_entrance(pos: int) -> bool:
		return false if ignore_entrance else super._near_entrance(pos)

func _fill_empty(level: RegularLevel) -> void:
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.build_flag_maps()

func _make_room(left: int, top: int, right: int, bottom: int) -> StandardRoom:
	var room := StandardRoom.new()
	room.left = left
	room.top = top
	room.right = right
	room.bottom = bottom
	return room

func _unique_count(values: Array[int]) -> int:
	var seen: Dictionary[int, bool] = {}
	for value: int in values:
		seen[value] = true
	return seen.size()

func run(t: Object) -> void:
	var fallback_only := SpawnLevel.new()
	_fill_empty(fallback_only)
	fallback_only.rooms = []
	fallback_only.fallback_positions = [
		ConstantsData.xy_to_pos(12, 12),
		ConstantsData.xy_to_pos(13, 12),
		ConstantsData.xy_to_pos(14, 12),
		ConstantsData.xy_to_pos(15, 12),
	]
	var fallback_positions: Array[int] = fallback_only.mob_spawn_positions(4)
	t.check(
		fallback_positions.size() == 4,
		"mob fallback returns the requested count instead of a single position"
	)
	t.check(
		_unique_count(fallback_positions) == 4,
		"mob fallback avoids duplicate spawn cells"
	)

	var room_level := SpawnLevel.new()
	_fill_empty(room_level)
	room_level.rooms = [_make_room(10, 10, 18, 18)]
	var room_positions: Array[int] = room_level.mob_spawn_positions(6)
	t.check(
		room_positions.size() == 6,
		"standard-room mob placement keeps trying until the requested count is placed"
	)
	t.check(
		_unique_count(room_positions) == 6,
		"standard-room mob placement avoids duplicate spawn cells"
	)

	var blocked_room_level := SpawnLevel.new()
	_fill_empty(blocked_room_level)
	blocked_room_level.rooms = [_make_room(10, 10, 18, 18)]
	for pos: int in blocked_room_level.rooms[0].interior_cells():
		blocked_room_level.map[pos] = ConstantsData.Terrain.WALL
	blocked_room_level.fallback_positions = [
		ConstantsData.xy_to_pos(20, 20),
		ConstantsData.xy_to_pos(21, 20),
		ConstantsData.xy_to_pos(22, 20),
	]
	var blocked_positions: Array[int] = blocked_room_level.mob_spawn_positions(3)
	t.check(
		blocked_positions.size() == 3,
		"failed room placement does not consume the remaining mob count"
	)
