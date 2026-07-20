extends RefCounted
## TurnManager schedule persistence: a just-acted, slowed, or hasted actor must
## keep its place on the timeline across a save/load cycle instead of resetting
## to a zero cooldown (which would let every actor act immediately after reload).
## Mirrors Shattered PD persisting each Actor's timeline position, adapted to this
## port's relative-cooldown model (cooldowns keyed by stable actor_id).

## Minimal actor stand-in: TurnManager only needs actor_id + get_speed() for the
## scheduling/serialization paths under test.
class MockActor:
	extends Node
	var actor_id: int = -1
	var is_hero: bool = false
	var _speed: float = 1.0

	func _init(id: int, speed: float = 1.0, hero: bool = false) -> void:
		actor_id = id
		_speed = speed
		is_hero = hero

	func get_speed() -> float:
		return _speed

func run(t: Object) -> void:
	var tm_script: Variant = load("res://src/autoloads/turn_manager.gd")
	t.check(tm_script != null and tm_script is GDScript, "turn_manager.gd compiles")
	if tm_script == null:
		return

	var tm: Node = tm_script.new()

	# Hero (normal speed), a Slowed actor (0.5x), and a Hasted actor (2x).
	var hero: MockActor = MockActor.new(101, 1.0, true)
	var slowed: MockActor = MockActor.new(102, 0.5)
	var hasted: MockActor = MockActor.new(103, 2.0)

	tm.register_actor(hero)
	tm.register_actor(slowed)
	tm.register_actor(hasted)

	# Each spends a standard turn: cooldown = turns / speed. Slower actors pay
	# more cooldown, faster actors pay less.
	tm.spend_energy(hero, 1.0)    # 1.0 / 1.0 = 1.0
	tm.spend_energy(slowed, 1.0)  # 1.0 / 0.5 = 2.0
	tm.spend_energy(hasted, 1.0)  # 1.0 / 2.0 = 0.5

	t.check(is_equal_approx(tm.get_cooldown(hero), 1.0), "hero cooldown is 1.0 after acting")
	t.check(is_equal_approx(tm.get_cooldown(slowed), 2.0), "slowed actor pays 2.0 cooldown")
	t.check(is_equal_approx(tm.get_cooldown(hasted), 0.5), "hasted actor pays 0.5 cooldown")

	# Advance counters and input focus so the round-trip covers them too.
	tm._turn_count = 42
	tm._round_count = 7
	tm._round_hero_ids_pending = [101] as Array[int]
	tm.current_input_actor = hero

	# --- Serialize, then push through the real save byte pipeline (store_var) ---
	var schedule: Dictionary = tm.serialize_schedule()
	t.check(schedule.has("cooldowns"), "serialized schedule includes cooldowns")
	var round_tripped: Variant = bytes_to_var(var_to_bytes(schedule))
	t.check(round_tripped is Dictionary, "schedule survives var_to_bytes round-trip")
	var restored_schedule: Dictionary = round_tripped as Dictionary

	# --- Simulate a reload: wipe live scheduler state, then re-register actors ---
	tm.clear_actors()
	t.check(is_equal_approx(tm.get_cooldown(slowed), 0.0), "cooldown resets to 0 after clear_actors")
	t.check(tm._turn_count == 0, "turn count resets after clear_actors")

	# Re-register the SAME actors (stable actor_id) as the load path would, and add
	# a brand-new actor that was not part of the saved schedule.
	var newcomer: MockActor = MockActor.new(999, 1.0)
	tm.register_actor(hero)
	tm.register_actor(slowed)
	tm.register_actor(hasted)
	tm.register_actor(newcomer)

	# Stage + apply exactly as SaveManager.load_full_game / loading_scene do.
	tm.stage_schedule(restored_schedule)
	tm.apply_pending_schedule()

	t.check(is_equal_approx(tm.get_cooldown(hero), 1.0), "reload preserves hero cooldown")
	t.check(is_equal_approx(tm.get_cooldown(slowed), 2.0), "reload preserves slowed actor cooldown")
	t.check(is_equal_approx(tm.get_cooldown(hasted), 0.5), "reload preserves hasted actor cooldown")
	t.check(is_equal_approx(tm.get_cooldown(newcomer), 0.0), "actor absent from save keeps default cooldown")
	t.check(tm._turn_count == 42, "reload preserves turn count")
	t.check(tm._round_count == 7, "reload preserves round count")
	t.check(tm._round_hero_ids_pending == ([101] as Array[int]), "reload preserves pending round heroes")
	t.check(tm.current_input_actor == hero, "reload re-links current input actor by id")

	# Staged schedule is single-use: a later apply is a harmless no-op so a plain
	# level descent (clear + re-register) does not re-stamp stale cooldowns.
	tm.spend_energy(hero, 1.0)
	tm.apply_pending_schedule()
	t.check(is_equal_approx(tm.get_cooldown(hero), 2.0), "consumed schedule does not re-apply on later calls")

	# Relative ordering is preserved: among the restored actors the hasted one has
	# the lowest cooldown and acts next. (Push the freshly-spawned newcomer, which
	# starts at 0.0, out of the way so it does not win the tie.)
	tm.set_cooldown(hero, 1.0)
	tm.set_cooldown(newcomer, 10.0)
	var next_actor: Node = tm.process_turn()
	t.check(next_actor == hasted, "hasted actor (lowest cooldown) is scheduled first after reload")

	tm.free()
	hero.free()
	slowed.free()
	hasted.free()
	newcomer.free()
