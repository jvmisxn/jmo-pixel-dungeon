extends RefCounted
## Blobs/gases advance on the shared game timeline (TurnManager.now()), not per
## hero round. Proves that Haste, Slow, and multi-hero co-op cadence never make a
## gas cloud tick faster or slower than real game-time: the number of blob steps
## always equals floor(now()), regardless of how fast or how many actors act, and
## equal elapsed game-time always yields equal blob steps. Mirrors Shattered PD,
## where each Blob is an Actor evolving on the shared Actor.now clock.

## Clock actor: drives a TurnManager instance's timeline authentically by
## spending a standard turn each act() (cooldown = turns / speed), the same
## mechanic real heroes/mobs use. Not a hero, so process_turn() never pauses.
class ClockActor:
	extends Node
	var actor_id: int = -1
	var is_hero: bool = false
	var _speed: float = 1.0
	var _tm: Object = null

	func _init(id: int, tm: Object, speed: float = 1.0) -> void:
		actor_id = id
		_tm = tm
		_speed = speed

	func get_speed() -> float:
		return _speed

	func act() -> void:
		_tm.spend_energy(self, _tm.TICK)

## Blob that never spreads or decays and counts how many simulation steps it
## runs, so we can compare step count directly against elapsed game-time.
class CountingBlob:
	extends Blob
	var ticks: int = 0

	func _init() -> void:
		super._init()
		blob_id = "counting_blob"
		spread_rate = 0.0
		decay_rate = 0.0

	func tick() -> void:
		ticks += 1
		super.tick()

func _new_tm() -> Object:
	var tm_script: Variant = load("res://src/autoloads/turn_manager.gd")
	return tm_script.new()

func _seed_counter(level: Level) -> CountingBlob:
	var center: int = ConstantsData.xy_to_pos(16, 16)
	var blob: CountingBlob = CountingBlob.new()
	level.add_blob(blob, center, 5.0)
	return blob

## Advance the timeline one actor turn at a time, catching blobs up to now()
## after each — exactly what the game does via the per-turn feedback hook.
func _step(tm: Object, level: Level, count: int) -> void:
	for _i: int in range(count):
		tm.process_turn()
		level.advance_blobs(tm.now())

## Advance until game-time reaches at least `target_now`.
func _drive_to(tm: Object, level: Level, target_now: float) -> void:
	var safety: int = 1000
	while tm.now() < target_now and safety > 0:
		safety -= 1
		tm.process_turn()
		level.advance_blobs(tm.now())

func run(t: Object) -> void:
	_test_invariant_ticks_equal_floor_now(t)
	_test_hasted_under_ticks_relative_to_actions(t)
	_test_slowed_over_ticks_relative_to_actions(t)
	_test_equal_game_time_equal_ticks(t)
	_test_multi_hero_tracks_game_time(t)
	_test_timeline_reset_snaps_without_ticking(t)
	_test_blob_time_persists_no_reload_burst(t)

## The governing invariant across every actor speed and party size: blob steps
## always equal floor(elapsed game-time). This is what "on the shared timeline"
## means — cadence is a function of game-time, nothing else.
func _test_invariant_ticks_equal_floor_now(t: Object) -> void:
	for speed: float in [2.0, 1.0, 0.5]:
		var tm: Object = _new_tm()
		var level: Level = Level.new()
		var blob: CountingBlob = _seed_counter(level)
		tm.register_actor(ClockActor.new(1, tm, speed))
		_step(tm, level, 10)
		var expected: int = int(floor(tm.now()))
		t.check(blob.ticks == expected,
				"speed %.1f: blob steps == floor(now())=%d, got %d" % [speed, expected, blob.ticks])

## A Hasted actor packs more actions into the same game-time, so over a fixed
## action count it must tick blobs FEWER times than its actions — never once per
## action (which is the per-round bug this slice removes).
func _test_hasted_under_ticks_relative_to_actions(t: Object) -> void:
	var tm: Object = _new_tm()
	var level: Level = Level.new()
	var blob: CountingBlob = _seed_counter(level)
	tm.register_actor(ClockActor.new(1, tm, 2.0))
	_step(tm, level, 8)  # 8 hasted actions span ~3.5 game-time
	t.check(blob.ticks == int(floor(tm.now())), "hasted: steps track game-time")
	t.check(blob.ticks < 8, "hasted actor's 8 actions tick blobs fewer than 8 times")

## A Slowed actor stretches each action across more game-time, so it must tick
## blobs MORE times than its action count — not once per action.
func _test_slowed_over_ticks_relative_to_actions(t: Object) -> void:
	var tm: Object = _new_tm()
	var level: Level = Level.new()
	var blob: CountingBlob = _seed_counter(level)
	tm.register_actor(ClockActor.new(1, tm, 0.5))
	_step(tm, level, 4)  # 4 slowed actions span ~6 game-time
	t.check(blob.ticks == int(floor(tm.now())), "slowed: steps track game-time")
	t.check(blob.ticks > 4, "slowed actor's 4 actions tick blobs more than 4 times")

## The parity guarantee stated directly: equal elapsed game-time yields equal
## blob steps, whether produced by one normal action or two hasted ones.
func _test_equal_game_time_equal_ticks(t: Object) -> void:
	var tm_a: Object = _new_tm()
	var level_a: Level = Level.new()
	var blob_a: CountingBlob = _seed_counter(level_a)
	tm_a.register_actor(ClockActor.new(1, tm_a, 1.0))
	_drive_to(tm_a, level_a, 4.0)

	var tm_b: Object = _new_tm()
	var level_b: Level = Level.new()
	var blob_b: CountingBlob = _seed_counter(level_b)
	tm_b.register_actor(ClockActor.new(1, tm_b, 2.0))
	_drive_to(tm_b, level_b, 4.0)

	# Both speeds land exactly on now == 4.0 (steps of 1.0 and 0.5 respectively).
	t.check(is_equal_approx(tm_a.now(), tm_b.now()), "both paths elapse the same game-time")
	t.check(blob_a.ticks == blob_b.ticks,
			"equal game-time gives equal blob steps regardless of action rate (%d vs %d)"
			% [blob_a.ticks, blob_b.ticks])

## Two co-op heroes do not halve or double the blob rate: steps still equal
## floor(now()), i.e. once per game-time TICK, not once per party round.
func _test_multi_hero_tracks_game_time(t: Object) -> void:
	var tm: Object = _new_tm()
	var level: Level = Level.new()
	var blob: CountingBlob = _seed_counter(level)
	tm.register_actor(ClockActor.new(1, tm, 1.0))
	tm.register_actor(ClockActor.new(2, tm, 1.0))
	_step(tm, level, 8)
	var expected: int = int(floor(tm.now()))
	t.check(blob.ticks == expected,
			"two-hero party ticks blobs floor(now())=%d times, got %d" % [expected, blob.ticks])

## When the timeline resets beneath the level (new/re-entered level sets
## TurnManager.now() back to 0 while the cursor is stale), advance_blobs snaps
## the cursor forward without replaying a catch-up burst.
func _test_timeline_reset_snaps_without_ticking(t: Object) -> void:
	var level: Level = Level.new()
	var blob: CountingBlob = _seed_counter(level)
	level.advance_blobs(5.0)  # advance to now=5
	t.check(blob.ticks == 5, "blob advanced 5 steps up to now=5")

	# Clock resets to 0 (level transition). No further ticks; cursor snaps back.
	var still_active: bool = level.advance_blobs(0.0)
	t.check(not still_active, "timeline reset reports no visual change")
	t.check(blob.ticks == 5, "no blob steps run when the clock goes backward")
	# Resuming forward from 0 ticks normally again, not from the stale cursor.
	level.advance_blobs(2.0)
	t.check(blob.ticks == 7, "blobs resume on the reset clock (2 more steps)")

## Saving mid-catch-up and reloading must not replay a burst: the blob timeline
## cursor persists alongside now(), so a reload starts flush with the clock.
func _test_blob_time_persists_no_reload_burst(t: Object) -> void:
	var level: Level = Level.new()
	var blob: CountingBlob = _seed_counter(level)
	level.advance_blobs(4.0)
	t.check(blob.ticks == 4, "blob advanced 4 steps before save")

	var data: Dictionary = level.serialize()
	t.check(is_equal_approx(float(data.get("blob_time", -1.0)), 4.0),
			"serialize persists the blob timeline cursor")

	var restored: Level = Level.new()
	restored.deserialize(data)
	var ticks_at_load: int = blob.ticks  # blob object is carried over by the save dict
	# now() is restored to ~4.0 too; advancing to it must run zero extra steps.
	var active_after_load: bool = restored.advance_blobs(4.0)
	t.check(not active_after_load, "reload at the saved now() reports no catch-up work")
	t.check(blob.ticks == ticks_at_load, "reload at the saved now() replays no catch-up burst")
