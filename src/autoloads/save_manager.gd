class_name SaveManagerNode
extends Node
## Dedicated save/load manager for full game state persistence.
## Handles complete game saves, rankings, and user settings.
## All paths use user:// for web (HTML5) export compatibility.

# --- File Paths ---
const SAVE_PATH: String = "user://save_game_full.dat"
const RANKINGS_PATH: String = "user://rankings.dat"
const SETTINGS_PATH: String = "user://settings.dat"

# --- Save Format Version (for future migration) ---
const SAVE_VERSION: int = 1

# ---------------------------------------------------------------------------
# Full Game Save / Load
# ---------------------------------------------------------------------------

## Save the complete game state: hero, level, GameManager, and all caches.
## Returns true on success.
func save_full_game() -> bool:
	var data: Dictionary = {
		"save_version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
	}

	# --- GameManager state ---
	data["game_manager"] = _serialize_game_manager()

	# --- Hero state ---
	data["hero"] = _serialize_hero()

	# --- Current level state ---
	data["current_level"] = _serialize_current_level()

	# --- Level cache (all visited levels) ---
	data["level_cache"] = _serialize_level_cache()

	# --- Quest state ---
	var _qh: GDScript = load("res://src/actors/npcs/quest_handler.gd")
	data["quest_state"] = _qh.serialize() if _qh.has_method("serialize") else {}

	# Write to disk
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to open save file for writing: %s" % FileAccess.get_open_error())
		return false

	file.store_var(data, true)  # full_objects = true for nested Dictionaries
	file.close()

	if EventBus:
		EventBus.game_saved.emit()
	return true


## Load a complete game state. Restores hero, level, GameManager, caches.
## Returns true on success.
func load_full_game() -> bool:
	if not has_save():
		push_warning("SaveManager: No save file found.")
		return false

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Failed to open save file for reading: %s" % FileAccess.get_open_error())
		return false

	var data: Variant = file.get_var(true)
	file.close()

	if data == null or not data is Dictionary:
		push_error("SaveManager: Save data is corrupt or unreadable.")
		return false

	var save: Dictionary = data as Dictionary

	# Check version for future migration
	var version: int = save.get("save_version", 0)
	if version > SAVE_VERSION:
		push_error("SaveManager: Save file is from a newer version (%d > %d)." % [version, SAVE_VERSION])
		return false

	# --- Restore GameManager state ---
	_deserialize_game_manager(save.get("game_manager", {}))

	# --- Restore level cache ---
	_deserialize_level_cache(save.get("level_cache", {}))

	# --- Restore current level ---
	_deserialize_current_level(save.get("current_level", {}))

	# --- Restore hero ---
	_deserialize_hero(save.get("hero", {}))

	# --- Restore quest state ---
	var quest_data: Variant = save.get("quest_state", {})
	if quest_data is Dictionary and not quest_data.is_empty():
		var _qh2: GDScript = load("res://src/actors/npcs/quest_handler.gd")
		if _qh2 and _qh2.has_method("deserialize"):
			_qh2.deserialize(quest_data)

	if EventBus:
		EventBus.game_loaded.emit()
	return true


## Check whether a full save file exists on disk.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Delete the save file (permadeath — run is over).
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# ---------------------------------------------------------------------------
# GameManager Serialization
# ---------------------------------------------------------------------------

func _serialize_game_manager() -> Dictionary:
	if GameManager == null:
		return {}
	return {
		"depth": GameManager.depth,
		"gold": GameManager.gold,
		"run_seed": GameManager.run_seed,
		"score": GameManager.score,
		"hero_class": GameManager.hero_class,
		"hero_subclass": GameManager.hero_subclass,
		"run_active": GameManager.run_active,
		"stats": GameManager.stats.duplicate(true),
		"item_appearance": ItemAppearance.serialize() if ItemAppearance else {},
	}


func _deserialize_game_manager(data: Dictionary) -> void:
	if GameManager == null or data.is_empty():
		return
	GameManager.depth = data.get("depth", 1)
	GameManager.gold = data.get("gold", 0)
	GameManager.run_seed = data.get("run_seed", 0)
	GameManager.score = data.get("score", 0)
	GameManager.hero_class = data.get("hero_class", ConstantsData.HeroClass.WARRIOR)
	GameManager.hero_subclass = data.get("hero_subclass", ConstantsData.HeroSubclass.NONE)
	GameManager.run_active = data.get("run_active", false)
	GameManager.stats = data.get("stats", {})
	if ItemAppearance:
		var appearance_data: Dictionary = data.get("item_appearance", {})
		if appearance_data.is_empty():
			ItemAppearance.reset_for_new_run(GameManager.run_seed)
		else:
			ItemAppearance.deserialize(appearance_data)


# ---------------------------------------------------------------------------
# Hero Serialization
# ---------------------------------------------------------------------------

func _serialize_hero() -> Dictionary:
	if GameManager == null or GameManager.hero == null:
		return {}
	if GameManager.hero.has_method("serialize"):
		return GameManager.hero.serialize()
	return {}


func _deserialize_hero(data: Dictionary) -> void:
	if GameManager == null or data.is_empty():
		return
	# Create hero if needed (cold start from saved game)
	if GameManager.hero == null:
		var hero_script: GDScript = load("res://src/actors/hero/hero.gd") as GDScript
		if hero_script:
			var hero: Node = hero_script.new()
			GameManager.hero = hero
			GameManager.heroes = [hero]
	if GameManager.hero != null and GameManager.hero.has_method("deserialize"):
		GameManager.hero.deserialize(data)


# ---------------------------------------------------------------------------
# Current Level Serialization
# ---------------------------------------------------------------------------

func _serialize_current_level() -> Dictionary:
	if GameManager == null or GameManager.current_level == null:
		return {}
	if GameManager.current_level.has_method("serialize"):
		var level_data: Dictionary = GameManager.current_level.serialize()
		# Level.serialize() already handles heaps, mobs, traps, and plants.
		# Only add blobs which Level doesn't serialize.
		level_data["blobs"] = _serialize_blobs()
		return level_data
	return {}


func _deserialize_current_level(data: Dictionary) -> void:
	if GameManager == null or data.is_empty():
		return
	# Create level if needed (cold start from saved game)
	if GameManager.current_level == null:
		GameManager.current_level = load("res://src/levels/level.gd").new()
	if GameManager.current_level.has_method("deserialize"):
		GameManager.current_level.deserialize(data)
	# Level.deserialize() handles heaps, mobs, traps, and plants.
	# Only handle blobs separately.
	_deserialize_blobs(data.get("blobs", []))


# ---------------------------------------------------------------------------
# Level Cache Serialization
# ---------------------------------------------------------------------------

func _serialize_level_cache() -> Dictionary:
	if GameManager == null:
		return {}
	var cache: Dictionary[int, Dictionary] = {}
	for depth_key: int in GameManager._level_cache:
		cache[depth_key] = GameManager._level_cache[depth_key]
	return cache


func _deserialize_level_cache(data: Dictionary) -> void:
	if GameManager == null:
		return
	GameManager._level_cache.clear()
	for depth_key in data:
		GameManager._level_cache[depth_key] = data[depth_key]


# ---------------------------------------------------------------------------
# Mobs Serialization
# ---------------------------------------------------------------------------

func _serialize_mobs() -> Array[Dictionary]:
	if GameManager == null or GameManager.current_level == null:
		return []
	var mobs_data: Array[Dictionary] = []
	if GameManager.current_level.get("mobs") != null:
		for mob in GameManager.current_level.mobs:
			if mob != null and mob.has_method("serialize"):
				mobs_data.append(mob.serialize())
	return mobs_data


func _deserialize_mobs(data: Array[Dictionary]) -> void:
	if GameManager == null or GameManager.current_level == null or data.is_empty():
		return
	# Clear existing mobs
	if GameManager.current_level.get("mobs") != null:
		GameManager.current_level.mobs.clear()
		for mob_data in data:
			if mob_data is Dictionary:
				# Attempt to reconstruct mob from saved type
				var mob_type: String = mob_data.get("type", "")
				var mob: Variant = _create_entity_by_type(mob_type, "mob")
				if mob != null and mob.has_method("deserialize"):
					mob.deserialize(mob_data)
					GameManager.current_level.mobs.append(mob)


# ---------------------------------------------------------------------------
# Heaps (Item piles) Serialization
# ---------------------------------------------------------------------------

func _serialize_heaps() -> Array[Dictionary]:
	if GameManager == null or GameManager.current_level == null:
		return []
	# Heaps are already Array[Dictionary], so just duplicate them
	var heaps_data: Array[Dictionary] = []
	for heap: Dictionary in GameManager.current_level.heaps:
		heaps_data.append(heap.duplicate(true))
	return heaps_data


func _deserialize_heaps(data: Array[Dictionary]) -> void:
	if GameManager == null or GameManager.current_level == null or data.is_empty():
		return
	GameManager.current_level.heaps.clear()
	for heap_data: Variant in data:
		if heap_data is Dictionary:
			GameManager.current_level.heaps.append(heap_data.duplicate(true))


# ---------------------------------------------------------------------------
# Traps Serialization
# ---------------------------------------------------------------------------

func _serialize_traps() -> Array[Dictionary]:
	if GameManager == null or GameManager.current_level == null:
		return []
	var traps_data: Array[Dictionary] = []
	# traps is Dictionary { pos: int -> Trap object }
	for pos: Variant in GameManager.current_level.traps:
		var trap: Variant = GameManager.current_level.traps[pos]
		if trap != null and trap.has_method("serialize"):
			var d: Dictionary = trap.serialize()
			d["pos"] = pos
			traps_data.append(d)
	return traps_data


func _deserialize_traps(data: Array[Dictionary]) -> void:
	if GameManager == null or GameManager.current_level == null or data.is_empty():
		return
	GameManager.current_level.traps.clear()
	for trap_data: Variant in data:
		if trap_data is Dictionary:
			var trap_type: String = trap_data.get("type", "")
			var trap_pos: int = trap_data.get("pos", -1)
			var trap: Variant = _create_entity_by_type(trap_type, "trap")
			if trap != null and trap.has_method("deserialize"):
				trap.deserialize(trap_data)
				if trap_pos >= 0:
					GameManager.current_level.traps[trap_pos] = trap


# ---------------------------------------------------------------------------
# Plants Serialization
# ---------------------------------------------------------------------------

func _serialize_plants() -> Array[Dictionary]:
	if GameManager == null or GameManager.current_level == null:
		return []
	var plants_data: Array[Dictionary] = []
	# plants is Dictionary { pos: int -> Plant object }
	for pos: Variant in GameManager.current_level.plants:
		var plant: Variant = GameManager.current_level.plants[pos]
		if plant != null and plant.has_method("serialize"):
			var d: Dictionary = plant.serialize()
			d["pos"] = pos
			plants_data.append(d)
	return plants_data


func _deserialize_plants(data: Array[Dictionary]) -> void:
	if GameManager == null or GameManager.current_level == null or data.is_empty():
		return
	GameManager.current_level.plants.clear()
	for plant_data: Variant in data:
		if plant_data is Dictionary:
			var plant_type: String = plant_data.get("type", "")
			var plant_pos: int = plant_data.get("pos", -1)
			var plant: Variant = _create_entity_by_type(plant_type, "plant")
			if plant != null and plant.has_method("deserialize"):
				plant.deserialize(plant_data)
				if plant_pos >= 0:
					GameManager.current_level.plants[plant_pos] = plant


# ---------------------------------------------------------------------------
# Blobs Serialization
# ---------------------------------------------------------------------------

func _serialize_blobs() -> Array[Dictionary]:
	if GameManager == null or GameManager.current_level == null:
		return []
	# blobs is Array[Dictionary], just duplicate them
	var blobs_data: Array[Dictionary] = []
	for blob: Dictionary in GameManager.current_level.blobs:
		blobs_data.append(blob.duplicate(true))
	return blobs_data


func _deserialize_blobs(data: Array[Dictionary]) -> void:
	if GameManager == null or GameManager.current_level == null or data.is_empty():
		return
	GameManager.current_level.blobs.clear()
	for blob_data: Variant in data:
		if blob_data is Dictionary:
			GameManager.current_level.blobs.append(blob_data.duplicate(true))


# ---------------------------------------------------------------------------
# Entity Factory Helper
# ---------------------------------------------------------------------------

## Attempt to create an entity by its type string. Returns null if unknown.
## This uses a simple mapping approach — entities store their class name in "type".
func _create_entity_by_type(type_name: String, category: String) -> Variant:
	if type_name.is_empty():
		return null

	# Try to find the class in Godot's global class registry
	# If the class has a class_name, we can instantiate it
	var script_path: String = _find_script_for_type(type_name, category)
	if script_path.is_empty():
		push_warning("SaveManager: Cannot find script for type '%s' in category '%s'" % [type_name, category])
		return null

	var script: Script = load(script_path) as Script
	if script == null:
		push_warning("SaveManager: Failed to load script at '%s'" % script_path)
		return null

	return script.new()


## Map type names to script paths. Provides a lookup for known entity types.
## This is populated based on the project's class structure.
func _find_script_for_type(type_name: String, category: String) -> String:
	# Build the path based on category and type_name conventions
	# Types are stored as PascalCase class names, file names are snake_case
	var snake_name: String = _pascal_to_snake(type_name)

	var search_dirs: Array[String] = []
	match category:
		"mob":
			search_dirs = [
				"res://src/actors/mobs/%s.gd" % snake_name,
				"res://src/actors/mobs/standard/%s.gd" % snake_name,
				"res://src/actors/mobs/bosses/%s.gd" % snake_name,
			]
		"trap":
			search_dirs = [
				"res://src/levels/traps/%s.gd" % snake_name,
			]
		"plant":
			search_dirs = [
				"res://src/plants/%s.gd" % snake_name,
			]
		"blob":
			search_dirs = [
				"res://src/actors/blobs/%s.gd" % snake_name,
			]
		"heap":
			search_dirs = [
				"res://src/items/%s.gd" % snake_name,
			]
		"item":
			search_dirs = [
				"res://src/items/%s.gd" % snake_name,
				"res://src/items/weapons/%s.gd" % snake_name,
				"res://src/items/armor/%s.gd" % snake_name,
				"res://src/items/potions/%s.gd" % snake_name,
				"res://src/items/scrolls/%s.gd" % snake_name,
				"res://src/items/rings/%s.gd" % snake_name,
				"res://src/items/wands/%s.gd" % snake_name,
				"res://src/items/artifacts/%s.gd" % snake_name,
				"res://src/items/food/%s.gd" % snake_name,
				"res://src/items/keys/%s.gd" % snake_name,
				"res://src/items/bags/%s.gd" % snake_name,
				"res://src/items/bombs/%s.gd" % snake_name,
				"res://src/items/stones/%s.gd" % snake_name,
				"res://src/items/spells/%s.gd" % snake_name,
			]

	for path in search_dirs:
		if ResourceLoader.exists(path):
			return path

	return ""


## Convert PascalCase to snake_case.
func _pascal_to_snake(pascal: String) -> String:
	var result: String = ""
	for i in pascal.length():
		var ch: String = pascal[i]
		if ch == ch.to_upper() and ch != ch.to_lower() and i > 0:
			result += "_"
		result += ch.to_lower()
	return result


# ---------------------------------------------------------------------------
# Rankings
# ---------------------------------------------------------------------------

## Save a ranking entry (appended to existing rankings list).
func save_ranking(entry: Dictionary) -> void:
	var rankings: Array[Dictionary] = load_rankings()
	# Ensure the entry has a timestamp
	if not entry.has("timestamp"):
		entry["timestamp"] = Time.get_unix_time_from_system()
	rankings.append(entry)
	# Sort by score descending
	rankings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("score", 0) > b.get("score", 0)
	)
	# Keep top 50
	if rankings.size() > 50:
		rankings.resize(50)

	var file: FileAccess = FileAccess.open(RANKINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to write rankings file.")
		return
	file.store_var(rankings, true)
	file.close()


## Load all ranking entries, sorted by score descending.
func load_rankings() -> Array[Dictionary]:
	if not FileAccess.file_exists(RANKINGS_PATH):
		return []
	var file: FileAccess = FileAccess.open(RANKINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Failed to read rankings file.")
		return []
	var data: Variant = file.get_var(true)
	file.close()
	if data == null or not data is Array:
		push_warning("SaveManager: Rankings data is corrupt, returning empty.")
		return []
	return data as Array


## Clear all rankings.
func clear_rankings() -> void:
	if FileAccess.file_exists(RANKINGS_PATH):
		DirAccess.remove_absolute(RANKINGS_PATH)


# ---------------------------------------------------------------------------
# Settings Persistence
# ---------------------------------------------------------------------------

## Save a settings dictionary to disk.
## Expected keys: sfx_volume, music_volume, sfx_muted, music_muted
func save_settings(settings: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to write settings file.")
		return
	file.store_var(settings, true)
	file.close()


## Load settings from disk. Returns a dictionary with default values if missing.
func load_settings() -> Dictionary:
	var defaults: Dictionary = {
		"sfx_volume": 0.8,
		"music_volume": 0.5,
		"sfx_muted": false,
		"music_muted": false,
	}

	if not FileAccess.file_exists(SETTINGS_PATH):
		return defaults

	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Failed to read settings file.")
		return defaults

	var data: Variant = file.get_var(true)
	file.close()

	if data == null or not data is Dictionary:
		push_warning("SaveManager: Settings data is corrupt, returning defaults.")
		return defaults

	var settings: Dictionary = data as Dictionary
	# Merge with defaults for any missing keys
	for key in defaults:
		if not settings.has(key):
			settings[key] = defaults[key]

	return settings


## Convenience: apply loaded settings to AudioManager.
func apply_settings_to_audio() -> void:
	var settings: Dictionary = load_settings()
	if AudioManager:
		AudioManager.set_sfx_volume(settings.get("sfx_volume", 0.8))
		AudioManager.set_music_volume(settings.get("music_volume", 1.0))

## Save audio settings to disk (called from settings window).
func save_audio_settings() -> void:
	var settings: Dictionary = load_settings()
	if AudioManager:
		settings["sfx_volume"] = AudioManager.get("sfx_volume") if AudioManager.get("sfx_volume") != null else 0.8
		settings["music_volume"] = AudioManager.get("music_volume") if AudioManager.get("music_volume") != null else 0.5
		settings["sfx_muted"] = AudioManager.get("sfx_muted") if AudioManager.get("sfx_muted") != null else false
		settings["music_muted"] = AudioManager.get("music_muted") if AudioManager.get("music_muted") != null else false
	save_settings(settings)
