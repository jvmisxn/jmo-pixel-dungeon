class_name SaveManagerNode
extends Node
## Dedicated save/load manager for full game state persistence.
## Handles complete game saves, rankings, and user settings.
## All paths use user:// for web (HTML5) export compatibility.

# --- File Paths ---
const SAVE_PATH: String = "user://save_game_full.dat"
const SAVE_TMP_PATH: String = "user://save_game_full.dat.tmp"
const SAVE_BAK_PATH: String = "user://save_game_full.dat.bak"
const RANKINGS_PATH: String = "user://rankings.dat"
const SETTINGS_PATH: String = "user://settings.dat"

# --- Save Format Version (for future migration) ---
# v2: Ring of Might no longer bakes its STR/HP bonus into the hero's persisted
#     base stats. Older saves un-bake the bonus during migration so the rebuilt
#     passive buff does not double-count it. See _migrate_might_ring_stats.
const SAVE_VERSION: int = 2

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED:
			autosave_if_active()

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
	data["heroes"] = _serialize_heroes()
	data["hero"] = _serialize_hero()

	# --- Current level state ---
	data["current_level"] = _serialize_current_level()

	# --- Level cache (all visited levels) ---
	data["level_cache"] = _serialize_level_cache()

	# --- Quest state ---
	var _qh: GDScript = load("res://src/actors/npcs/quest_handler.gd")
	data["quest_state"] = _qh.serialize() if _qh.has_method("serialize") else {}

	if not _write_atomic_var(SAVE_PATH, SAVE_TMP_PATH, SAVE_BAK_PATH, data):
		return false

	if EventBus:
		EventBus.game_saved.emit()
	return true


func autosave_if_active() -> bool:
	if GameManager == null or not GameManager.get("run_active"):
		return false
	if GameManager.current_level == null:
		return false
	var level_depth: int = int(GameManager.current_level.get("depth"))
	if level_depth != int(GameManager.depth):
		return false
	return save_full_game()


## Load a complete game state. Restores hero, level, GameManager, caches.
## Returns true on success.
func load_full_game() -> bool:
	if not has_save():
		push_warning("SaveManager: No save file found.")
		return false

	var save: Dictionary = _read_save_dictionary(SAVE_PATH)
	if save.is_empty() and FileAccess.file_exists(SAVE_BAK_PATH):
		push_warning("SaveManager: Primary save is unreadable, trying backup.")
		save = _read_save_dictionary(SAVE_BAK_PATH)
	if save.is_empty():
		push_error("SaveManager: Save data is corrupt or unreadable.")
		return false

	# Check version for future migration
	var version: int = save.get("save_version", 0)
	if version > SAVE_VERSION:
		push_error("SaveManager: Save file is from a newer version (%d > %d)." % [version, SAVE_VERSION])
		return false
	save = _migrate_save(save, version)

	# Start from a clean runtime state before rehydrating saved objects.
	if TurnManager != null and TurnManager.has_method("clear_actors"):
		TurnManager.clear_actors()
	if MessageLog != null and MessageLog.has_method("clear"):
		MessageLog.clear()
		MessageLog.current_turn = 0
	if GameManager != null and GameManager.has_method("_cleanup_previous_run"):
		GameManager._cleanup_previous_run()
	QuestHandler.reset()

	# --- Restore GameManager state ---
	_deserialize_game_manager(save.get("game_manager", {}))

	# --- Restore quest state before level/NPC reconstruction ---
	# Restored NPC instances re-register themselves during level deserialize.
	# QuestHandler must be initialized first so that registration is not wiped
	# by a later reset/deserialize call.
	var quest_data: Variant = save.get("quest_state", {})
	if quest_data is Dictionary and not quest_data.is_empty():
		var _qh2: GDScript = load("res://src/actors/npcs/quest_handler.gd")
		if _qh2 and _qh2.has_method("deserialize"):
			_qh2.deserialize(quest_data)

	# --- Restore level cache ---
	_deserialize_level_cache(save.get("level_cache", {}))

	# --- Restore current level ---
	_deserialize_current_level(save.get("current_level", {}))

	# --- Restore hero / party ---
	var heroes_data: Variant = save.get("heroes", [])
	if heroes_data is Array and not heroes_data.is_empty():
		_deserialize_heroes(heroes_data)
	else:
		_deserialize_hero(save.get("hero", {}))

	# Reattach restored heroes to the current level.
	if GameManager.current_level != null:
		for hero_node: Variant in GameManager.heroes:
			if hero_node != null and hero_node is Node:
				hero_node.set("level", GameManager.current_level)

	if EventBus:
		EventBus.game_loaded.emit()
	return true


## Check whether a full save file exists on disk.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_BAK_PATH)


## Delete the save file (permadeath — run is over).
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(SAVE_TMP_PATH):
		DirAccess.remove_absolute(SAVE_TMP_PATH)
	if FileAccess.file_exists(SAVE_BAK_PATH):
		DirAccess.remove_absolute(SAVE_BAK_PATH)


func _read_save_dictionary(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning(
			"SaveManager: Failed to open save file '%s' for reading: %s"
			% [path, FileAccess.get_open_error()]
		)
		return {}
	var data: Variant = file.get_var(true)
	file.close()
	if data == null or not data is Dictionary:
		push_warning("SaveManager: Save file '%s' did not contain a Dictionary." % path)
		return {}
	return data as Dictionary


func _write_atomic_var(
	path: String,
	tmp_path: String,
	bak_path: String,
	data: Variant
) -> bool:
	if FileAccess.file_exists(tmp_path):
		var tmp_remove_error: Error = DirAccess.remove_absolute(tmp_path)
		if tmp_remove_error != OK:
			push_error(
				"SaveManager: Failed to remove stale temp save '%s': %s"
				% [tmp_path, tmp_remove_error]
			)
			return false

	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to open temp save for writing: %s" % FileAccess.get_open_error())
		return false
	file.store_var(data, true)
	file.flush()
	file.close()

	if FileAccess.file_exists(bak_path):
		var bak_remove_error: Error = DirAccess.remove_absolute(bak_path)
		if bak_remove_error != OK:
			DirAccess.remove_absolute(tmp_path)
			push_error(
				"SaveManager: Failed to remove old backup save '%s': %s"
				% [bak_path, bak_remove_error]
			)
			return false

	if FileAccess.file_exists(path):
		var rotate_error: Error = DirAccess.rename_absolute(path, bak_path)
		if rotate_error != OK:
			DirAccess.remove_absolute(tmp_path)
			push_error("SaveManager: Failed to rotate existing save to backup: %s" % rotate_error)
			return false

	var promote_error: Error = DirAccess.rename_absolute(tmp_path, path)
	if promote_error != OK:
		if FileAccess.file_exists(bak_path) and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(bak_path, path)
		push_error("SaveManager: Failed to promote temp save into place: %s" % promote_error)
		return false
	return true


func _migrate_save(save: Dictionary, from_version: int) -> Dictionary:
	var migrated: Dictionary = save.duplicate(true)
	var version: int = from_version
	if version <= 0:
		version = 1

	while version < SAVE_VERSION:
		match version:
			1:
				# v1 -> v2: un-bake Ring of Might's STR/HP bonus from persisted
				# base stats (the old buff mutated them in place) so the rebuilt
				# passive does not double-apply on load.
				_migrate_v1_to_v2(migrated)
				version = 2
			_:
				push_warning("SaveManager: No migration step registered for save version %d." % version)
				version += 1

	migrated["save_version"] = SAVE_VERSION
	return migrated


## v1 -> v2 migration: strip the (formerly persisted) Ring of Might buff and
## remove its STR/HP contribution from each hero's saved base stats. STR un-bake
## is exact; HP un-bake reconstructs the base HT the multiplier was applied to,
## which is exact unless the hero levelled up while the ring was worn (a bounded,
## one-time HP discrepancy).
func _migrate_v1_to_v2(save: Dictionary) -> void:
	var hero_single: Variant = save.get("hero", null)
	if hero_single is Dictionary:
		_migrate_might_ring_stats(hero_single as Dictionary)
	var heroes: Variant = save.get("heroes", null)
	if heroes is Array:
		for hero_entry: Variant in heroes:
			if hero_entry is Dictionary:
				_migrate_might_ring_stats(hero_entry as Dictionary)


func _migrate_might_ring_stats(hero: Dictionary) -> void:
	# Drop any persisted Ring of Might buff; it is now rebuilt from the ring.
	var buffs: Variant = hero.get("buffs", null)
	if buffs is Array:
		var kept: Array = []
		for entry: Variant in buffs:
			if entry is Dictionary and str((entry as Dictionary).get("buff_id", "")) == "RingOfMight":
				continue
			kept.append(entry)
		hero["buffs"] = kept

	var belongings: Variant = hero.get("belongings", null)
	if not (belongings is Dictionary):
		return
	for slot_name: String in ["ring_left", "ring_right"]:
		var ring: Variant = (belongings as Dictionary).get(slot_name, null)
		if not (ring is Dictionary):
			continue
		if str((ring as Dictionary).get("item_id", "")) != "ring_of_might":
			continue
		var level: int = int((ring as Dictionary).get("level", 0))
		var cursed: bool = bool((ring as Dictionary).get("cursed", false))
		var ring_bonus: int = -1 if (cursed and level == 0) else level

		# STR: old buff added exactly ring_bonus.
		hero["str_val"] = int(hero.get("str_val", 10)) - ring_bonus

		# HP: old buff added int(base_ht * m) - base_ht, i.e. saved_ht = int(base_ht * m).
		var saved_ht: int = int(hero.get("ht", hero.get("hp_max", 0)))
		var multiplier: float = pow(1.035, float(maxi(0, ring_bonus)))
		var base_ht: int = _invert_ht_multiplier(saved_ht, multiplier)
		var hp_bonus: int = saved_ht - base_ht
		hero["ht"] = int(hero.get("ht", saved_ht)) - hp_bonus
		hero["hp_max"] = int(hero.get("hp_max", saved_ht)) - hp_bonus
		hero["hp"] = mini(int(hero.get("hp", 0)), int(hero["hp_max"]))
		# The old buff de-duplicated by id, so at most one Might bonus was ever
		# baked in even with two rings equipped; un-bake only once.
		return


## Recover the base HT the runtime multiplied to reach saved_ht, i.e. the largest
## base with int(base * multiplier) == saved_ht. Returns saved_ht when multiplier
## is <= 1 (no HP bonus was applied).
func _invert_ht_multiplier(saved_ht: int, multiplier: float) -> int:
	if multiplier <= 1.0 or saved_ht <= 0:
		return saved_ht
	var guess: int = int(float(saved_ht) / multiplier)
	for candidate: int in range(guess + 2, maxi(0, guess - 3), -1):
		if int(float(candidate) * multiplier) == saved_ht:
			return candidate
	return saved_ht


# ---------------------------------------------------------------------------
# GameManager Serialization
# ---------------------------------------------------------------------------

func _serialize_game_manager() -> Dictionary:
	if GameManager == null:
		return {}
	if GameManager.has_method("serialize_run_state"):
		return GameManager.serialize_run_state()
	return {
		"depth": GameManager.depth,
		"gold": GameManager.gold,
		"run_seed": GameManager.run_seed,
		"score": GameManager.score,
		"hero_class": GameManager.hero_class,
		"hero_subclass": GameManager.hero_subclass,
		"party_classes": GameManager.get_party_classes() if GameManager.has_method("get_party_classes") else [GameManager.hero_class],
		"local_hero_index": GameManager.local_hero_index,
		"run_active": GameManager.run_active,
		"stats": GameManager.stats.duplicate(true),
		"quest_flags": GameManager.quest_flags.duplicate(true),
		"item_appearance": ItemAppearance.serialize() if ItemAppearance else {},
	}


func _deserialize_game_manager(data: Dictionary) -> void:
	if GameManager == null or data.is_empty():
		return
	if GameManager.has_method("apply_run_state"):
		GameManager.apply_run_state(data)
		return
	GameManager.depth = data.get("depth", 1)
	GameManager.gold = data.get("gold", 0)
	GameManager.run_seed = data.get("run_seed", 0)
	GameManager.score = data.get("score", 0)
	GameManager.hero_class = data.get("hero_class", ConstantsData.HeroClass.WARRIOR)
	GameManager.hero_subclass = data.get("hero_subclass", ConstantsData.HeroSubclass.NONE)
	if GameManager.has_method("set_party_classes"):
		GameManager.set_party_classes(data.get("party_classes", [GameManager.hero_class]))
	GameManager.local_hero_index = int(data.get("local_hero_index", 0))
	GameManager.run_active = data.get("run_active", false)
	GameManager.stats = data.get("stats", {})
	GameManager.quest_flags = data.get("quest_flags", {})
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


func _serialize_heroes() -> Array[Dictionary]:
	if GameManager == null:
		return []
	var heroes_data: Array[Dictionary] = []
	var party: Array[Node] = GameManager.get_active_heroes() if GameManager.has_method("get_active_heroes") else GameManager.heroes
	for hero_node: Variant in party:
		if hero_node != null and hero_node.has_method("serialize"):
			heroes_data.append(hero_node.serialize())
	return heroes_data


func _deserialize_hero(data: Dictionary) -> void:
	if GameManager == null or data.is_empty():
		return
	for existing: Variant in GameManager.heroes:
		if existing != null and is_instance_valid(existing) and existing is Node:
			(existing as Node).free()
	GameManager.heroes.clear()
	GameManager.hero = null
	GameManager.local_hero_index = 0
	# Create hero if needed (cold start from saved game)
	if GameManager.hero == null:
		var hero_script: GDScript = load("res://src/actors/hero/hero.gd") as GDScript
		if hero_script:
			var hero: Node = hero_script.new()
			GameManager.hero = hero
			GameManager.heroes = [hero]
	if GameManager.hero != null and GameManager.hero.has_method("deserialize"):
		GameManager.hero.deserialize(data)
		if GameManager.has_method("set_party_classes"):
			GameManager.set_party_classes([GameManager.hero.get("hero_class")])


func _deserialize_heroes(data: Array) -> void:
	if GameManager == null or data.is_empty():
		return

	var hero_script: GDScript = load("res://src/actors/hero/hero.gd") as GDScript
	if hero_script == null:
		return

	for existing: Variant in GameManager.heroes:
		if existing != null and is_instance_valid(existing) and existing is Node:
			(existing as Node).free()
	GameManager.heroes.clear()
	GameManager.hero = null

	for hero_data: Variant in data:
		if not hero_data is Dictionary:
			continue
		var hero_node: Node = hero_script.new()
		if hero_node.has_method("deserialize"):
			hero_node.deserialize(hero_data)
		if GameManager.has_method("add_hero"):
			GameManager.add_hero(hero_node)
		else:
			GameManager.heroes.append(hero_node)

	GameManager.hero = GameManager.get_primary_hero() if GameManager.has_method("get_primary_hero") else (GameManager.heroes[0] if not GameManager.heroes.is_empty() else null)
	if not GameManager.heroes.is_empty():
		GameManager.local_hero_index = clampi(GameManager.local_hero_index, 0, GameManager.heroes.size() - 1)
	else:
		GameManager.local_hero_index = 0


# ---------------------------------------------------------------------------
# Current Level Serialization
# ---------------------------------------------------------------------------

func _serialize_current_level() -> Dictionary:
	if GameManager == null or GameManager.current_level == null:
		return {}
	if GameManager.current_level.has_method("serialize"):
		return GameManager.current_level.serialize()
	return {}


func _deserialize_current_level(data: Dictionary) -> void:
	if GameManager == null or data.is_empty():
		return
	# Create level if needed (cold start from saved game)
	if GameManager.current_level == null:
		var saved_depth: int = int(data.get("depth", GameManager.depth))
		GameManager.current_level = LevelFactory.instantiate_for_depth(saved_depth)
	if GameManager.current_level.has_method("deserialize"):
		GameManager.current_level.deserialize(data)


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
## Expected keys: sfx_volume, music_volume, sfx_muted, music_muted, mobile_orientation_mode
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
		"mobile_orientation_mode": "auto",
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
