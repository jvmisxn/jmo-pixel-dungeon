extends RefCounted
## Boss-floor bidirectional seal parity (upstream Level.seal/unseal):
## when a boss fight starts the floor locks, blocking BOTH staircases (SPD
## seals the level in the boss's notice()); the seal lifts on boss death,
## which also opens the exit's locked doors. The lock survives save/load.

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 5
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(10, 10)
	level.map[ConstantsData.xy_to_pos(10, 9)] = ConstantsData.Terrain.LOCKED_DOOR
	level.build_flag_maps()
	return level

func run(t: Object) -> void:
	var level: Level = _make_level()
	t.check(not level.locked, "freshly built level starts unlocked")

	# --- seal() is idempotent and flips locked ---
	level.seal()
	t.check(level.locked, "seal() locks the level")
	level.seal()
	t.check(level.locked, "second seal() is a harmless no-op")

	# --- locked flag round-trips through serialize/deserialize ---
	var data: Dictionary = level.serialize()
	var reloaded := Level.new()
	reloaded.deserialize(data)
	t.check(reloaded.locked, "locked seal persists through save/load")
	var fresh := Level.new()
	fresh.deserialize({})
	t.check(not fresh.locked, "legacy saves without the field load unlocked")

	# --- boss waking (boss bar start) seals its level ---
	var boss_level: Level = _make_level()
	var goo := Goo.new()
	goo.level = boss_level
	goo._ensure_boss_bar_started()
	t.check(boss_level.locked, "boss fight starting seals the floor")

	# --- boss death unseals and opens the exit door ---
	var door_pos: int = ConstantsData.xy_to_pos(10, 9)
	goo.hp = 1
	goo.take_damage(999, null)
	t.check(not boss_level.locked, "boss death lifts the seal")
	t.check(
		boss_level.map[door_pos] == ConstantsData.Terrain.OPEN_DOOR,
		"boss death opens the locked exit door"
	)

	# --- a non-boss mob waking never seals ---
	var plain_level: Level = _make_level()
	var rat := Mob.new()
	rat.mob_id = "rat"
	rat.setup(8, 8, 2, 1, 4, 0)
	rat.level = plain_level
	rat._ensure_boss_bar_started()
	t.check(not plain_level.locked, "non-boss mobs never seal the floor")
	rat.free()
