class_name GameManagerNode
extends Node
## Main game state singleton, analogous to Dungeon.java in Shattered PD.
## Holds the current run's global state: hero reference, depth, gold, seed,
## statistics, and provides save/load functionality.

# --- Signals ---
@warning_ignore("unused_signal")
signal game_started
@warning_ignore("unused_signal")
signal game_ended(victory: bool)
@warning_ignore("unused_signal")
signal depth_changed(new_depth: int)
@warning_ignore("unused_signal")
signal gold_changed(new_total: int)
@warning_ignore("unused_signal")
signal score_changed(new_score: int)
@warning_ignore("unused_signal")
signal local_hero_changed(hero_node: Node, hero_index: int)

# --- Run State ---
## The currently active level (RefCounted, not a Node).
var current_level: Variant = null
## Reference to the primary hero (backwards compat). Same as heroes[0].
var hero: Node = null
## All active heroes (multiplayer-ready). hero == heroes[0] for single-player.
var heroes: Array[Node] = []
## Requested hero classes for the current/future party bootstrap.
var party_classes: Array[int] = []
## Which hero the local client/UI is currently focused on.
## For single-player this stays at 0. In future co-op this becomes the local
## controlled party member, while `hero` remains a backwards-compat alias.
var local_hero_index: int = 0
const MAX_PARTY_SIZE: int = 4
## Current dungeon depth (1-26). Depth 0 = surface/not in dungeon.
var depth: int = 0
## Gold collected in this run.
var gold: int = 0
## Random seed for deterministic generation.
var run_seed: int = 0
## Accumulated score.
var score: int = 0
## Hero class chosen for this run.
var hero_class: int = ConstantsData.HeroClass.WARRIOR  # default
## Hero subclass (unlocked at depth 6 boss).
var hero_subclass: int = ConstantsData.HeroSubclass.NONE
## Whether a run is currently in progress.
var run_active: bool = false
const DESKTOP_CONTENT_SCALE_SIZE: Vector2i = Vector2i(1280, 720)
const MOBILE_LANDSCAPE_CONTENT_SCALE_SIZE: Vector2i = Vector2i(932, 430)
const MOBILE_PORTRAIT_CONTENT_SCALE_SIZE: Vector2i = Vector2i(430, 932)
const MOBILE_WEB_MAX_VIEWPORT: int = 960
const MOBILE_WEB_MIN_CONTENT_SCALE: int = 320
const MOBILE_WEB_MAX_CONTENT_SCALE: int = 960
const MOBILE_ORIENTATION_AUTO: String = "auto"
const MOBILE_ORIENTATION_PORTRAIT: String = "portrait"
const MOBILE_ORIENTATION_LANDSCAPE: String = "landscape"
var mobile_orientation_mode: String = MOBILE_ORIENTATION_AUTO
var zoom_level: float = 1.5

# --- Statistics ---
var stats: Dictionary[String, int] = {}

# --- Visited Levels Cache ---
## Maps depth (int) -> saved level data (Dictionary) for backtracking.
var _level_cache: Dictionary[int, Dictionary] = {}

# --- Fallen Items (upstream Dungeon.droppedItems) ---
## Items that fell through a chasm/pitfall, waiting to land on a lower depth.
## Keyed by destination depth (int) -> Array of serialized item Dictionaries.
## Items are serialized at drop time so they survive the source level being
## freed/cached; LoadingScene delivers and clears each depth's list on arrival.
var pending_dropped_items: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------


## Quest flags stored as a dictionary for tracking quest progress.
var quest_flags: Dictionary[String, Variant] = {}

## Set a quest flag.
func set_quest_flag(flag_name: String, value: Variant) -> void:
	quest_flags[flag_name] = value

## Get a quest flag, returning default if not set.
func get_quest_flag(flag_name: String, default_val: Variant = false) -> Variant:
	return quest_flags.get(flag_name, default_val)


func _ready() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	call_deferred("_load_display_settings")
	_apply_platform_content_scale()
	_reset_stats()

# ---------------------------------------------------------------------------
# New Game
# ---------------------------------------------------------------------------

## Start a fresh run with the given hero class and optional seed.
func new_game(chosen_class: int = ConstantsData.HeroClass.WARRIOR, seed_value: int = -1) -> void:
	# Clean up previous run state
	_cleanup_previous_run()
	if TurnManager != null and TurnManager.has_method("clear_actors"):
		TurnManager.clear_actors()
	if MessageLog != null and MessageLog.has_method("clear"):
		MessageLog.clear()
		MessageLog.current_turn = 0

	hero_class = chosen_class
	if party_classes.is_empty():
		set_party_classes([chosen_class])
	hero_subclass = ConstantsData.HeroSubclass.NONE
	depth = 0
	gold = 0
	score = 0
	run_active = true
	_level_cache.clear()
	pending_dropped_items.clear()
	quest_flags.clear()

	if seed_value < 0:
		run_seed = randi()
	else:
		run_seed = seed_value

	_reset_stats()
	if ItemAppearance:
		ItemAppearance.reset_for_new_run(run_seed)
	game_started.emit()

	# Immediately descend to depth 1.
	descend()


func _apply_platform_content_scale() -> void:
	var window: Window = get_window()
	if window == null:
		return
	if _is_mobile_web():
		window.content_scale_size = _get_mobile_content_scale_size()
	else:
		window.content_scale_size = DESKTOP_CONTENT_SCALE_SIZE


func set_mobile_orientation_mode(mode: String) -> void:
	mobile_orientation_mode = _normalize_mobile_orientation_mode(mode)
	_apply_platform_content_scale()


func get_mobile_orientation_mode() -> String:
	return mobile_orientation_mode


func save_display_settings() -> void:
	if SaveManager == null or not SaveManager.has_method("load_settings"):
		return
	var settings: Dictionary = SaveManager.load_settings()
	settings["mobile_orientation_mode"] = mobile_orientation_mode
	settings["zoom_level"] = zoom_level
	if SaveManager.has_method("save_settings"):
		SaveManager.save_settings(settings)


func _load_display_settings() -> void:
	if SaveManager != null and SaveManager.has_method("load_settings"):
		var settings: Dictionary = SaveManager.load_settings()
		mobile_orientation_mode = _normalize_mobile_orientation_mode(
			str(settings.get("mobile_orientation_mode", MOBILE_ORIENTATION_AUTO))
		)
		zoom_level = clampf(float(settings.get("zoom_level", zoom_level)), 1.0, 10.0)
	_apply_platform_content_scale()


func _is_mobile_web() -> bool:
	if OS.get_name() != "Web":
		return false
	if DisplayServer.is_touchscreen_available():
		return true
	var window: Window = get_window()
	if window != null:
		var window_size: Vector2i = window.size
		if window_size.y > window_size.x or mini(window_size.x, window_size.y) <= 720:
			return true
		if maxi(window_size.x, window_size.y) <= MOBILE_WEB_MAX_VIEWPORT:
			return true
	var js_result: Variant = JavaScriptBridge.eval(
		"(function(){return !!(navigator.maxTouchPoints > 0 || " +
		"matchMedia('(pointer: coarse)').matches || " +
		"/Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent));})()",
		true
	)
	return bool(js_result) if js_result is bool else false


func _get_mobile_content_scale_size() -> Vector2i:
	var browser_viewport_size: Vector2i = _get_mobile_web_viewport_size()
	if browser_viewport_size != Vector2i.ZERO:
		return _clamp_mobile_content_scale_size(browser_viewport_size)
	var mode: String = _normalize_mobile_orientation_mode(mobile_orientation_mode)
	if mode == MOBILE_ORIENTATION_PORTRAIT:
		return MOBILE_PORTRAIT_CONTENT_SCALE_SIZE
	if mode == MOBILE_ORIENTATION_LANDSCAPE:
		return MOBILE_LANDSCAPE_CONTENT_SCALE_SIZE
	var window: Window = get_window()
	if window != null and window.size.y > window.size.x:
		return MOBILE_PORTRAIT_CONTENT_SCALE_SIZE
	return MOBILE_LANDSCAPE_CONTENT_SCALE_SIZE


func _get_mobile_web_viewport_size() -> Vector2i:
	if OS.get_name() != "Web":
		return Vector2i.ZERO
	var js_result: Variant = JavaScriptBridge.eval(
		"(function(){var v=window.visualViewport;" +
		"var w=(v&&v.width)?v.width:window.innerWidth;" +
		"var h=(v&&v.height)?v.height:window.innerHeight;" +
		"return Math.round(w) + 'x' + Math.round(h);})()",
		true
	)
	var browser_size: Vector2i = _parse_mobile_web_viewport_size(js_result)
	if browser_size != Vector2i.ZERO:
		return browser_size
	var window: Window = get_window()
	if window != null and window.size.x > 0 and window.size.y > 0:
		return window.size
	return Vector2i.ZERO


static func _parse_mobile_web_viewport_size(js_result: Variant) -> Vector2i:
	if js_result is String:
		var parts: PackedStringArray = str(js_result).split("x")
		if parts.size() == 2:
			var width: int = int(parts[0])
			var height: int = int(parts[1])
			if width > 0 and height > 0:
				return Vector2i(width, height)
	return Vector2i.ZERO


func _clamp_mobile_content_scale_size(viewport_size: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(viewport_size.x, MOBILE_WEB_MIN_CONTENT_SCALE, MOBILE_WEB_MAX_CONTENT_SCALE),
		clampi(viewport_size.y, MOBILE_WEB_MIN_CONTENT_SCALE, MOBILE_WEB_MAX_CONTENT_SCALE)
	)


func _normalize_mobile_orientation_mode(mode: String) -> String:
	match mode:
		MOBILE_ORIENTATION_PORTRAIT, MOBILE_ORIENTATION_LANDSCAPE:
			return mode
		_:
			return MOBILE_ORIENTATION_AUTO


func _on_viewport_size_changed() -> void:
	if OS.get_name() == "Web" or mobile_orientation_mode == MOBILE_ORIENTATION_AUTO:
		_apply_platform_content_scale()


## Free stale Nodes from the previous run so nothing holds a freed-instance ref.
func _cleanup_previous_run() -> void:
	# Free hero nodes from the previous run
	for h: Variant in heroes:
		if is_instance_valid(h) and h is Node:
			(h as Node).free()
	heroes.clear()
	hero = null
	party_classes.clear()
	local_hero_index = 0

	# Free mobs cached in the level cache
	if current_level != null and current_level.get("mobs") != null:
		if current_level.has_method("deactivate_respawner"):
			current_level.deactivate_respawner(true)
		for mob: Variant in current_level.mobs:
			if is_instance_valid(mob) and mob is Node:
				(mob as Node).free()
		current_level.mobs.clear()
	current_level = null

	# Free mobs in cached levels
	for cached_depth: int in _level_cache.keys():
		var cached_data: Dictionary = _level_cache[cached_depth]
		if cached_data.has("mobs"):
			var cached_mobs: Variant = cached_data["mobs"]
			if cached_mobs is Array:
				for mob_data: Variant in cached_mobs:
					if is_instance_valid(mob_data) and mob_data is Node:
						(mob_data as Node).free()
	_level_cache.clear()

# ---------------------------------------------------------------------------
# Depth Navigation
# ---------------------------------------------------------------------------

## Move one floor deeper. Returns the new depth, or -1 if already at max.
func descend() -> int:
	if depth >= ConstantsData.MAX_DEPTH:
		return -1

	# Cache current level before leaving.
	_cache_current_level()

	depth += 1
	_on_depth_changed()
	return depth

## Move one floor higher (stairs up). Returns the new depth, or -1 if at surface.
func ascend() -> int:
	if depth <= 1:
		return -1

	_cache_current_level()

	depth -= 1
	_on_depth_changed()
	return depth

func _on_depth_changed() -> void:
	depth_changed.emit(depth)
	if EventBus:
		EventBus.level_changed.emit(depth)

## Cache the current level data so the player can return later.
func _cache_current_level() -> void:
	if current_level == null:
		return
	if current_level.has_method("serialize"):
		_level_cache[depth] = current_level.serialize()
	if current_level.has_method("deactivate_respawner"):
		current_level.deactivate_respawner(true)
	# Free mob Nodes from the departing level to prevent memory leak.
	# The serialized data is in the cache; these Node instances are no longer needed.
	if current_level.get("mobs") != null:
		for mob: Variant in current_level.mobs:
			if is_instance_valid(mob) and mob is Node:
				(mob as Node).free()
		current_level.mobs.clear()

# ---------------------------------------------------------------------------
# Party Helpers
# ---------------------------------------------------------------------------

## Return the canonical primary hero.
## This remains the compatibility path for single-player assumptions.
func get_primary_hero() -> Node:
	if hero != null and is_instance_valid(hero):
		return hero
	for candidate: Variant in heroes:
		if candidate != null and is_instance_valid(candidate):
			hero = candidate as Node
			return hero
	return null

## Return the hero currently focused by the local client/UI.
func get_focused_hero() -> Node:
	if heroes.is_empty():
		return get_primary_hero()
	if local_hero_index < 0 or local_hero_index >= heroes.size():
		local_hero_index = 0
	var candidate: Variant = heroes[local_hero_index]
	if candidate != null and is_instance_valid(candidate):
		return candidate as Node
	return get_primary_hero()

## Backwards-compatible alias for the current local/focused hero.
func get_local_hero() -> Node:
	return get_focused_hero()

## Return the hero currently owning the input/action phase.
func get_input_hero() -> Node:
	if TurnManager != null and TurnManager.has_method("get_input_hero"):
		var input_hero: Node = TurnManager.get_input_hero()
		if input_hero != null and is_instance_valid(input_hero):
			return input_hero
	return get_focused_hero()

## Return all valid party heroes.
func get_active_heroes() -> Array[Node]:
	var valid: Array[Node] = []
	for candidate: Variant in heroes:
		if candidate != null and is_instance_valid(candidate):
			valid.append(candidate as Node)
	return valid

func get_living_heroes() -> Array[Node]:
	var living: Array[Node] = []
	for candidate: Node in get_active_heroes():
		if candidate.get("is_alive") == true:
			living.append(candidate)
	return living

func get_local_owned_hero() -> Node:
	if NetworkManager == null or not NetworkManager.has_method("is_online_session") or not NetworkManager.is_online_session():
		return get_primary_hero()
	var local_peer_id: int = NetworkManager.get_local_peer_id() if NetworkManager.has_method("get_local_peer_id") else 1
	for candidate: Node in get_active_heroes():
		if int(ConstantsData.get_prop(candidate, "owner_peer_id", -1)) == local_peer_id:
			return candidate
	return get_primary_hero()

func is_local_player_spectating() -> bool:
	var owned_hero: Node = get_local_owned_hero()
	if owned_hero == null or owned_hero.get("is_alive") == true:
		return false
	var focused_hero: Node = get_focused_hero()
	return focused_hero != null and focused_hero != owned_hero and focused_hero.get("is_alive") == true

func are_all_heroes_dead() -> bool:
	var party: Array[Node] = get_active_heroes()
	if party.is_empty():
		return true
	for hero_node: Node in party:
		if hero_node.get("is_alive") == true:
			return false
	return true

func set_party_classes(classes: Array) -> void:
	party_classes.clear()
	for class_value: Variant in classes:
		if party_classes.size() >= MAX_PARTY_SIZE:
			break
		if class_value == null:
			continue
		party_classes.append(int(class_value))
	if party_classes.is_empty():
		party_classes.append(hero_class)
	hero_class = party_classes[0]

func get_party_classes() -> Array[int]:
	if party_classes.is_empty():
		set_party_classes([hero_class])
	return party_classes.duplicate()

func create_party_heroes() -> Array[Node]:
	var created: Array[Node] = []
	var hero_script: GDScript = load("res://src/actors/hero/hero.gd") as GDScript
	if hero_script == null:
		return created
	for class_id: int in get_party_classes():
		var hero_node: Node = hero_script.new()
		if hero_node.has_method("init_class"):
			hero_node.init_class(class_id)
		if hero_node.has_method("give_starting_items"):
			hero_node.give_starting_items()
		hero_node.set("pos", -1)
		created.append(hero_node)
	return created

func replace_party(hero_nodes: Array) -> void:
	for existing: Variant in heroes:
		if existing != null and is_instance_valid(existing) and existing is Node:
			(existing as Node).free()
	heroes.clear()
	hero = null
	local_hero_index = 0
	for hero_node: Variant in hero_nodes:
		if hero_node is Node and is_instance_valid(hero_node):
			add_hero(hero_node as Node)
	hero = get_primary_hero()
	if not party_classes.is_empty():
		hero_class = party_classes[0]

func get_hero_index(hero_node: Node) -> int:
	if hero_node == null:
		return -1
	for idx: int in range(heroes.size()):
		if heroes[idx] == hero_node:
			return idx
	return -1

## Register a hero into the current party.
## The first registered hero becomes the primary backwards-compatible hero.
func add_hero(hero_node: Node) -> void:
	if hero_node == null or not is_instance_valid(hero_node):
		return
	for existing: Variant in heroes:
		if existing == hero_node:
			if hero == null:
				hero = hero_node
			return
	heroes.append(hero_node)
	if hero == null:
		hero = hero_node
	if local_hero_index < 0:
		local_hero_index = 0
	if heroes.size() == 1:
		local_hero_changed.emit(hero_node, 0)

## Remove a hero from the current party and repair primary/local references.
func remove_hero(hero_node: Node) -> void:
	if hero_node == null:
		return
	for idx: int in range(heroes.size() - 1, -1, -1):
		if heroes[idx] == hero_node:
			heroes.remove_at(idx)
	if hero == hero_node:
		hero = null
	if local_hero_index >= heroes.size():
		local_hero_index = maxi(0, heroes.size() - 1)
	hero = get_primary_hero()
	local_hero_changed.emit(get_focused_hero(), local_hero_index)

## Explicitly choose which party hero the local UI is focused on.
func set_local_hero_index(index: int) -> void:
	if heroes.is_empty():
		local_hero_index = 0
		return
	var clamped_index: int = clampi(index, 0, heroes.size() - 1)
	if local_hero_index == clamped_index:
		return
	local_hero_index = clamped_index
	local_hero_changed.emit(get_focused_hero(), local_hero_index)

func cycle_local_hero_focus(step: int = 1) -> void:
	if heroes.is_empty():
		return
	var living_indices: Array[int] = []
	for idx: int in range(heroes.size()):
		var hero_node: Variant = heroes[idx]
		if hero_node != null and is_instance_valid(hero_node) and hero_node.get("is_alive") == true:
			living_indices.append(idx)
	if living_indices.size() <= 1:
		var next_index: int = posmod(local_hero_index + step, heroes.size())
		set_local_hero_index(next_index)
		return
	var current_living_index: int = living_indices.find(local_hero_index)
	if current_living_index < 0:
		current_living_index = 0
	var next_living_index: int = posmod(current_living_index + step, living_indices.size())
	set_local_hero_index(living_indices[next_living_index])

## Returns true if more than one hero is currently active in the party.
func is_party_run() -> bool:
	return get_active_heroes().size() > 1

## Check if a cached version of a level exists at the given depth.
func has_cached_level(target_depth: int) -> bool:
	return _level_cache.has(target_depth)

## Retrieve cached level data for a depth (or null).
func get_cached_level(target_depth: int) -> Variant:
	return _level_cache.get(target_depth)

# ---------------------------------------------------------------------------
# Gold
# ---------------------------------------------------------------------------

## Add gold and emit signals.
func add_gold(amount: int, collector_hero: Variant = null) -> void:
	gold += amount
	gold_changed.emit(gold)
	if EventBus:
		EventBus.gold_collected.emit(amount, gold)
	var collector: Variant = collector_hero
	if collector == null or not is_instance_valid(collector):
		collector = get_primary_hero()
	if amount > 0 and collector != null:
		var belongings: Variant = collector.get("belongings")
		var artifact: Variant = belongings.get_equipped_artifact() if belongings != null and belongings.has_method("get_equipped_artifact") else null
		if artifact != null and artifact.has_method("on_gold_pickup"):
			artifact.on_gold_pickup(amount)
	stats["gold_collected"] = stats.get("gold_collected", 0) + amount

## Spend gold. Returns true if the hero had enough.
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	if EventBus:
		EventBus.gold_collected.emit(-amount, gold)
	return true

# ---------------------------------------------------------------------------
# Fallen Items (upstream Chasm/Dungeon.dropToChasm)
# ---------------------------------------------------------------------------

## Queue an item to land on the next depth down, mirroring upstream
## `Dungeon.dropToChasm`. Items dropped past the last depth are lost.
func drop_to_chasm(item: Variant) -> void:
	if item == null or not item.has_method("serialize"):
		return
	var target_depth: int = depth + 1
	if target_depth > ConstantsData.MAX_DEPTH:
		return
	var list: Array = pending_dropped_items.get(target_depth, [])
	list.append(item.serialize())
	pending_dropped_items[target_depth] = list

## Take (and clear) the pending fallen items for a depth, reconstructed as live
## Item instances. Called by the level-arrival path (upstream switchLevel's
## droppedItems delivery).
func take_dropped_items(target_depth: int) -> Array:
	var list: Variant = pending_dropped_items.get(target_depth, null)
	if list == null:
		return []
	pending_dropped_items.erase(target_depth)
	var items: Array = []
	if list is Array:
		for data: Variant in list:
			if data is Dictionary:
				var item_id: String = str((data as Dictionary).get("item_id", ""))
				if item_id == "":
					continue
				var item: Item = Generator.create_item(item_id)
				if item != null:
					if item.has_method("deserialize"):
						item.deserialize(data as Dictionary)
					items.append(item)
	return items

# ---------------------------------------------------------------------------
# Run State Serialization
# ---------------------------------------------------------------------------

func serialize_run_state() -> Dictionary:
	return {
		"depth": depth,
		"gold": gold,
		"run_seed": run_seed,
		"score": score,
		"hero_class": hero_class,
		"hero_subclass": hero_subclass,
		"party_classes": get_party_classes(),
		"local_hero_index": local_hero_index,
		"run_active": run_active,
		"stats": stats.duplicate(true),
		"quest_flags": quest_flags.duplicate(true),
		"item_appearance": ItemAppearance.serialize() if ItemAppearance else {},
	}

func apply_run_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	depth = data.get("depth", 1)
	gold = data.get("gold", 0)
	run_seed = data.get("run_seed", 0)
	score = data.get("score", 0)
	hero_class = data.get("hero_class", ConstantsData.HeroClass.WARRIOR)
	hero_subclass = data.get("hero_subclass", ConstantsData.HeroSubclass.NONE)
	set_party_classes(data.get("party_classes", [hero_class]))
	local_hero_index = int(data.get("local_hero_index", 0))
	run_active = data.get("run_active", false)
	stats = data.get("stats", {})

	quest_flags.clear()
	var saved_quest_flags: Variant = data.get("quest_flags", {})
	if saved_quest_flags is Dictionary:
		for key: Variant in saved_quest_flags:
			quest_flags[str(key)] = saved_quest_flags[key]

	if ItemAppearance:
		var appearance_data: Dictionary = data.get("item_appearance", {})
		if appearance_data.is_empty():
			ItemAppearance.reset_for_new_run(run_seed)
		else:
			ItemAppearance.deserialize(appearance_data)

# ---------------------------------------------------------------------------
# Score
# ---------------------------------------------------------------------------

## Add to the score.
func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)

## Compute final score at run end (depth progress, gold, stats bonuses).
func compute_final_score() -> int:
	var final: int = score
	final += depth * 100
	final += gold / 10
	final += stats.get("enemies_slain", 0) * 10
	if depth >= ConstantsData.MAX_DEPTH:
		final += 5000  # victory bonus
	return final

# ---------------------------------------------------------------------------
# Statistics
# ---------------------------------------------------------------------------

func _reset_stats() -> void:
	stats = {
		"enemies_slain": 0,
		"items_collected": 0,
		"potions_used": 0,
		"scrolls_used": 0,
		"food_eaten": 0,
		"gold_collected": 0,
		"depths_explored": 0,
		"ankhs_used": 0,
		"bosses_slain": 0,
		"piranhas_slain": 0,
		"high_grass_searched": 0,
		"doors_opened": 0,
		"traps_triggered": 0,
		"damage_dealt": 0,
		"damage_taken": 0,
		"healing_done": 0,
	}

## Increment a stat by a given amount.
func record_stat(stat_name: String, amount: int = 1) -> void:
	stats[stat_name] = stats.get(stat_name, 0) + amount

# ---------------------------------------------------------------------------
# Region Helpers
# ---------------------------------------------------------------------------

## Return the region enum value for the current depth.
func current_region() -> int:
	return ConstantsData.region_for_depth(depth)

## Return the display name of the current region.
func current_region_name() -> String:
	return ConstantsData.region_name(current_region())

## Returns true if the current depth is a boss depth.
func is_boss_depth() -> bool:
	return depth in ConstantsData.BOSS_DEPTHS

# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

## End the current run. Called on hero death or victory.
func end_game(victory: bool) -> void:
	run_active = false
	if victory:
		score = compute_final_score()
		score_changed.emit(score)
	game_ended.emit(victory)
	
