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

# --- Run State ---
## The currently active level (RefCounted, not a Node).
var current_level: Variant = null
## Reference to the primary hero (backwards compat). Same as heroes[0].
var hero: Node = null
## All active heroes (multiplayer-ready). hero == heroes[0] for single-player.
var heroes: Array[Node] = []
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

# --- Statistics ---
var stats: Dictionary[String, int] = {}

# --- Visited Levels Cache ---
## Maps depth (int) -> saved level data (Dictionary) for backtracking.
var _level_cache: Dictionary[int, Dictionary] = {}

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
	_reset_stats()

# ---------------------------------------------------------------------------
# New Game
# ---------------------------------------------------------------------------

## Start a fresh run with the given hero class and optional seed.
func new_game(chosen_class: int = ConstantsData.HeroClass.WARRIOR, seed_value: int = -1) -> void:
	# Clean up previous run state
	_cleanup_previous_run()

	hero_class = chosen_class
	hero_subclass = ConstantsData.HeroSubclass.NONE
	depth = 0
	gold = 0
	score = 0
	run_active = true
	_level_cache.clear()
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


## Free stale Nodes from the previous run so nothing holds a freed-instance ref.
func _cleanup_previous_run() -> void:
	# Free hero nodes from the previous run
	for h: Variant in heroes:
		if is_instance_valid(h) and h is Node:
			(h as Node).free()
	heroes.clear()
	hero = null

	# Free mobs cached in the level cache
	if current_level != null and current_level.get("mobs") != null:
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
	# Free mob Nodes from the departing level to prevent memory leak.
	# The serialized data is in the cache; these Node instances are no longer needed.
	if current_level.get("mobs") != null:
		for mob: Variant in current_level.mobs:
			if is_instance_valid(mob) and mob is Node:
				(mob as Node).free()
		current_level.mobs.clear()

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
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	if EventBus:
		EventBus.gold_collected.emit(amount, gold)
	stats["gold_collected"] = stats.get("gold_collected", 0) + amount

## Spend gold. Returns true if the hero had enough.
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

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

const SAVE_PATH: String = "user://save_game.dat"

## Serialize the entire game state to a dictionary.
func _to_save_dict() -> Dictionary:
	return {
		"depth": depth,
		"gold": gold,
		"run_seed": run_seed,
		"score": score,
		"hero_class": hero_class,
		"hero_subclass": hero_subclass,
		"stats": stats.duplicate(),
		"run_active": run_active,
		"item_appearance": ItemAppearance.serialize() if ItemAppearance else {},
		"level_cache_keys": _level_cache.keys(),
		# Hero and level data would be serialized by their own systems.
	}

## Save the current game to disk.
func save_game() -> bool:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameManager: Failed to open save file for writing.")
		return false
	var data: Dictionary = _to_save_dict()
	file.store_var(data)
	file.close()
	if EventBus:
		EventBus.game_saved.emit()
	return true

## Load a saved game from disk. Returns true on success.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("GameManager: No save file found.")
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameManager: Failed to open save file for reading.")
		return false
	var data: Variant = file.get_var()
	file.close()
	if data == null or not data is Dictionary:
		push_error("GameManager: Save data is corrupt.")
		return false

	var save: Dictionary = data as Dictionary
	depth = save.get("depth", 1)
	gold = save.get("gold", 0)
	run_seed = save.get("run_seed", 0)
	score = save.get("score", 0)
	hero_class = save.get("hero_class", ConstantsData.HeroClass.WARRIOR)
	hero_subclass = save.get("hero_subclass", ConstantsData.HeroSubclass.NONE)
	stats = save.get("stats", {})
	run_active = save.get("run_active", false)
	if ItemAppearance:
		var appearance_data: Dictionary = save.get("item_appearance", {})
		if appearance_data.is_empty():
			ItemAppearance.reset_for_new_run(run_seed)
		else:
			ItemAppearance.deserialize(appearance_data)

	if EventBus:
		EventBus.game_loaded.emit()
	return true

## End the current run. Called on hero death or victory.
func end_game(victory: bool) -> void:
	run_active = false
	if victory:
		score = compute_final_score()
		score_changed.emit(score)
	game_ended.emit(victory)

## Delete the save file (permadeath).
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

## Check whether a save file exists.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
	
