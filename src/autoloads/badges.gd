class_name BadgesManager
extends Node
## Tracks and persists badge/achievement unlocks across all runs.
## Mirrors the badge system from Shattered Pixel Dungeon.

# --- Constants ---

const SAVE_PATH: String = "user://badges.dat"

## All hero class names used for tracking per-class wins.
const ALL_CLASSES: Array[String] = ["warrior", "mage", "rogue", "huntress", "duelist"]

## Boss mob_name values mapped to their badge IDs.
const BOSS_BADGE_MAP: Dictionary = {
	"Goo": "boss_slain_1",
	"Tengu": "boss_slain_2",
	"DM-300": "boss_slain_3",
	"King of Dwarves": "boss_slain_4",
	"Yog-Dzewa": "boss_slain_5",
}

## Number of potion types in the game.
const TOTAL_POTION_TYPES: int = 14
## Number of scroll types in the game.
const TOTAL_SCROLL_TYPES: int = 14

## Enemy slain thresholds for badges.
const ENEMIES_SLAIN_THRESHOLDS: Array[int] = [10, 50, 100, 250]

## Gold collected thresholds for badges.
const GOLD_THRESHOLDS: Array[int] = [500, 2500, 5000]

# --- Persistent State (survives across runs) ---

## badge_id -> { "unlocked_at": float, "class": String }
var _unlocked: Dictionary[String, Dictionary] = {}
## hero_class_name -> true for each class that has won the game.
var _class_wins: Dictionary[String, bool] = {}

# --- Per-Run Tracking (reset each game) ---

## Potion item_ids identified this run.
var _run_potions_identified: Dictionary[String, bool] = {}
## Scroll item_ids identified this run.
var _run_scrolls_identified: Dictionary[String, bool] = {}
## Whether the hero has worn armor this run.
var _run_armor_worn: bool = false
## Whether the hero has eaten food this run.
var _run_food_eaten: bool = false
## Number of piranhas slain this run.
var _run_piranhas_slain: int = 0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load()
	# EventBus signals
	EventBus.mob_defeated.connect(_on_mob_defeated)
	EventBus.hero_died.connect(_on_hero_died)
	EventBus.level_changed.connect(_on_level_changed)
	EventBus.gold_collected.connect(_on_gold_collected)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.item_used.connect(_on_item_used)
	EventBus.item_equipped.connect(_on_item_equipped)
	EventBus.hero_stats_changed.connect(_on_hero_stats_changed)
	# GameManager signals
	if GameManager:
		GameManager.game_started.connect(_on_game_started)
		GameManager.game_ended.connect(_on_game_ended)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Unlock a badge by ID. No-op if already unlocked.
func unlock(badge_id: String) -> void:
	if _unlocked.has(badge_id):
		return
	var hero_class_name: String = _current_hero_class_name()
	_unlocked[badge_id] = {
		"unlocked_at": Time.get_unix_time_from_system(),
		"class": hero_class_name,
	}
	_save()
	EventBus.badge_unlocked.emit(badge_id)
	if MessageLog:
		MessageLog.add_positive("Badge unlocked: %s" % get_badge_name(badge_id))

## Check if a badge has been unlocked.
func is_unlocked(badge_id: String) -> bool:
	return _unlocked.has(badge_id)

## Return a list of all unlocked badge IDs.
func get_all_unlocked() -> Array[String]:
	var result: Array[String] = []
	for key: String in _unlocked.keys():
		result.append(key)
	return result

## Return the unlock info dictionary for a badge, or null if not unlocked.
func get_unlock_info(badge_id: String) -> Variant:
	return _unlocked.get(badge_id)

## Return the total number of badges that can be earned.
func get_total_badge_count() -> int:
	return _ALL_BADGE_IDS.size()

## Return the number of badges currently unlocked.
func get_unlocked_count() -> int:
	return _unlocked.size()

## Return the display name for a badge.
func get_badge_name(badge_id: String) -> String:
	match badge_id:
		# Progress
		"first_victory":
			return "First Victory"
		"all_classes_won":
			return "Master of All"
		"boss_slain_1":
			return "Goo Slain"
		"boss_slain_2":
			return "Tengu Slain"
		"boss_slain_3":
			return "DM-300 Slain"
		"boss_slain_4":
			return "King Slain"
		"boss_slain_5":
			return "Yog-Dzewa Slain"
		"depth_10":
			return "Into the Caves"
		"depth_20":
			return "Into the Halls"
		# Combat
		"enemies_slain_10":
			return "Slayer I"
		"enemies_slain_50":
			return "Slayer II"
		"enemies_slain_100":
			return "Slayer III"
		"enemies_slain_250":
			return "Slayer IV"
		"piranhas_slain_5":
			return "Piranha Hunter"
		# Collection
		"all_potions_identified":
			return "Potion Expert"
		"all_scrolls_identified":
			return "Scroll Expert"
		"gold_collected_500":
			return "Gold Finder I"
		"gold_collected_2500":
			return "Gold Finder II"
		"gold_collected_5000":
			return "Gold Finder III"
		"items_collected_50":
			return "Hoarder"
		# Skill
		"no_armor_win":
			return "Naked Victory"
		"no_food_win":
			return "Fasting Victory"
		"champion_win":
			return "Champion"
		"strength_15":
			return "Mighty"
		# Death
		"first_death":
			return "First Blood"
		"death_by_goo":
			return "Goo's Victim"
	return badge_id.capitalize().replace("_", " ")

## Return the description for a badge.
func get_badge_description(badge_id: String) -> String:
	match badge_id:
		# Progress
		"first_victory":
			return "Win the game for the first time."
		"all_classes_won":
			return "Win the game with all five hero classes."
		"boss_slain_1":
			return "Defeat the Goo, boss of the Sewers."
		"boss_slain_2":
			return "Defeat Tengu, boss of the Prison."
		"boss_slain_3":
			return "Defeat DM-300, boss of the Caves."
		"boss_slain_4":
			return "Defeat the King of Dwarves, boss of the City."
		"boss_slain_5":
			return "Defeat Yog-Dzewa, boss of the Demon Halls."
		"depth_10":
			return "Reach depth 10."
		"depth_20":
			return "Reach depth 20."
		# Combat
		"enemies_slain_10":
			return "Slay 10 enemies in a single run."
		"enemies_slain_50":
			return "Slay 50 enemies in a single run."
		"enemies_slain_100":
			return "Slay 100 enemies in a single run."
		"enemies_slain_250":
			return "Slay 250 enemies in a single run."
		"piranhas_slain_5":
			return "Kill 5 piranhas in a single run."
		# Collection
		"all_potions_identified":
			return "Identify all 14 potion types in a single run."
		"all_scrolls_identified":
			return "Identify all 14 scroll types in a single run."
		"gold_collected_500":
			return "Collect 500 gold in a single run."
		"gold_collected_2500":
			return "Collect 2500 gold in a single run."
		"gold_collected_5000":
			return "Collect 5000 gold in a single run."
		"items_collected_50":
			return "Collect 50 items in a single run."
		# Skill
		"no_armor_win":
			return "Win the game without ever wearing armor."
		"no_food_win":
			return "Win the game without eating food."
		"champion_win":
			return "Win with every hero class at least once."
		"strength_15":
			return "Reach 15 strength in a single run."
		# Death
		"first_death":
			return "Die for the first time."
		"death_by_goo":
			return "Be slain by the Goo."
	return ""

## Reset per-run tracking variables. Called at the start of each new game.
func reset_run_tracking() -> void:
	_run_potions_identified.clear()
	_run_scrolls_identified.clear()
	_run_armor_worn = false
	_run_food_eaten = false
	_run_piranhas_slain = 0

## Called when the game is won to check victory-related badges.
func check_victory() -> void:
	unlock("first_victory")
	var hero_class_name: String = _current_hero_class_name()
	if not hero_class_name.is_empty():
		_class_wins[hero_class_name] = true
	# Check all classes won
	var all_won: bool = true
	for c: String in ALL_CLASSES:
		if not _class_wins.has(c):
			all_won = false
			break
	if all_won:
		unlock("all_classes_won")
		unlock("champion_win")
	# Skill badges — no armor / no food
	if not _run_armor_worn:
		unlock("no_armor_win")
	if not _run_food_eaten:
		unlock("no_food_win")
	_save()

## Notify the badge system that a potion type has been identified.
func notify_potion_identified(potion_id: String) -> void:
	_run_potions_identified[potion_id] = true
	if _run_potions_identified.size() >= TOTAL_POTION_TYPES:
		unlock("all_potions_identified")

## Notify the badge system that a scroll type has been identified.
func notify_scroll_identified(scroll_id: String) -> void:
	_run_scrolls_identified[scroll_id] = true
	if _run_scrolls_identified.size() >= TOTAL_SCROLL_TYPES:
		unlock("all_scrolls_identified")

# ---------------------------------------------------------------------------
# Signal Handlers
# ---------------------------------------------------------------------------

func _on_mob_defeated(_mob_pos: int, mob_name: String) -> void:
	# Boss badges
	if BOSS_BADGE_MAP.has(mob_name):
		unlock(BOSS_BADGE_MAP[mob_name])
	# Piranha tracking
	if mob_name.to_lower().contains("piranha"):
		_run_piranhas_slain += 1
		if _run_piranhas_slain >= 5:
			unlock("piranhas_slain_5")
	# Enemy slain thresholds (use GameManager stats)
	if GameManager:
		var slain: int = GameManager.stats.get("enemies_slain", 0)
		for threshold: int in ENEMIES_SLAIN_THRESHOLDS:
			if slain >= threshold:
				unlock("enemies_slain_%d" % threshold)

func _on_hero_died() -> void:
	unlock("first_death")
	# Check what killed the hero — look at current depth for boss death badges
	if GameManager and GameManager.depth == 5:
		# Could have died to Goo — we check if the boss is on this level
		# Use a heuristic: if depth is 5 and a boss fight was in progress
		unlock("death_by_goo")

func _on_level_changed(new_depth: int) -> void:
	if new_depth >= 10:
		unlock("depth_10")
	if new_depth >= 20:
		unlock("depth_20")

func _on_gold_collected(_amount: int, total: int) -> void:
	for threshold: int in GOLD_THRESHOLDS:
		if total >= threshold:
			unlock("gold_collected_%d" % threshold)

func _on_item_picked_up(_item_name: String) -> void:
	if GameManager:
		var collected: int = GameManager.stats.get("items_collected", 0)
		if collected >= 50:
			unlock("items_collected_50")

func _on_item_used(item_name: String) -> void:
	# Track food consumption
	var lower_name: String = item_name.to_lower()
	if lower_name.contains("ration") or lower_name.contains("pasty") \
			or lower_name.contains("meat") or lower_name.contains("food") \
			or lower_name.contains("berry") or lower_name.contains("blandfruit"):
		_run_food_eaten = true

func _on_item_equipped(_item_name: String, slot: String) -> void:
	# Track armor usage
	if slot == "armor" or slot == "body":
		_run_armor_worn = true

func _on_hero_stats_changed() -> void:
	# Check strength badge
	if GameManager and GameManager.hero:
		var str_val: Variant = GameManager.hero.get("str_val")
		if str_val is int and str_val >= 15:
			unlock("strength_15")

func _on_game_started() -> void:
	reset_run_tracking()

func _on_game_ended(victory: bool) -> void:
	if victory:
		check_victory()

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func _save() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("BadgesManager: Failed to open badges file for writing.")
		return
	var data: Dictionary = {
		"unlocked": _unlocked,
		"class_wins": _class_wins,
	}
	file.store_var(data, true)
	file.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("BadgesManager: Failed to open badges file for reading.")
		return
	var data: Variant = file.get_var(true)
	file.close()
	if data is Dictionary:
		var raw_unlocked: Variant = data.get("unlocked", {})
		if raw_unlocked is Dictionary:
			_unlocked.clear()
			for key: Variant in raw_unlocked.keys():
				_unlocked[str(key)] = raw_unlocked[key]
		var raw_wins: Variant = data.get("class_wins", {})
		if raw_wins is Dictionary:
			_class_wins.clear()
			for key: Variant in raw_wins.keys():
				_class_wins[str(key)] = true
	else:
		push_warning("BadgesManager: Badge data is corrupt, starting fresh.")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Return the current hero's class as a lowercase string name.
func _current_hero_class_name() -> String:
	if GameManager == null:
		return ""
	match GameManager.hero_class:
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

## Master list of all badge IDs for counting purposes.
const _ALL_BADGE_IDS: Array[String] = [
	# Progress
	"first_victory",
	"all_classes_won",
	"boss_slain_1",
	"boss_slain_2",
	"boss_slain_3",
	"boss_slain_4",
	"boss_slain_5",
	"depth_10",
	"depth_20",
	# Combat
	"enemies_slain_10",
	"enemies_slain_50",
	"enemies_slain_100",
	"enemies_slain_250",
	"piranhas_slain_5",
	# Collection
	"all_potions_identified",
	"all_scrolls_identified",
	"gold_collected_500",
	"gold_collected_2500",
	"gold_collected_5000",
	"items_collected_50",
	# Skill
	"no_armor_win",
	"no_food_win",
	"champion_win"
]
