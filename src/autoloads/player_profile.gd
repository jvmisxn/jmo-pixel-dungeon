class_name PlayerProfileManager
extends Node
## Persistent player identity/profile used by title UI, rankings summaries,
## badge progress, and multiplayer display name.

signal profile_updated

const PROFILE_PATH: String = "user://player_profile.cfg"
const DEFAULT_PLAYER_NAME: String = "Player"
const DEFAULT_ICON_ID: String = "warrior"
const PROFILE_ICON_IDS: Array[String] = ["warrior", "mage", "rogue", "huntress", "duelist"]
const HERO_CLASS_KEYS: Array[String] = ["warrior", "mage", "rogue", "huntress", "duelist"]
const HERO_CLASS_ICON_IDS: Dictionary = {
	ConstantsData.HeroClass.WARRIOR: "warrior",
	ConstantsData.HeroClass.MAGE: "mage",
	ConstantsData.HeroClass.ROGUE: "rogue",
	ConstantsData.HeroClass.HUNTRESS: "huntress",
	ConstantsData.HeroClass.DUELIST: "duelist",
}

const ICON_UNLOCK_BADGES: Dictionary = {
	"warrior": "",
	"mage": "boss_slain_1",
	"rogue": "boss_slain_2",
	"huntress": "boss_slain_3",
	"duelist": "first_victory",
}

var player_name: String = ""
var profile_initialized: bool = false
var selected_icon_id: String = DEFAULT_ICON_ID
var unlocked_profile_icons: Dictionary[String, bool] = {
	DEFAULT_ICON_ID: true,
}
var unlocked_hero_classes: Dictionary[String, bool] = {
	"warrior": true,
}
var _run_surprise_attacks: int = 0
var _run_thrown_hits: int = 0

func _ready() -> void:
	_load_profile()
	_refresh_unlocks()
	_sync_network_name()
	if EventBus and EventBus.has_signal("badge_unlocked"):
		EventBus.badge_unlocked.connect(_on_badge_unlocked)
	if EventBus and EventBus.has_signal("item_used"):
		EventBus.item_used.connect(_on_item_used)
	if EventBus and EventBus.has_signal("item_equipped"):
		EventBus.item_equipped.connect(_on_item_equipped)
	if EventBus and EventBus.has_signal("game_event"):
		EventBus.game_event.connect(_on_game_event)
	if GameManager and GameManager.has_signal("game_started"):
		GameManager.game_started.connect(_reset_run_unlock_progress)
	if GameManager and GameManager.has_signal("game_ended"):
		GameManager.game_ended.connect(_on_game_ended)

func has_player_name() -> bool:
	return not player_name.strip_edges().is_empty()

func is_profile_complete() -> bool:
	return has_player_name()

func get_player_name() -> String:
	var trimmed_name: String = player_name.strip_edges()
	if trimmed_name.is_empty():
		return DEFAULT_PLAYER_NAME
	return trimmed_name

func set_player_name(new_name: String) -> void:
	player_name = new_name.strip_edges()
	if player_name.is_empty():
		player_name = DEFAULT_PLAYER_NAME
	profile_initialized = true
	_save_profile()
	_sync_network_name()
	profile_updated.emit()

func get_selected_icon_id() -> String:
	if not is_profile_icon_unlocked(selected_icon_id):
		selected_icon_id = DEFAULT_ICON_ID
	return selected_icon_id

func set_selected_icon_id(icon_id: String) -> void:
	if not is_profile_icon_unlocked(icon_id):
		return
	selected_icon_id = icon_id
	_save_profile()
	profile_updated.emit()

func cycle_selected_icon(step: int = 1) -> void:
	var unlocked_ids: Array[String] = get_unlocked_profile_icon_ids()
	if unlocked_ids.is_empty():
		return
	var current_index: int = unlocked_ids.find(get_selected_icon_id())
	if current_index < 0:
		current_index = 0
	var next_index: int = posmod(current_index + step, unlocked_ids.size())
	set_selected_icon_id(unlocked_ids[next_index])

func is_profile_icon_unlocked(icon_id: String) -> bool:
	return bool(unlocked_profile_icons.get(icon_id, false))

func get_unlocked_profile_icon_ids() -> Array[String]:
	var result: Array[String] = []
	for icon_id: String in PROFILE_ICON_IDS:
		if is_profile_icon_unlocked(icon_id):
			result.append(icon_id)
	return result

func unlock_profile_icon(icon_id: String) -> void:
	if not PROFILE_ICON_IDS.has(icon_id):
		return
	if is_profile_icon_unlocked(icon_id):
		return
	unlocked_profile_icons[icon_id] = true
	_save_profile()
	profile_updated.emit()

func is_hero_class_unlocked(hero_class: int) -> bool:
	var class_key: String = _hero_class_key(hero_class)
	return bool(unlocked_hero_classes.get(class_key, false))

func unlock_hero_class(hero_class: int) -> void:
	var class_key: String = _hero_class_key(hero_class)
	if class_key.is_empty() or is_hero_class_unlocked(hero_class):
		return
	unlocked_hero_classes[class_key] = true
	var icon_id: String = str(HERO_CLASS_ICON_IDS.get(hero_class, ""))
	if not icon_id.is_empty():
		unlocked_profile_icons[icon_id] = true
	_save_profile()
	profile_updated.emit()
	if MessageLog:
		MessageLog.add_positive("%s unlocked!" % HeroClassData.get_class_name_str(hero_class))

func get_hero_unlock_text(hero_class: int) -> String:
	match hero_class:
		ConstantsData.HeroClass.WARRIOR:
			return "Available from the start."
		ConstantsData.HeroClass.MAGE:
			return "Use a Scroll of Upgrade in a single run."
		ConstantsData.HeroClass.ROGUE:
			return "Perform 10 surprise attacks in a single run."
		ConstantsData.HeroClass.HUNTRESS:
			return "Hit 10 enemies with thrown weapons in a single run."
		ConstantsData.HeroClass.DUELIST:
			return "Equip an identified tier-2+ weapon with no strength penalty."
	return ""

func get_badge_summary() -> String:
	if Badges == null:
		return "Badges: 0/0"
	return "Badges: %d/%d" % [Badges.get_unlocked_count(), Badges.get_total_badge_count()]

func get_rankings_summary() -> Dictionary:
	var summary: Dictionary = {
		"runs": 0,
		"wins": 0,
		"best_score": 0,
		"best_depth": 0,
	}
	var rankings: Array[Dictionary] = []
	if SaveManager and SaveManager.has_method("load_rankings"):
		rankings = SaveManager.load_rankings()
	for entry: Variant in rankings:
		if not (entry is Dictionary):
			continue
		var ranking: Dictionary = entry
		summary["runs"] = int(summary["runs"]) + 1
		if bool(ranking.get("victory", false)):
			summary["wins"] = int(summary["wins"]) + 1
		summary["best_score"] = maxi(int(summary["best_score"]), int(ranking.get("score", 0)))
		summary["best_depth"] = maxi(int(summary["best_depth"]), int(ranking.get("depth", 0)))
	return summary

func _load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		player_name = ""
		profile_initialized = false
		return
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(PROFILE_PATH)
	if err != OK:
		player_name = ""
		profile_initialized = false
		return
	player_name = str(cfg.get_value("profile", "player_name", "")).strip_edges()
	profile_initialized = bool(cfg.get_value("profile", "initialized", false))
	selected_icon_id = str(cfg.get_value("profile", "selected_icon_id", DEFAULT_ICON_ID))
	var raw_icons: Variant = cfg.get_value("profile", "unlocked_profile_icons", {DEFAULT_ICON_ID: true})
	unlocked_profile_icons.clear()
	if raw_icons is Dictionary:
		for icon_key: Variant in raw_icons.keys():
			var icon_id: String = str(icon_key)
			if PROFILE_ICON_IDS.has(icon_id):
				unlocked_profile_icons[icon_id] = bool(raw_icons[icon_key])
	unlocked_profile_icons[DEFAULT_ICON_ID] = true
	var raw_classes: Variant = cfg.get_value("profile", "unlocked_hero_classes", {"warrior": true})
	unlocked_hero_classes.clear()
	if raw_classes is Dictionary:
		for class_key: Variant in raw_classes.keys():
			var class_name: String = str(class_key)
			if HERO_CLASS_KEYS.has(class_name):
				unlocked_hero_classes[class_name] = bool(raw_classes[class_key])
	unlocked_hero_classes["warrior"] = true

func _save_profile() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("profile", "player_name", player_name)
	cfg.set_value("profile", "initialized", profile_initialized)
	cfg.set_value("profile", "selected_icon_id", get_selected_icon_id())
	cfg.set_value("profile", "unlocked_profile_icons", unlocked_profile_icons.duplicate(true))
	cfg.set_value("profile", "unlocked_hero_classes", unlocked_hero_classes.duplicate(true))
	cfg.save(PROFILE_PATH)

func _sync_network_name() -> void:
	if NetworkManager and NetworkManager.has_method("set_local_player_name"):
		NetworkManager.set_local_player_name(get_player_name())

func _refresh_unlocks() -> void:
	var changed: bool = false
	for icon_id: String in PROFILE_ICON_IDS:
		if icon_id == DEFAULT_ICON_ID:
			unlocked_profile_icons[icon_id] = true
			continue
		var required_badge: String = str(ICON_UNLOCK_BADGES.get(icon_id, ""))
		if required_badge.is_empty():
			continue
		if Badges and Badges.has_method("is_unlocked") and Badges.is_unlocked(required_badge):
			if not is_profile_icon_unlocked(icon_id):
				unlocked_profile_icons[icon_id] = true
				changed = true
	for hero_class: int in HERO_CLASS_ICON_IDS.keys():
		if is_hero_class_unlocked(hero_class):
			var hero_icon_id: String = str(HERO_CLASS_ICON_IDS[hero_class])
			if not is_profile_icon_unlocked(hero_icon_id):
				unlocked_profile_icons[hero_icon_id] = true
				changed = true
	if not is_profile_icon_unlocked(selected_icon_id):
		selected_icon_id = DEFAULT_ICON_ID
		changed = true
	if changed:
		_save_profile()
		profile_updated.emit()

func _on_badge_unlocked(_badge_id: String) -> void:
	_refresh_unlocks()

func _on_item_used(item_name: String) -> void:
	if item_name == "Scroll of Upgrade":
		unlock_hero_class(ConstantsData.HeroClass.MAGE)

func _on_item_equipped(_item_name: String, slot: String) -> void:
	if slot != "weapon" or GameManager == null or not GameManager.has_method("get_local_hero"):
		return
	var hero: Variant = GameManager.get_local_hero()
	if hero == null or not is_instance_valid(hero):
		return
	var weapon: Variant = ConstantsData.get_prop(ConstantsData.get_prop(hero, "belongings", null), "weapon", null)
	if weapon == null:
		return
	var tier: int = int(ConstantsData.get_prop(weapon, "tier", 0))
	var str_requirement: int = int(weapon.get_str_requirement() if weapon.has_method("get_str_requirement") else ConstantsData.get_prop(weapon, "str_requirement", 99))
	var identified: bool = bool(weapon.is_identified() if weapon.has_method("is_identified") else true)
	var hero_str: int = int(ConstantsData.get_prop(hero, "str_val", 0))
	if identified and tier >= 2 and hero_str >= str_requirement:
		unlock_hero_class(ConstantsData.HeroClass.DUELIST)

func _on_game_event(event_name: String, _event_data: Dictionary) -> void:
	match event_name:
		"surprise_attack":
			_run_surprise_attacks += 1
			if _run_surprise_attacks >= 10:
				unlock_hero_class(ConstantsData.HeroClass.ROGUE)
		"thrown_weapon_hit":
			_run_thrown_hits += 1
			if _run_thrown_hits >= 10:
				unlock_hero_class(ConstantsData.HeroClass.HUNTRESS)

func _reset_run_unlock_progress() -> void:
	_run_surprise_attacks = 0
	_run_thrown_hits = 0

func _on_game_ended(_victory: bool) -> void:
	_reset_run_unlock_progress()

func _hero_class_key(hero_class: int) -> String:
	match hero_class:
		ConstantsData.HeroClass.WARRIOR:
			return "warrior"
		ConstantsData.HeroClass.MAGE:
			return "mage"
		ConstantsData.HeroClass.ROGUE:
			return "rogue"
		ConstantsData.HeroClass.HUNTRESS:
			return "huntress"
		ConstantsData.HeroClass.DUELIST:
			return "duelist"
	return ""
