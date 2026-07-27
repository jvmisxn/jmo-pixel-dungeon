extends RefCounted
## Rogue's Foresight (upstream GameScene.create): on arriving at a regular
## floor with at least one secret room (two when the level feeling is SECRETS),
## the talent gives a 2+points in 4 (75%/100%) chance to print the secret hint.
## Upstream seeds the roll per level; the port rolls once and persists it on
## the level (`foresight_roll`) next to the generation-time `secret_room_count`.

func run(t: Object) -> void:
	_test_registry(t)
	_test_gating(t)
	_test_roll_thresholds(t)
	_test_secrets_feeling_requires_two(t)
	_test_roll_persists(t)
	_test_generation_counts_secrets(t)

func _make_level(secrets: int, feeling: int = Level.Feeling.NONE) -> RegularLevel:
	var level := RegularLevel.new()
	level.feeling = feeling
	level.secret_room_count = secrets
	return level

func _make_hero(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	if points > 0:
		hero.talent_levels["rogue_rogues_foresight"] = points
	return hero

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.ROGUE, "rogue_rogues_foresight")
	t.check(info != null, "rogue_rogues_foresight is registered for the Rogue")
	t.check(info != null and info.implemented,
		"rogue_rogues_foresight is marked implemented")
	t.check(info != null and info.tier == 2, "rogue_rogues_foresight is tier 2")

func _test_gating(t: Object) -> void:
	var level: RegularLevel = _make_level(1)
	level.foresight_roll = 0
	t.check(not FloorTransitionCoordinator.rogues_foresight_secret_hint(
		level, _make_hero(0)), "No hint without the talent")
	t.check(not FloorTransitionCoordinator.rogues_foresight_secret_hint(
		_make_level(0), _make_hero(2)), "No hint on a floor without secret rooms")
	var plain := Level.new()
	plain.secret_room_count = 3
	t.check(not FloorTransitionCoordinator.rogues_foresight_secret_hint(
		plain, _make_hero(2)), "Non-regular levels never hint")
	t.check(not FloorTransitionCoordinator.rogues_foresight_secret_hint(
		null, _make_hero(2)), "Null level is safe")

func _test_roll_thresholds(t: Object) -> void:
	# Upstream: hint iff Random.Int(4) < 2 + points.
	var level: RegularLevel = _make_level(1)
	level.foresight_roll = 2
	t.check(FloorTransitionCoordinator.rogues_foresight_secret_hint(
		level, _make_hero(1)), "+1: roll 2 is under the 75% threshold")
	level.foresight_roll = 3
	t.check(not FloorTransitionCoordinator.rogues_foresight_secret_hint(
		level, _make_hero(1)), "+1: roll 3 misses the 75% threshold")
	t.check(FloorTransitionCoordinator.rogues_foresight_secret_hint(
		level, _make_hero(2)), "+2: even roll 3 hints (100%)")

func _test_secrets_feeling_requires_two(t: Object) -> void:
	var level: RegularLevel = _make_level(1, Level.Feeling.SECRETS)
	level.foresight_roll = 0
	t.check(not FloorTransitionCoordinator.rogues_foresight_secret_hint(
		level, _make_hero(2)),
		"SECRETS feeling needs two secret rooms before hinting")
	level.secret_room_count = 2
	t.check(FloorTransitionCoordinator.rogues_foresight_secret_hint(
		level, _make_hero(2)), "SECRETS feeling hints at two secret rooms")

func _test_roll_persists(t: Object) -> void:
	var level: RegularLevel = _make_level(1)
	t.check(level.foresight_roll == -1, "Fresh level has no roll yet")
	var hinted: bool = FloorTransitionCoordinator.rogues_foresight_secret_hint(
		level, _make_hero(2))
	t.check(hinted, "+2 always hints once eligible")
	t.check(level.foresight_roll >= 0 and level.foresight_roll <= 3,
		"First check rolls and stores a 0-3 value")
	var rolled: int = level.foresight_roll
	FloorTransitionCoordinator.rogues_foresight_secret_hint(level, _make_hero(2))
	t.check(level.foresight_roll == rolled, "Repeat visits reuse the stored roll")

	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	var data: Dictionary = level.serialize()
	var loaded := RegularLevel.new()
	loaded.deserialize(data)
	t.check(loaded.secret_room_count == 1 and loaded.foresight_roll == rolled,
		"secret_room_count and foresight_roll survive a serialize round trip")
	var legacy := RegularLevel.new()
	legacy.deserialize({"depth": 1})
	t.check(legacy.secret_room_count == 0 and legacy.foresight_roll == -1,
		"Legacy saves default to no secrets and no stored roll")

func _test_generation_counts_secrets(t: Object) -> void:
	var level := SewerLevel.new()
	level.depth = 2
	var built: bool = false
	for _attempt: int in range(5):
		if level._build():
			built = true
			break
	if not built:
		t.check(false, "SewerLevel _build failed 5 attempts (generation broken?)")
		return
	var placed: int = 0
	for r: Variant in level.rooms:
		var room: Room = r as Room
		if room is SecretRoom and (
				not room.connected.is_empty() or not room.neighbors.is_empty()):
			placed += 1
	t.check(level.secret_room_count == placed,
		"Generation records the placed secret-room count")
