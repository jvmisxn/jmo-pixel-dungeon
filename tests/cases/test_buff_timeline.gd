extends RefCounted
## Scheduled buff timeline: a timed buff must burn down by shared game-time, not by
## its owner's action count. Haste/Slow change how OFTEN an owner acts, not how fast
## its timed effects expire in game-time terms. Mirrors Shattered PD's model of buffs
## acting on the shared Actor.now timeline, adapted to this port's relative-cooldown
## scheduler plus game-time buff advancement (Char.act_buffs / TurnManager.now).

## Minimal scheduled character: on its turn it advances buffs off the shared timeline
## (exactly as Hero/Mob do) and spends a standard turn at its fixed speed.
class TimelineActor:
	extends Char
	var fixed_speed: float = 1.0
	var act_count: int = 0

	func get_speed() -> float:
		return fixed_speed

	func act() -> void:
		act_count += 1
		act_buffs()
		spend_turn()

func _make_actor(speed: float) -> TimelineActor:
	var a: TimelineActor = TimelineActor.new()
	a.fixed_speed = speed
	a.base_speed = speed
	a.is_alive = true
	a.hp = 10000
	a.hp_max = 10000
	a.ht = 10000
	# Weakness is a pure 20-turn timed debuff with no speed side effects, so it is a
	# clean probe for how fast a duration burns down relative to owner actions.
	a.add_buff(Weakness.new())
	return a

func run(t: Object) -> void:
	_test_carry_math(t)
	_test_timeline_markers_serialize(t)
	_test_haste_does_not_shorten_duration(t)

## process_buffs(elapsed) is the low-level primitive: whole-turn ticks with the
## fractional remainder carried across calls. Feeding 40 half-turns must equal 20
## whole-turn ticks (a Hasted actor's per-action slice), and the default 1.0 path
## must still tick exactly once per call (the historical contract other tests rely on).
func _test_carry_math(t: Object) -> void:
	var half: TimelineActor = TimelineActor.new()
	half.add_buff(Weakness.new())
	var w_half: Weakness = half.get_buff("Weakness") as Weakness
	t.check(w_half != null and is_equal_approx(w_half.time_left, 20.0), "Weakness starts at 20 turns")
	for _i: int in range(39):
		half.process_buffs(0.5)
	t.check(half.has_buff("Weakness"), "39 half-turns (19.5) leave the buff active")
	t.check(
		w_half != null and is_equal_approx(w_half.time_left, 20.0 - 19.0),
		"39 half-turns apply exactly 19 whole ticks, remainder carried"
	)
	half.process_buffs(0.5)  # reaches 20.0 total -> 20th tick -> expiry
	t.check(not half.has_buff("Weakness"), "40 half-turns (20.0 game-turns) expire the 20-turn buff")

	var whole: TimelineActor = TimelineActor.new()
	whole.add_buff(Weakness.new())
	for _i: int in range(19):
		whole.process_buffs()  # default 1.0 per call
	t.check(whole.has_buff("Weakness"), "19 default ticks leave the buff active")
	whole.process_buffs()
	t.check(not whole.has_buff("Weakness"), "20 default ticks expire the buff (one tick per call preserved)")

	half.free()
	whole.free()

func _test_timeline_markers_serialize(t: Object) -> void:
	var original: TimelineActor = TimelineActor.new()
	original._buff_time_marker = 12.5
	original._buff_pending = 0.5
	var payload: Dictionary = original.serialize()
	var restored: TimelineActor = TimelineActor.new()
	restored.deserialize(payload)
	t.check(is_equal_approx(restored._buff_time_marker, 12.5), "buff timeline marker survives Char serialization")
	t.check(is_equal_approx(restored._buff_pending, 0.5), "buff fractional pending time survives Char serialization")
	original.free()
	restored.free()

## End-to-end on the real scheduler: a normal (1x) and a Hasted (2x) actor each carry
## a 20-turn Weakness. The Hasted actor acts about twice as often, but both debuffs
## must expire at the same point on the shared game timeline.
func _test_haste_does_not_shorten_duration(t: Object) -> void:
	if TurnManager == null or not TurnManager.has_method("now"):
		t.check(false, "TurnManager autoload with now() is required for the timeline test")
		return

	TurnManager.clear_actors()

	var normal: TimelineActor = _make_actor(1.0)
	var hasted: TimelineActor = _make_actor(2.0)
	TurnManager.register_actor(normal)
	TurnManager.register_actor(hasted)

	var normal_expiry_now: float = -1.0
	var normal_expiry_acts: int = -1
	var hasted_expiry_now: float = -1.0
	var hasted_expiry_acts: int = -1
	# Weakness time_left the moment the Hasted actor has taken 20 of its own actions.
	# Under the old owner-action model this would already be 0 (expired); under the
	# timeline model only ~10 game-turns have passed, so ~10 turns should remain.
	var hasted_time_left_at_20_acts: float = -1.0

	var guard: int = 0
	while guard < 800 and (normal.has_buff("Weakness") or hasted.has_buff("Weakness")):
		guard += 1
		var actor: Node = TurnManager.process_turn()
		if actor == null:
			break
		if actor == hasted and hasted.act_count == 20 and hasted_time_left_at_20_acts < 0.0:
			var w: Weakness = hasted.get_buff("Weakness") as Weakness
			hasted_time_left_at_20_acts = w.time_left if w != null else 0.0
		if actor == normal and not normal.has_buff("Weakness") and normal_expiry_now < 0.0:
			normal_expiry_now = TurnManager.now()
			normal_expiry_acts = normal.act_count
		if actor == hasted and not hasted.has_buff("Weakness") and hasted_expiry_now < 0.0:
			hasted_expiry_now = TurnManager.now()
			hasted_expiry_acts = hasted.act_count

	t.check(normal_expiry_acts >= 19 and normal_expiry_acts <= 21,
		"normal actor's 20-turn buff expires in ~20 of its own actions")
	t.check(hasted_expiry_acts >= 36,
		"Hasted actor takes ~2x the actions to expire the same 20-turn buff")
	t.check(hasted_expiry_now > 0.0 and absf(hasted_expiry_now - normal_expiry_now) <= 2.0,
		"both buffs expire at the same point on the shared game timeline")
	t.check(hasted_time_left_at_20_acts >= 7.0 and hasted_time_left_at_20_acts <= 13.0,
		"after 20 Hasted actions the buff is only ~half spent (not expired by action count)")

	TurnManager.remove_actor(normal)
	TurnManager.remove_actor(hasted)
	TurnManager.clear_actors()
	normal.free()
	hasted.free()
