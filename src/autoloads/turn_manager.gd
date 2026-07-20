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
@warning_ignore("unused_signal")
signal input_actor_changed(actor: Variant)

## Base time unit. One standard-speed action costs TICK energy.
const TICK: float = 1.0

## Registered actors. Each entry: { "node": Node, "cooldown": float, "speed": float }
var _actors: Array[Dictionary] = []

## Global turn counter (total individual actor turns taken).
var _turn_count: int = 0
## Monotonic game-timeline clock (Shattered PD's Actor.now). Advances by the
## real game-time elapsed between actions (the min cooldown consumed each step),
## independent of how many individual actors acted. Timed buffs read this so their
## duration burns down by shared game-time rather than by their owner's action rate.
var _now: float = 0.0
## Round counter (increments each time all currently registered heroes act once).
var _round_count: int = 0
## Tracks which currently registered heroes still need to act this party round.
var _round_hero_ids_pending: Array[int] = []

## Whether the system is currently processing (prevents re-entrant calls).
var _processing: bool = false

## Schedule state captured from a save, held until actors re-register on load.
## Kept separate from live actor state so clear_actors() never wipes it; applied
## explicitly (and consumed) by the load path once actors exist again.
var _pending_schedule: Dictionary = {}

## If true, the turn loop pauses and waits (e.g., for player input).
var waiting_for_input: bool = false

## True while the async mob-processing coroutine is running.
## Prevents GameScene._process from re-entering the turn loop.
var processing_mobs: bool = false

## Delay (seconds) between visible mob actions (move/attack in hero's FOV).
## Mirrors Shattered Pixel Dungeon's short movement interval so attacks and
## movement remain readable when several mobs act after the hero.
const MOB_ACTION_DELAY: float = 0.1

## Cached reference to the active GameScene (cleared on level transitions).
var _cached_game_scene: Node = null
## The hero currently owning local input/focus.
var current_input_actor: Node = null

func _ready() -> void:
	# SceneManager registers after TurnManager in the autoload order, so defer
	# the hookup until all autoloads exist.
	_connect_scene_manager.call_deferred()

## Invalidate the cached GameScene whenever a transition completes so the turn
## loop never dispatches on_mob_action to a stale/freed scene node.
func _connect_scene_manager() -> void:
	if SceneManager != null and SceneManager.has_signal("scene_changed"):
		if not SceneManager.scene_changed.is_connected(_on_scene_changed):
			SceneManager.scene_changed.connect(_on_scene_changed)

func _is_time_frozen_for_nonhero(actor_node: Node) -> bool:
	if actor_node == null or actor_node.get("is_hero") == true:
		return false
	if GameManager == null:
		return false
	var hero_ref: Variant = GameManager.get_primary_hero() if GameManager.has_method("get_primary_hero") else GameManager.hero
	if hero_ref == null or not is_instance_valid(hero_ref):
		return false
	var belongings: Variant = hero_ref.get("belongings")
	if belongings == null or not belongings.has_method("get_equipped_artifact"):
		return false
	var artifact: Variant = belongings.get_equipped_artifact()
	return artifact != null and artifact.has_method("is_time_frozen") and artifact.is_time_frozen()

func get_input_hero() -> Node:
	if current_input_actor != null and is_instance_valid(current_input_actor):
		return current_input_actor
	return null

func _get_registered_hero_ids() -> Array[int]:
	var hero_ids: Array[int] = []
	for entry: Dictionary in _actors:
		var actor_ref: Variant = entry.get("node")
		if actor_ref == null or not is_instance_valid(actor_ref):
			continue
		var actor_node: Node = actor_ref as Node
		if actor_node.get("is_hero") == true and actor_node.get("actor_id") != null:
			hero_ids.append(int(actor_node.get("actor_id")))
	return hero_ids

func _remove_hero_from_round_pending(actor_node: Node) -> bool:
	if actor_node == null or actor_node.get("actor_id") == null:
		return false
	var actor_id: int = int(actor_node.get("actor_id"))
	var removed: bool = false
	for idx: int in range(_round_hero_ids_pending.size() - 1, -1, -1):
		if _round_hero_ids_pending[idx] == actor_id:
			_round_hero_ids_pending.remove_at(idx)
			removed = true
	return removed

func _reseed_round_pending_if_needed() -> void:
	if not _round_hero_ids_pending.is_empty():
		return
	_round_hero_ids_pending = _get_registered_hero_ids()

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
			_remove_hero_from_round_pending(actor_node)
			if current_input_actor == actor_node:
				current_input_actor = null
				input_actor_changed.emit(null)
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
			# Slower actors pay more cooldown; faster actors pay less. Re-query
			# live so buffs/rings that change speed affect the very next action.
			var speed: float = _current_speed_for_actor(actor_node, entry)
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

## Current position on the shared game timeline. Buffs measure elapsed duration
## against this so Haste/Slow change how often an owner acts, not how fast its
## timed effects burn down in game-time.
func now() -> float:
	return _now

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
			_current_speed_for_actor(actor_node, entry)
			return

func _current_speed_for_actor(actor_node: Node, entry: Dictionary) -> float:
	var speed: float = float(entry.get("speed", 1.0))
	if actor_node != null and actor_node.has_method("get_speed"):
		speed = float(actor_node.get_speed())
		entry["speed"] = speed
	return speed

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
		# The shared timeline moves forward by the same real game-time. Buffs sample
		# this clock so their duration is measured in game-time, not in owner actions
		# (a Hasted owner acts more often but the same amount of time passes).
		_now += min_cd

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
		current_input_actor = actor_node
		input_actor_changed.emit(actor_node)
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
func hero_action_complete(actor_node: Node = null) -> void:
	waiting_for_input = false
	_turn_count += 1
	if actor_node != null and is_instance_valid(actor_node) and actor_node.get("is_hero") == true:
		current_input_actor = actor_node
		_reseed_round_pending_if_needed()
		var removed_from_pending: bool = _remove_hero_from_round_pending(actor_node)
		if removed_from_pending and _round_hero_ids_pending.is_empty():
			_round_count += 1
			# Update message log turn counter so messages group by party round.
			if MessageLog:
				MessageLog.current_turn = _round_count
			round_completed.emit(_round_count)
		turn_processed.emit(actor_node, _turn_count)

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
	# Prefer SceneManager's tracked scene: it is updated synchronously on every
	# transition, whereas get_tree().current_scene only agrees once SceneManager
	# has mirrored it. Falling back to the tree keeps this working in bare-tree
	# contexts where the SceneManager autoload is absent.
	if SceneManager != null and SceneManager.current_scene != null and is_instance_valid(SceneManager.current_scene):
		_cached_game_scene = SceneManager.current_scene
		return _cached_game_scene
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_cached_game_scene = tree.current_scene
	return _cached_game_scene

## Drop the cached scene when SceneManager reports a transition, so the next
## mob-processing pass resolves the freshly active scene instead of a stale
## (possibly freed) node.
func _on_scene_changed(_new_scene: Node) -> void:
	_cached_game_scene = null

func _should_abort_async_processing(game_scene: Node) -> bool:
	if GameManager != null:
		var hero_ref: Variant = GameManager.get_primary_hero() if GameManager.has_method("get_primary_hero") else GameManager.hero
		if hero_ref != null and is_instance_valid(hero_ref) and hero_ref.get("is_alive") == false:
			return true
	if game_scene != null and game_scene.get("_game_ended") == true:
		return true
	return false

func _process_mobs_async() -> void:
	var game_scene: Node = _get_game_scene_cached()

	while true:
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
	_now = 0.0
	_round_hero_ids_pending.clear()
	current_input_actor = null
	input_actor_changed.emit(null)
	waiting_for_input = false
	processing_mobs = false

# ---------------------------------------------------------------------------
# Schedule Persistence
# ---------------------------------------------------------------------------
# Shattered PD persists each Actor's position on the shared timeline (Actor.time)
# plus the global clock (Actor.now) so a just-acted, slowed, or hasted actor keeps
# its place after a reload instead of resetting to act immediately. This port uses
# a relative cooldown per actor (time-until-next-action) rather than absolute time,
# so we persist each actor's cooldown keyed by its stable actor_id, alongside the
# turn/round counters, and re-link by id after actors re-register on load.

## Capture the current scheduler timeline as a plain, save-friendly dictionary.
func serialize_schedule() -> Dictionary:
	var cooldowns: Array[Dictionary] = []
	for entry: Dictionary in _actors:
		var actor_ref: Variant = entry.get("node")
		if actor_ref == null or not is_instance_valid(actor_ref):
			continue
		var actor_node: Node = actor_ref as Node
		if actor_node.get("actor_id") == null:
			continue
		cooldowns.append({
			"actor_id": int(actor_node.get("actor_id")),
			"cooldown": float(entry.get("cooldown", 0.0)),
			"speed": float(entry.get("speed", 1.0)),
		})
	var input_id: int = -1
	if current_input_actor != null and is_instance_valid(current_input_actor) and current_input_actor.get("actor_id") != null:
		input_id = int(current_input_actor.get("actor_id"))
	return {
		"turn_count": _turn_count,
		"round_count": _round_count,
		"now": _now,
		"round_hero_ids_pending": _round_hero_ids_pending.duplicate(),
		"current_input_actor_id": input_id,
		"cooldowns": cooldowns,
	}

## Stash a saved schedule to be applied once actors have re-registered. Kept out
## of live actor state so an intervening clear_actors() (the load path clears and
## re-activates every actor) does not discard it.
func stage_schedule(data: Variant) -> void:
	if data is Dictionary and not (data as Dictionary).is_empty():
		_pending_schedule = (data as Dictionary).duplicate(true)
	else:
		_pending_schedule = {}

## Apply and consume a staged schedule against the currently registered actors,
## matching by actor_id. No-op when nothing is staged. Call this after the load
## path has finished (re-)activating all actors for the restored level.
func apply_pending_schedule() -> void:
	if _pending_schedule.is_empty():
		return
	var data: Dictionary = _pending_schedule
	_pending_schedule = {}
	restore_schedule(data)

## Discard any staged schedule without applying it (e.g. on aborted loads).
func clear_pending_schedule() -> void:
	_pending_schedule = {}

## Restore scheduler state from a serialized schedule, re-linking cooldowns to the
## live actors by actor_id. Counters are restored so message/round grouping and
## turn totals continue from where the save left off.
func restore_schedule(data: Dictionary) -> void:
	if data == null or data.is_empty():
		return

	var by_id: Dictionary = {}
	var cooldowns: Variant = data.get("cooldowns", [])
	if cooldowns is Array:
		for saved: Variant in cooldowns:
			if saved is Dictionary:
				by_id[int((saved as Dictionary).get("actor_id", -1))] = saved

	for entry: Dictionary in _actors:
		var actor_ref: Variant = entry.get("node")
		if actor_ref == null or not is_instance_valid(actor_ref):
			continue
		var actor_node: Node = actor_ref as Node
		if actor_node.get("actor_id") == null:
			continue
		var record: Variant = by_id.get(int(actor_node.get("actor_id")), null)
		if record is Dictionary:
			entry["cooldown"] = float((record as Dictionary).get("cooldown", entry.get("cooldown", 0.0)))
			entry["speed"] = float((record as Dictionary).get("speed", entry.get("speed", 1.0)))

	_turn_count = int(data.get("turn_count", _turn_count))
	_round_count = int(data.get("round_count", _round_count))
	_now = float(data.get("now", _now))

	var pending: Variant = data.get("round_hero_ids_pending", null)
	if pending is Array:
		var typed_pending: Array[int] = []
		for value: Variant in pending:
			typed_pending.append(int(value))
		_round_hero_ids_pending = typed_pending

	var input_id: int = int(data.get("current_input_actor_id", -1))
	if input_id >= 0:
		for entry2: Dictionary in _actors:
			var ref2: Variant = entry2.get("node")
			if ref2 != null and is_instance_valid(ref2) and (ref2 as Node).get("actor_id") == input_id:
				current_input_actor = ref2 as Node
				break

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
