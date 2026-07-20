class_name AmbImp
extends NPC
## The Ambitious Imp appears in the Dwarf City (depth 17-19). He asks the hero
## to defeat a number of a specific mob type — either monks or golems. On
## completion, the Imp grants access to a special ring shop.

# --- Quest Specifics ---
## Which mob type the imp wants killed: "monk" or "golem"
var quest_mob_id: String = ""
var quest_mob_name: String = ""
## Original uses DwarfToken items dropped by target mobs.
## Requires 5 tokens for monks, 4 for golems. We track kill count as equivalent.
var required_kills: int = 5
## Current kill count (equivalent to DwarfToken count).
var kill_count: int = 0

# --- Reward ---
var reward_given: bool = false
## Original: single Ring reward, random type, +2 upgrade, cursed (for identification).
var reward_ring: Variant = null

# --- First-sight yell ---
## Original Imp.act() yells "Hey!" when first seen by the hero, before quest is given.
var _seen_before: bool = false

# --- Ring Pool (for reward generation) ---
const RING_POOL: Array = [
	["ring_accuracy", "Ring of Accuracy"],
	["ring_elements", "Ring of Elements"],
	["ring_energy", "Ring of Energy"],
	["ring_evasion", "Ring of Evasion"],
	["ring_force", "Ring of Force"],
	["ring_furor", "Ring of Furor"],
	["ring_haste", "Ring of Haste"],
	["ring_might", "Ring of Might"],
	["ring_of_sharpshooting", "Ring of Sharpshooting"],
	["ring_tenacity", "Ring of Tenacity"],
	["ring_wealth", "Ring of Wealth"],
]

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func _init() -> void:
	super._init()
	npc_name = "Ambitious Imp"
	mob_name = npc_name
	mob_id = "ambitious_imp"
	quest_id = "imp_quest"
	description = "A tiny, sharply dressed imp with a merchant's grin."

	setup(1, 0, 0, 0, 0, 0, 1.0)

	# Original Imp has Property.IMMOVABLE — does not wander
	# Override wandering to stay in place (unlike Ghost which wanders)

	# Original Imp yells "Hey!" when first seen by the hero
	_seen_before = false

	dialogue_lines = [
		"Those %s are bad for business. Kill %d of them and I'll make it worth your while.",
		"Keep at it! %d down, %d to go.",
		"Excellent work! Here, take this ring as your reward.",
	]

	_pick_quest_target()
	_generate_reward()

# ---------------------------------------------------------------------------
# Turn System — Imp yells "Hey!" when first spotted by hero
# ---------------------------------------------------------------------------

## Original Imp.act() yells "Hey!" when first visible to the hero and quest
## hasn't been given yet. This draws attention to the NPC.
func act() -> void:
	# Original: yell only when not quest_given AND cell is visited AND heroFOV.
	# Reset seenBefore when quest IS given (hero walks away and returns).
	if not quest_active:
		var cell_visited: bool = level != null and level.has_method("is_visited") and level.is_visited(pos)
		if cell_visited:
			if not _seen_before and level.has_method("is_in_hero_fov") and level.is_in_hero_fov(pos):
				_seen_before = true
				_deliver_message("\"Hey!\" calls out a tiny imp.")
		# Fallback for levels without visited tracking
		elif not _seen_before and level and level.has_method("is_visible") and level.is_visible(pos):
			_seen_before = true
			_deliver_message("\"Hey!\" calls out a tiny imp.")
	else:
		_seen_before = false
	act_buffs()
	spend_turn()

# ---------------------------------------------------------------------------
# Quest Setup
# ---------------------------------------------------------------------------

func _pick_quest_target() -> void:
	# Original: depth 17=monks, depth 18=50/50, depth 19=golems
	var depth: int = GameManager.depth if GameManager else 18
	var alternative: bool  # true = monks, false = golems
	match depth:
		17:
			alternative = true
		19:
			alternative = false
		_:  # 18 or unknown
			alternative = (randi() % 2 == 0)

	if alternative:
		quest_mob_id = "monk"
		quest_mob_name = "monks"
		required_kills = 5
	else:
		quest_mob_id = "golem"
		quest_mob_name = "golems"
		required_kills = 4  # Original: golems only need 4 tokens

# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func interact(hero: Variant) -> void:
	if hero == null:
		return
	_remember_interacting_hero(hero)

	if reward_given:
		_deliver_message("The imp is gone.", "info", hero)
		return

	if quest_complete:
		_offer_reward(hero)
		return

	if quest_active:
		if kill_count >= required_kills:
			quest_complete = true
			_deliver_message(dialogue_lines[2], "info", hero)
			_offer_reward(hero)
		else:
			var remaining: int = required_kills - kill_count
			_deliver_message(dialogue_lines[1] % [kill_count, remaining], "info", hero)
		return

	# First interaction — give the quest
	quest_active = true
	# Original resets seenBefore when quest is given so the yell doesn't repeat
	_seen_before = false
	_deliver_message(dialogue_lines[0] % [quest_mob_name, required_kills], "info", hero)
	if EventBus:
		EventBus.quest_updated.emit(quest_id, "active")

# ---------------------------------------------------------------------------
# Kill Tracking
# ---------------------------------------------------------------------------

## Called by the quest system when a mob is defeated. Tracks kills for this quest.
## Original uses DwarfToken items dropped by target mobs. We use a kill counter
## as a simplified equivalent — functionally similar but without physical token items.
func on_mob_defeated(_mob_pos: int, mob_name_str: String, mob_id: String = "") -> void:
	if not quest_active or quest_complete:
		return
	# Match by mob_id (case-insensitive). The quest_mob_id is the singular form
	# (e.g., "monk" or "golem"), so we check if the killed mob's name matches.
	# Original checks `mob instanceof Monk` or `mob instanceof Golem`.
	var target_lower: String = quest_mob_id.to_lower()
	var defeated_id: String = mob_id.to_lower()
	var defeated_name: String = mob_name_str.to_lower()
	if defeated_id == target_lower or defeated_name == target_lower or defeated_name == target_lower + "s" or defeated_name.begins_with(target_lower):
		kill_count += 1
		if kill_count >= required_kills:
			_deliver_message("You've killed enough %s for the imp!" % quest_mob_name, "positive")
		elif kill_count % 2 == 0:
			# Periodic progress reminder (every 2 kills for better feedback)
			_deliver_message("Imp's quest: %d/%d %s slain." % [kill_count, required_kills, quest_mob_name], "info")

# ---------------------------------------------------------------------------
# Reward
# ---------------------------------------------------------------------------

func _generate_reward() -> void:
	var pick: Array = RING_POOL[randi() % RING_POOL.size()]
	var ring_id: String = pick[0]
	var normalized_id: String = ring_id
	if not normalized_id.begins_with("ring_of_"):
		normalized_id = normalized_id.replace("ring_", "ring_of_")
	reward_ring = Generator.create_item(normalized_id)
	if reward_ring == null:
		reward_ring = Ring.create(normalized_id)
	if reward_ring != null:
		reward_ring.identified = true
		reward_ring.cursed_known = true
		reward_ring.cursed = true
		if reward_ring.has_method("upgrade"):
			reward_ring.upgrade()
			reward_ring.upgrade()

func _offer_reward(hero: Variant) -> void:
	var rewards: Array = []
	if reward_ring != null:
		rewards.append(reward_ring)

	if rewards.is_empty():
		_deliver_message("The imp has nothing left to offer.")
		_depart()
		return

	if NetworkManager != null and NetworkManager.has_method("is_host") and NetworkManager.is_host():
		var owner_peer_id: int = int(ConstantsData.get_prop(hero, "owner_peer_id", 1))
		var local_peer_id: int = NetworkManager.get_local_peer_id() if NetworkManager.has_method("get_local_peer_id") else 1
		if owner_peer_id != local_peer_id:
			var reward_data: Array[Dictionary] = []
			for reward_item: Variant in rewards:
				if reward_item != null and reward_item.has_method("serialize"):
					reward_data.append(reward_item.serialize())
			if NetworkManager.has_method("send_ui_event_to_peer"):
				NetworkManager.send_ui_event_to_peer(owner_peer_id, {
					"type": "quest_reward_open",
					"hero_actor_id": int(ConstantsData.get_prop(hero, "actor_id", -1)),
					"npc_actor_id": int(ConstantsData.get_prop(self, "actor_id", -1)),
					"quest_name": "Imp's Gift",
					"quest_description": "Choose a ring as your reward.",
					"reward_items": reward_data,
				})
			return

	var wnd: Node = load("res://src/ui/windows/wnd_quest_reward.gd").new()
	wnd.setup("Imp's Gift", "Choose a ring as your reward.", rewards, hero, int(ConstantsData.get_prop(self, "actor_id", -1)))
	if wnd.has_signal("reward_chosen"):
		wnd.reward_chosen.connect(_on_reward_window_closed)

	if EventBus and EventBus.has_signal("show_window"):
		EventBus.show_window.emit(wnd)
	else:
		if hero and hero.get("belongings") != null:
			if hero.belongings.has_method("add_item"):
				hero.belongings.add_item(reward_ring)
		_deliver_message("You receive the %s." % reward_ring.item_name, "positive", hero)
		_on_reward_window_closed(reward_ring)

func _on_reward_window_closed(_chosen_item: Variant) -> void:
	reward_given = true
	if EventBus:
		EventBus.quest_updated.emit(quest_id, "complete")
	_deliver_message("The imp bows and vanishes in a puff of smoke.")
	_depart()

func _depart() -> void:
	is_alive = false
	deactivate()
	if QuestHandler:
		QuestHandler.unregister_npc(self)
		QuestHandler.complete_quest(quest_id)
	if level and level.has_method("remove_mob"):
		level.remove_mob(self)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["quest_mob_id"] = quest_mob_id
	data["quest_mob_name"] = quest_mob_name
	data["required_kills"] = required_kills
	data["kill_count"] = kill_count
	data["reward_given"] = reward_given
	data["_seen_before"] = _seen_before
	data["reward_ring"] = reward_ring.serialize() if reward_ring != null and reward_ring.has_method("serialize") else {}
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	quest_mob_id = str(data.get("quest_mob_id", quest_mob_id))
	quest_mob_name = str(data.get("quest_mob_name", quest_mob_name))
	required_kills = int(data.get("required_kills", required_kills))
	kill_count = int(data.get("kill_count", kill_count))
	reward_given = bool(data.get("reward_given", reward_given))
	_seen_before = bool(data.get("_seen_before", _seen_before))
	var reward_ring_data: Variant = data.get("reward_ring", {})
	if reward_ring_data is Dictionary and not (reward_ring_data as Dictionary).is_empty():
		var item_id: String = str((reward_ring_data as Dictionary).get("item_id", ""))
		if item_id != "":
			reward_ring = Generator.create_item(item_id)
			if reward_ring != null and reward_ring.has_method("deserialize"):
				reward_ring.deserialize(reward_ring_data as Dictionary)
