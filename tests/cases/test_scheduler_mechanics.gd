extends RefCounted
## TurnManager scheduler mechanics: cooldown rebasing, round_completed emission,
## remove_actor clearing _round_hero_ids_pending, and freed-actor skip.
## Covers the gaps listed in [P2][audit:S04].

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

	func act() -> void:
		pass

func run(t: Object) -> void:
	var tm_script: Variant = load("res://src/autoloads/turn_manager.gd")
	t.check(tm_script != null, "turn_manager.gd loads")
	if tm_script == null:
		return

	# --- 1. Cooldown rebasing ---
	# When process_turn fires, the minimum cooldown is subtracted from every
	# registered actor before the winner acts, advancing the shared clock.
	var tm1: Node = tm_script.new()
	var a1: MockActor = MockActor.new(1, 1.0)
	var a2: MockActor = MockActor.new(2, 1.0)
	tm1.register_actor(a1)
	tm1.register_actor(a2)
	# Place actors at known cooldowns with a gap.
	tm1.set_cooldown(a1, 1.0)
	tm1.set_cooldown(a2, 3.0)
	# a1 has the lower cooldown; process_turn should rebase all by 1.0 then act a1.
	var acted: Node = tm1.process_turn()
	t.check(acted == a1, "rebasing: lowest-cooldown actor acts first")
	t.check(is_equal_approx(tm1.get_cooldown(a2), 2.0),
		"rebasing: a2 cooldown reduced by a1's min_cd (3.0 - 1.0 = 2.0)")
	t.check(is_equal_approx(tm1.now(), 1.0),
		"rebasing: shared game clock advances by min_cd")
	tm1.free()
	a1.free()
	a2.free()

	# --- 2. round_completed fires exactly once per party round ---
	# Emitted when the last registered hero finishes their action this round.
	# Use a Dictionary counter — GDScript lambdas capture primitives by value,
	# so a plain int var would not be mutated by the signal callback.
	var tm2: Node = tm_script.new()
	var h1: MockActor = MockActor.new(10, 1.0, true)
	var h2: MockActor = MockActor.new(11, 1.0, true)
	tm2.register_actor(h1)
	tm2.register_actor(h2)
	var rc: Dictionary = {"n": 0}
	tm2.round_completed.connect(func(_r: int) -> void: rc["n"] += 1)
	# First hero acts — second is still pending.
	tm2.hero_action_complete(h1)
	t.check(rc["n"] == 0,
		"round_completed: not fired after first of two heroes acts")
	# Second hero acts — round is complete.
	tm2.hero_action_complete(h2)
	t.check(rc["n"] == 1,
		"round_completed: fires once when last hero of the round acts")
	# New round: first hero acts again — second still pending.
	tm2.hero_action_complete(h1)
	t.check(rc["n"] == 1,
		"round_completed: not fired again at start of next round")
	# New round: second hero acts — round 2 complete.
	tm2.hero_action_complete(h2)
	t.check(rc["n"] == 2,
		"round_completed: fires again on completion of the second round")
	tm2.free()
	h1.free()
	h2.free()

	# --- 3. remove_actor cleans _round_hero_ids_pending ---
	# Removing a hero mid-round must scrub it from the pending list so that
	# the round can complete without that hero ever acting again.
	var tm3: Node = tm_script.new()
	var h3: MockActor = MockActor.new(20, 1.0, true)
	var h4: MockActor = MockActor.new(21, 1.0, true)
	tm3.register_actor(h3)
	tm3.register_actor(h4)
	# h3 acts — seeds pending to [20, 21] then removes h3, leaving [21].
	tm3.hero_action_complete(h3)
	t.check(tm3._round_hero_ids_pending.has(21),
		"remove_actor: h4 id in pending before removal")
	# Remove h4 while it's still pending.
	tm3.remove_actor(h4)
	t.check(not tm3._round_hero_ids_pending.has(21),
		"remove_actor: h4 id scrubbed from pending list on removal")
	tm3.free()
	h3.free()

	# --- 4. Freed-actor skip ---
	# If a registered actor is freed between scheduling and acting (e.g., mob
	# dies from deferred free), process_turn must detect is_instance_valid == false,
	# remove the stale entry, and return null rather than crashing.
	var tm4: Node = tm_script.new()
	var live_a: MockActor = MockActor.new(30, 1.0)
	var freed_a: MockActor = MockActor.new(31, 0.5)
	tm4.register_actor(freed_a)
	tm4.register_actor(live_a)
	# Give freed_a priority so it would act next.
	tm4.set_cooldown(freed_a, 0.0)
	tm4.set_cooldown(live_a, 1.0)
	freed_a.free()
	# process_turn should silently skip the freed actor and return null.
	var result: Node = tm4.process_turn()
	t.check(result == null,
		"freed-actor skip: process_turn returns null for a freed actor entry")
	# The freed entry must be removed so the live actor is next.
	t.check(tm4.actor_count() == 1,
		"freed-actor skip: stale entry removed, only live actor remains")
	tm4.free()
	live_a.free()
