extends RefCounted

class FakeOpener:
	extends RefCounted

	var keys: Dictionary = {}
	var used: Array[String] = []

	func has_key(key_type: String) -> bool:
		return int(keys.get(key_type, 0)) > 0

	func use_key(key_type: String) -> void:
		used.append(key_type)
		keys[key_type] = maxi(0, int(keys.get(key_type, 0)) - 1)

func _make_level(door_pos: int, door_terrain: int = ConstantsData.Terrain.LOCKED_DOOR) -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.map[door_pos] = door_terrain
	level.build_flag_maps()
	return level

func run(t: Object) -> void:
	var door_pos: int = ConstantsData.xy_to_pos(6, 6)

	var golden_opener := FakeOpener.new()
	golden_opener.keys["golden"] = 1
	var golden_level: Level = _make_level(door_pos)
	t.check(
		not Door.open(golden_level, door_pos, golden_opener),
		"ordinary locked doors do not open with golden keys"
	)
	t.check(
		golden_level.terrain_at(door_pos) == ConstantsData.Terrain.LOCKED_DOOR,
		"golden-key attempt leaves locked door closed"
	)
	t.check(
		golden_opener.used.is_empty() and int(golden_opener.keys["golden"]) == 1,
		"golden-key attempt does not consume the chest key"
	)

	var iron_opener := FakeOpener.new()
	iron_opener.keys["iron"] = 1
	var iron_level: Level = _make_level(door_pos)
	t.check(
		Door.open(iron_level, door_pos, iron_opener),
		"ordinary locked doors open with iron keys"
	)
	t.check(
		iron_level.terrain_at(door_pos) == ConstantsData.Terrain.OPEN_DOOR,
		"iron-key attempt opens the locked door"
	)
	t.check(
		iron_opener.used == ["iron"] and int(iron_opener.keys["iron"]) == 0,
		"iron-key attempt consumes exactly one iron key"
	)

	var sealed_opener := FakeOpener.new()
	sealed_opener.keys["iron"] = 1
	var sealed_level: Level = _make_level(door_pos, ConstantsData.Terrain.CRYSTAL_DOOR)
	t.check(
		not Door.open(sealed_level, door_pos, sealed_opener),
		"crystal doors do not open with iron keys"
	)
	t.check(
		sealed_level.terrain_at(door_pos) == ConstantsData.Terrain.CRYSTAL_DOOR,
		"iron-key attempt leaves the crystal door sealed"
	)
	t.check(
		sealed_opener.used.is_empty() and int(sealed_opener.keys["iron"]) == 1,
		"iron-key attempt on a crystal door consumes nothing"
	)

	var crystal_opener := FakeOpener.new()
	crystal_opener.keys["crystal"] = 1
	var crystal_level: Level = _make_level(door_pos, ConstantsData.Terrain.CRYSTAL_DOOR)
	t.check(
		Door.open(crystal_level, door_pos, crystal_opener),
		"crystal doors open with crystal keys"
	)
	t.check(
		crystal_level.terrain_at(door_pos) == ConstantsData.Terrain.EMPTY,
		"crystal doors shatter to empty floor, not an open door (upstream Hero.actUnlock)"
	)
	t.check(
		crystal_level.is_passable(door_pos),
		"shattered crystal door cell is passable"
	)
	t.check(
		crystal_opener.used == ["crystal"] and int(crystal_opener.keys["crystal"]) == 0,
		"crystal-key attempt consumes exactly one crystal key"
	)
