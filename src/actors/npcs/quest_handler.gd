class_name QuestHandler
extends RefCounted
## Static quest tracker that manages NPC quest spawning and state across a run.
## Tracks which quests are active/complete and handles mob-defeat routing to
## active quest NPCs. Designed as a static utility — no instance needed.

# --- Quest State (static, reset per run) ---
## Maps quest_id -> status ("inactive", "active", "complete")
static var quest_states: Dictionary[String, String] = {}
## References to active quest NPCs for event routing.
## NOTE: Cannot use Array[NPC] for static vars in GDScript — typed arrays of
## custom classes in static context cause issues. Using Array[Variant] instead.
static var active_npcs: Array[Variant] = []
## Whether the quest system has been initialized this run.
static var _initialized: bool = false

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Reset all quest state for a new run. Call at game start.
static func reset() -> void:
	quest_states = {
		"ghost_quest": "inactive",
		"wandmaker_quest": "inactive",
		"blacksmith_quest": "inactive",
		"imp_quest": "inactive",
	}
	active_npcs.clear()
	_initialized = true

# ---------------------------------------------------------------------------
# Quest Depth Detection
# ---------------------------------------------------------------------------

## Single source of truth for quest spawn windows.
## Original uses probabilistic spawning: Random.Int(guaranteed_by - depth) == 0
## within [min_depth, max_depth], so odds run 33%/50%/100% across each window
## (Ghost/Wandmaker/Blacksmith/Imp Quest.spawn). Each quest is guaranteed to
## spawn by the last eligible depth. Windows must not overlap.
const QUEST_WINDOWS: Array[Dictionary] = [
	{"id": "ghost_quest", "min_depth": 2, "max_depth": 4, "guaranteed_by": 5},
	{"id": "wandmaker_quest", "min_depth": 7, "max_depth": 9, "guaranteed_by": 10},
	{"id": "blacksmith_quest", "min_depth": 12, "max_depth": 14, "guaranteed_by": 15},
	{"id": "imp_quest", "min_depth": 17, "max_depth": 19, "guaranteed_by": 20},
]

## Roll which quest (if any) should spawn on the given depth. Returns the
## quest id or "" when none. This is the only depth gate; spawn_quest_npc
## consumes the result, so the gate and the spawn dispatch cannot diverge.
static func _roll_quest_for_depth(depth: int) -> String:
	if not _initialized:
		reset()
	for window: Dictionary in QUEST_WINDOWS:
		if depth < int(window["min_depth"]) or depth > int(window["max_depth"]):
			continue
		if not _quest_available(str(window["id"])):
			continue
		if randi() % (int(window["guaranteed_by"]) - depth) == 0:
			return str(window["id"])
	return ""

## Returns true if a quest has not yet been spawned or completed.
static func _quest_available(quest_id: String) -> bool:
	if not _initialized:
		reset()
	var status: String = quest_states.get(quest_id, "inactive")
	return status == "inactive"

# ---------------------------------------------------------------------------
# NPC Spawning
# ---------------------------------------------------------------------------

## Roll the depth gate and spawn the matching quest NPC. Returns the NPC, or
## null if no quest should spawn on this depth. The caller is responsible for
## placing the NPC on the level at a valid position.
static func spawn_quest_npc(level_ref: Variant, depth: int) -> Variant:
	var quest_id: String = _roll_quest_for_depth(depth)
	if quest_id == "":
		return null

	var npc: Variant = null
	match quest_id:
		"ghost_quest":
			npc = _spawn_ghost(level_ref, depth)
		"wandmaker_quest":
			npc = _spawn_wandmaker(level_ref, depth)
		"blacksmith_quest":
			npc = _spawn_blacksmith(level_ref, depth)
		"imp_quest":
			npc = _spawn_imp(level_ref, depth)

	if npc != null:
		_register_npc(npc)

	return npc

static func _spawn_ghost(level_ref: Variant, _depth: int) -> Variant:
	var ghost: Variant = load("res://src/actors/npcs/ghost.gd").new()
	ghost.level = level_ref
	ghost.generate_quest()
	quest_states["ghost_quest"] = "active"
	# Original: quest mob is spawned on first interaction, not at level gen.
	# Ghost._spawn_quest_mob() handles this when the hero first talks to it.
	return ghost

static func _spawn_wandmaker(level_ref: Variant, _depth: int) -> Variant:
	var wm_script: GDScript = load("res://src/actors/npcs/wandmaker.gd")
	var wm: Variant = wm_script.new()
	wm.level = level_ref
	wm.generate_quest()
	quest_states["wandmaker_quest"] = "active"

	# Spawn the quest seed item on this level
	var seed_item: Variant = wm_script.create_quest_item(wm.requested_seed_id)
	if level_ref and level_ref.has_method("drop_item"):
		var item_pos: int = _find_spawn_pos(level_ref)
		if item_pos >= 0:
			level_ref.drop_item(item_pos, seed_item)

	return wm

static func _spawn_blacksmith(level_ref: Variant, _depth: int) -> Variant:
	var smith: Variant = load("res://src/actors/npcs/blacksmith.gd").new()
	smith.level = level_ref
	quest_states["blacksmith_quest"] = "active"
	# Dark gold ore drops from bats naturally — handled by bat loot tables
	return smith

static func _spawn_imp(level_ref: Variant, _depth: int) -> Variant:
	var imp: Variant = load("res://src/actors/npcs/imp.gd").new()
	imp.level = level_ref
	imp.generate_quest()
	quest_states["imp_quest"] = "active"
	return imp

# ---------------------------------------------------------------------------
# NPC Registration & Event Routing
# ---------------------------------------------------------------------------

static func _register_npc(npc: Variant) -> void:
	if npc not in active_npcs:
		active_npcs.append(npc)
	# Connect to EventBus mob_defeated signal for quest tracking
	if EventBus and not EventBus.mob_defeated.is_connected(_on_mob_defeated):
		EventBus.mob_defeated.connect(_on_mob_defeated)

## Route mob defeat events to active quest NPCs that track kills.
static func _on_mob_defeated(mob_pos: int, mob_name_str: String, mob_id: String) -> void:
	for npc: Variant in active_npcs:
		if npc == null:
			continue
		if npc.has_method("on_mob_defeated"):
			npc.on_mob_defeated(mob_pos, mob_name_str, mob_id)

## Unregister an NPC (called when quest is complete and NPC departs).
static func unregister_npc(npc: Variant) -> void:
	active_npcs.erase(npc)

## Mark a quest as complete.
static func complete_quest(quest_id: String) -> void:
	quest_states[quest_id] = "complete"

## Get the status of a quest.
static func get_quest_status(quest_id: String) -> String:
	if not _initialized:
		reset()
	return quest_states.get(quest_id, "inactive")

# ---------------------------------------------------------------------------
# Shopkeeper Spawning (separate from quests)
# ---------------------------------------------------------------------------

## Shop depths: one shop per region, on the first floor of each new region.
## Original SPD: Sewers->Prison: 6, Prison->Caves: 11, Caves->City: 16, City->Halls: 21
const SHOP_DEPTHS: Array[int] = [6, 11, 16, 21]

## Returns true if this depth should have a shopkeeper.
static func is_shop_depth(depth: int) -> bool:
	return depth in SHOP_DEPTHS

## Spawn a shopkeeper for the given depth. Returns the Shopkeeper instance.
static func spawn_shopkeeper(level_ref: Variant, depth: int) -> Variant:
	var keeper: Variant = load("res://src/actors/npcs/shopkeeper.gd").new()
	keeper.level = level_ref
	keeper.stock_shop(depth)
	return keeper

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

## Find a random passable position on the level for NPC/item placement.
static func _find_spawn_pos(level_ref: Variant) -> int:
	if level_ref == null:
		return -1
	# Try up to 100 random positions. Validates: passable, no char, not entrance,
	# not exit, not on trap, not EMPTY_SP. Matches original spawn validation.
	for _attempt: int in range(100):
		var candidate: int = randi() % ConstantsData.LENGTH
		if not (level_ref.has_method("is_passable") and level_ref.is_passable(candidate)):
			continue
		if level_ref.has_method("find_char_at") and level_ref.find_char_at(candidate) != null:
			continue
		# Avoid entrance and exit
		if level_ref.has_method("get_entrance") and candidate == level_ref.get_entrance():
			continue
		if level_ref.has_method("get_exit") and candidate == level_ref.get_exit():
			continue
		# Avoid traps
		if level_ref.has_method("trap_at") and level_ref.trap_at(candidate) != null:
			continue
		# Avoid EMPTY_SP terrain (shop pedestals, special floor)
		if level_ref.has_method("get_terrain"):
			var terrain: int = level_ref.get_terrain(candidate)
			if terrain == ConstantsData.Terrain.EMPTY_SP:
				continue
		return candidate
	return -1

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

static func serialize() -> Dictionary:
	return {
		"quest_states": quest_states.duplicate(),
		"initialized": _initialized,
	}

static func deserialize(data: Dictionary) -> void:
	reset()
	if data.has("quest_states") and data["quest_states"] is Dictionary:
		for key: String in (data["quest_states"] as Dictionary).keys():
			quest_states[key] = str((data["quest_states"] as Dictionary)[key])
	_initialized = data.get("initialized", true) as bool
