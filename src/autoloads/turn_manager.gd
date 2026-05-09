class_name TurnManagerNode
extends Node
## Actor-processing turn system inspired by Shattered PD's Actor.java.
##
## Every entity that takes turns (hero, mobs, buffs) registers as an "actor".
## Each actor has an energy/cooldown value. On each tick the manager finds the
## actor with the lowest cooldown, advances time to that point, then calls
## that actor's act() method. The actor is expected to spend energy when acting.

## Emitted after every actor has finished its turn step.
@warning_ignore("unused_signal")
signal turn_processed(actor: Node, turn_number: int)
## Emitted when all actors in the current round have been processed.
@warning_ignore("unused_signal")
signal round_completed(round_number: int)

## Base time unit. One standard-speed action costs TICK energy.
const TICK: float = 1.0

## Registered actors. Each entry: { "node": Node, "cooldown": float, "speed": float }
var _actors: Array[Dictionary] = []

## Global turn counter (total individual actor turns taken).
var _turn_count: int = 0
## Round counter (increments each time the hero acts).
var _round_count: int = 0

## Whether the system is currently processing (prevents re-entrant calls).
var _processing: bool = false

## If true, the turn loop pauses and waits (e.g., for player input).
var waiting_for_input: bool = false

## True while the async mob-processing coroutine is running.
## Prevents GameScene._process from re-entering the turn loop.
var processing_mobs: bool = false

## Delay (seconds) between visible mob actions (move/attack in hero's FOV).
## Set to 0 so visible mobs still animate/update in order, but don't add
## extra post-action waiting before control returns to the hero.
const MOB_ACTION_DELAY: float = 0.0

## Cached reference to the active GameScene (cleared on level transitions).
var _cached_game_scene: Node = null

func _is_time_frozen_for_nonhero(actor_node: Node) -> bool:
	if actor_node == null or actor_node.get("is_hero") == true:
		return false
	if GameManager == null:
		return false
	var hero_ref: Variant = GameManager.hero
	if hero_ref == null or not is_instance_valid(hero_ref):
		return false
	var belongings: Variant = hero_ref.get("belongings")
	if belongings == null or not belongings.has_method("get_equipped_artifact"):
		return false
	var artifact: Variant = belongings.get_equipped_artifact()
	return artifact != null and artifact.has_method("is_time_frozen") and artifact.is_time_frozen()

# ---------------------------------------------------------------------------
# Actor Registration
# ---------------------------------------------------------------------------

## Register an actor node. The node MUST implement:
##   func act() -> void          — perform the actor's turn
##   func get_speed() -> float   — return speed multiplier (1.0 = normal)
## Optional:
##   var is_hero: bool           — if true, the manager pauses for player input
func register_actor(actor_node: Node, initial_cooldown: float = 0.0) -> void:
	# Avoid double-registration.
	for entry: Dictionary in _actors:
		if entry["node"] == actor_node:
			return
	var speed: float = 1.0
	if actor_node.has_method("get_speed"):
		speed = actor_node.get_speed()
	_actors.append({
		"node": actor_node,
		"cooldown": initial_cooldown,
		"speed": speed,
	})

## Remove an actor from the schedule (e.g., when a mob dies).
func remove_actor(actor_node: Node) -> void:
	for i: int in range(_actors.size() - 1, -1, -1):
		if _actors[i]["node"] == actor_node:
			_actors.remove_at(i)
			return

## Returns true if the given node is currently registered.
func has_actor(actor_node: Node) -> bool:
	for entry: Dictionary in _actors:
		if entry["node"] == actor_node:
			return true
	return false

## Return number of registered actors.
func actor_count() -> int:
	return _actors.size()

# ---------------------------------------------------------------------------
# Energy / Cooldown Helpers
# ---------------------------------------------------------------------------

## Spend energy for a standard-speed action. Call this from inside act().
func spend_energy(actor_node: Node, turns: float = TICK) -> void:
	for entry: Dictionary in _actors:
		if entry["node"] == actor_node:
			# Slower actors pay more cooldown; faster actors pay less.
			var speed: float = entry["speed"]
			if speed <= 0.0:
				speed = 0.1  # safety floor
			entry["cooldown"] += turns / speed
			return

## Directly set an actor's cooldown (for special cases like paralysis).
func set_cooldown(actor_node: Node, value: float) -> void:
	for entry: Dictionary in _actors:
		if entry["node"] == actor_node:
			entry["cooldown"] = value
			return

## Retrieve an actor's current cooldown.
func get_cooldown(actor_node: Node) -> float:
	for entry: Dictionary in _actors:
		if entry["node"] == actor_node:
			return entry["cooldown"]
	return 0.0

## Refresh cached speed value (call after haste/slow buff changes).
func refresh_speed(actor_node: Node) -> void:
	for entry: Dictionary in _actors:
		if entry["node"] == actor_node:
			if actor_node.has_method("get_speed"):
				entry["speed"] = actor_node.get_speed()
			return

# ---------------------------------------------------------------------------
# Turn Processing
# ---------------------------------------------------------------------------

## Process a single actor turn — find the actor with the lowest cooldown,
## advance time, and call its act(). Returns the actor node that acted,
## or null if no actors or waiting for input.
func process_turn() -> Node:
	if _actors.is_empty():
		return null
	if _processing:
		return null  # re-entrant guard

	_processing = true

	# --- Find actor with the minimum cooldown ---
	var min_cd: float = INF
	var next_idx: int = -1
	for i: int in range(_actors.size()):
		var cd: float = _actors[i]["cooldown"]
		if cd < min_cd:
			min_cd = cd
			next_idx = i

	if next_idx == -1:
		_processing = false
		return null

	# --- Advance all cooldowns by the minimum (so next actor reaches 0) ---
	if min_cd > 0.0:
		for entry: Dictionary in _actors:
			entry["cooldown"] -= min_cd

	var acting_entry: Dictionary = _actors[next_idx]

	# Safety: skip freed actors (mob died from deferred free on prior frame)
	# Check validity BEFORE assigning to a typed variable to avoid the
	# "invalid previously freed instance" error.
	var actor_ref: Variant = acting_entry.get("node")
	if not is_instance_valid(actor_ref):
		_actors.remove_at(next_idx)
		_processing = false
		return null
	var actor_node: Node = actor_ref as Node

	# If this is the hero, pause for player input.
	if actor_node.get("is_hero") == true:
		waiting_for_input = true
		_processing = false
		return actor_node

	# Time freeze from Timekeeper's Hourglass skips non-hero actions while
	# still advancing them through the cooldown schedule.
	if _is_time_frozen_for_nonhero(actor_node):
		spend_energy(actor_node, TICK)
		_turn_count += 1
		if is_instance_valid(actor_node):
			turn_processed.emit(actor_node, _turn_count)
		_processing = false
		return actor_node

	# --- Let the actor act ---
	if actor_node.has_method("act"):
		actor_node.act()

	_turn_count += 1
	# Guard against actor being freed during its own act() (e.g., poison kill)
	if is_instance_valid(actor_node):
		turn_processed.emit(actor_node, _turn_count)

	_processing = false
	return actor_node

## Called after the hero has chosen and executed their action.
## Processes non-hero actors one at a time with visual delays so the
## player can see each enemy act individually.
func hero_action_complete() -> void:
	waiting_for_input = false
	_turn_count += 1
	_round_count += 1
	# Update message log turn counter so messages group by round.
	if MessageLog:
		MessageLog.current_turn = _round_count
	round_completed.emit(_round_count)

	# Start async mob processing
	processing_mobs = true
	_process_mobs_async()

## Async coroutine that processes mob turns one at a time, adding brief
## visual delays ONLY for mobs that did something visible (moved/attacked
## while in the hero's FOV). Sleeping, passive, or out-of-sight mobs are
## processed instantly with no delay or screen refresh.
func _get_game_scene_cached() -> Node:
	if _cached_game_scene != null and is_instance_valid(_cached_game_scene):
		return _cached_game_scene
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_cached_game_scene = tree.current_scene
	return _cached_game_scene

func _should_abort_async_processing(game_scene: Node) -> bool:
	if GameManager != null:
		var hero_ref: Variant = GameManager.hero
		if hero_ref != null and is_instance_valid(hero_ref) and hero_ref.get("is_alive") == false:
			return true
	if game_scene != null and game_scene.get("_game_ended") == true:
		return true
	return false

func _process_mobs_async() -> void:
	var safety: int = 200
	var game_scene: Node = _get_game_scene_cached()

	while safety > 0:
		safety -= 1
		if _should_abort_async_processing(game_scene):
			break
		if _actors.is_empty():
			break
		# Find next actor
		var actor: Node = process_turn()
		if actor == null:
			break
		if _should_abort_async_processing(game_scene):
			break
		# If it's the hero's turn, stop mob processing
		if actor.get("is_hero") == true:
			break
		# Check if this mob did something visible
		if actor.get("did_visible_action") == true:
			actor.did_visible_action = false
			if game_scene and game_scene.has_method("on_mob_action"):
				game_scene.on_mob_action(actor)
			# Optional pacing delay for visible actions.
			if MOB_ACTION_DELAY > 0.0:
				await Engine.get_main_loop().create_timer(MOB_ACTION_DELAY).timeout

	processing_mobs = false

## Alias for register_actor (used by mob spawning code).
func add_actor(actor_node: Node, initial_cooldown: float = 0.0) -> void:
	register_actor(actor_node, initial_cooldown)

## Remove all actors and reset counters (used on level transitions).
func clear_actors() -> void:
	_actors.clear()
	_turn_count = 0
	_round_count = 0
	waiting_for_input = false
	processing_mobs = false

## Process turns until it's the hero's turn (used on level load).
func process_until_hero() -> void:
	var safety: int = 500
	while safety > 0:
		safety -= 1
		if _actors.is_empty():
			break
		var actor: Node = process_turn()
		if actor == null:
			break
		if actor.get("is_hero") == true:
			break
