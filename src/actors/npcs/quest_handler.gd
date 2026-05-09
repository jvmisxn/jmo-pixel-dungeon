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

## Returns true if the given depth can spawn a quest NPC.
## Original uses probabilistic spawning: Random.Int(N - depth) == 0
## Ghost: Random.Int(5 - depth) == 0 for depth 2-4 -> 33%/50%/100%
## Wandmaker: Random.Int(10 - depth) == 0 for depth 7-9 -> 33%/50%/100%
## Blacksmith: Random.Int(15 - depth) == 0 for depth 12-14 -> 33%/50%/100%
## Imp: Random.Int(20 - depth) == 0 for depth 17-19 -> 33%/50%/100%
## Each quest is guaranteed to spawn by the last eligible depth.
static func is_quest_depth(depth: int) -> bool:
	# Sad Ghost: Sewers depth 2-4
	if depth >= 2 and depth <= 4 and _quest_available("ghost_quest"):
		return randi() % (5 - depth) == 0
	# Wandmaker: Prison depth 7-9
	if depth >= 7 and depth <= 9 and _quest_available("wandmaker_quest"):
		return randi() % (10 - depth) == 0
	# Blacksmith: Caves depth 12-14
	if depth >= 12 and depth <= 14 and _quest_available("blacksmith_quest"):
		return randi() % (15 - depth) == 0
	# Imp: City depth 17-19
	if depth >= 17 and depth <= 19 and _quest_available("imp_quest"):
		return randi() % (20 - depth) == 0
	return false

## Returns true if a quest has not yet been spawned or completed.
static func _quest_available(quest_id: String) -> bool:
	if not _initialized:
		reset()
	var status: String = quest_states.get(quest_id, "inactive")
	return status == "inactive"

# ---------------------------------------------------------------------------
# NPC Spawning
# ---------------------------------------------------------------------------

## Spawn the appropriate quest NPC for the given depth. Returns the NPC, or null
## if no quest should spawn on this depth. The caller is responsible for placing
## the NPC on the level at a valid position.
static func spawn_quest_npc(level_ref: Variant, depth: int) -> Variant:
	if not _initialized:
		reset()

	if not is_quest_depth(depth):
		return null

	var npc: Variant = null

	# Sad Ghost — Sewers (depth 2-4)
	if depth >= 2 and depth <= 4 and _quest_available("ghost_quest"):
		npc = _spawn_ghost(level_ref, depth)

	# Wandmaker — Prison (depth 7-9)
	elif depth >= 7 and depth <= 9 and _quest_available("wandmaker_quest"):
		npc = _spawn_wandmaker(level_ref, depth)

	# Blacksmith — Caves (depth 12-14)
	elif depth >= 12 and depth <= 14 and _quest_available("blacksmith_quest"):
		npc = _spawn_blacksmith(level_ref, depth)

	# Imp — City (depth 17-19)
	elif depth >= 17 and depth <= 19 and _quest_available("imp_quest"):
		npc = _spawn_imp(level_ref, depth)

	if npc != null:
		_register_npc(npc)

	return npc

static func _spawn_ghost(level_ref: Variant, _depth: int) -> Variant:
	var ghost: Variant = load("res://src/actors/npcs/ghost.gd").new()
	ghost.level = level_ref
	quest_states["ghost_quest"] = "active"
	# Original: quest mob is spawned on first interaction, not at level gen.
	# Ghost._spawn_quest_mob() handles this when the hero first talks to it.
	return ghost

static func _spawn_wandmaker(level_ref: Variant, _depth: int) -> Variant:
	var wm_script: GDScript = load("res://src/actors/npcs/wandmaker.gd")
	var wm: Variant = wm_script.new()
	wm.level = level_ref
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
static func _on_mob_defeated(mob_pos: int, mob_name_str: String) -> void:
	for npc: Variant in active_npcs:
		if npc == null:
			continue
		if npc.has_method("on_mob_defeated"):
			npc.on_mob_defeated(mob_pos, mob_name_str)

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
const SHOP_DEPTHS: Array[int] = [6, 11, 16, 20, 21]

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
	var npc_data: Array[Dictionary] = []
	for npc: Variant in active_npcs:
		if npc != null and npc.has_method("serialize"):
			npc_data.append(npc.serialize())
	return {
		"quest_states": quest_states.duplicate(),
		"active_npcs": npc_data,
		"initialized": _initialized,
	}

static func deserialize(data: Dictionary) -> void:
	reset()
	if data.has("quest_states") and data["quest_states"] is Dictionary:
		for key: String in (data["quest_states"] as Dictionary).keys():
			quest_states[key] = str((data["quest_states"] as Dictionary)[key])
	_initialized = data.get("initialized", true) as bool
