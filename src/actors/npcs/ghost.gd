class_name SadGhost
extends NPC
## The Sad Ghost appears in the Sewers (depth 2-4). It asks the hero to avenge
## its death by slaying a specific quest mob spawned on the level. On completion,
## the ghost offers a choice between a weapon and a piece of armor.

# --- Quest Specifics ---
## The mob_id of the quest target that must be killed.
var quest_target_id: String = ""
## The display name of the quest target.
var quest_target_name: String = ""
## Whether the quest target has been slain.
var target_slain: bool = false

# --- Reward ---
var reward_weapon: Variant = null
var reward_armor: Variant = null
var reward_given: bool = false

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Whether the quest mob has been spawned on the level yet.
## Original spawns the quest mob on FIRST INTERACTION, not at NPC init time.
var quest_mob_spawned: bool = false

## 20% base chance for rewards to be enchanted (matching original)
var reward_enchanted: bool = false

func _init() -> void:
	super._init()
	npc_name = "Sad Ghost"
	mob_name = npc_name
	mob_id = "sad_ghost"
	quest_id = "ghost_quest"
	description = "A pale, translucent figure hovers mournfully."

	# Original Ghost is flying and wanders (not passive)
	flying = true
	state = AIState.WANDERING
	# Original Ghost has Property.LARGE to stick to exit room. We note this
	# but don't implement a full property system here.

	setup(1, 0, 0, 0, 0, 0, 1.0)

	# Connect to mob_defeated so we can track quest target kills
	if EventBus and EventBus.has_signal("mob_defeated"):
		if not EventBus.mob_defeated.is_connected(on_mob_defeated):
			EventBus.mob_defeated.connect(on_mob_defeated)

	dialogue_lines = [
		"Please... avenge me... slay the %s that took my life...",
		"The %s still lurks nearby... please, end it...",
		"You did it... thank you... take this as my gratitude.",
	]

	_pick_quest_target()
	_generate_rewards()

## Original Ghost moves at half speed.
func get_speed() -> float:
	return 0.5

## Ghost wanders on its own turn instead of using the passive NPC act loop.
func act() -> void:
	process_buffs()
	if paralysed > 0:
		spend_turn()
		return
	_wander()
	spend_move()

## Original Ghost.chooseEnemy() returns null — ghost never hunts.
func choose_enemy() -> Variant:
	return null

## Override wandering so Ghost cannot wander onto heaps or the level exit.
func _wander() -> void:
	if level == null:
		return
	var options: Array[int] = []
	for dir: int in ConstantsData.DIRS_8:
		var next_pos: int = pos + dir
		if not _can_move_to(next_pos):
			continue
		if level.has_method("heaps_at") and not level.heaps_at(next_pos).is_empty():
			continue
		if level.get("exit_pos") != null and next_pos == level.exit_pos:
			continue
		options.append(next_pos)
	if options.is_empty():
		return
	move_to(options[randi() % options.size()])

## Override _set_state: Ghost wanders (not passive like other NPCs, not hunting).
func _set_state(new_state: AIState) -> void:
	var applied_state: AIState = AIState.WANDERING
	if new_state == AIState.WANDERING or new_state == AIState.PASSIVE:
		applied_state = new_state
	if state == applied_state:
		return
	state = applied_state
	state_changed.emit(applied_state)

# ---------------------------------------------------------------------------
# Quest Setup
# ---------------------------------------------------------------------------

func _pick_quest_target() -> void:
	# Original: quest type is determined by dungeon depth (depth-1)
	# depth 2 = fetid rat, depth 3 = gnoll trickster, depth 4 = great crab
	# Since we don't know depth at init time, pick randomly among all 3
	var depth: int = GameManager.depth if GameManager else (randi() % 3 + 2)
	var quest_type: int = clampi(depth - 1, 1, 3)
	match quest_type:
		1:
			quest_target_id = "fetid_rat"
			quest_target_name = "Fetid Rat"
		2:
			quest_target_id = "gnoll_trickster"
			quest_target_name = "Gnoll Trickster"
		3, _:
			quest_target_id = "great_crab"
			quest_target_name = "Great Crab"

func _generate_rewards() -> void:
	# Original reward tiers: Random.chances([0, 0, 10, 6, 3, 1])
	# = 50%:T2, 30%:T3, 15%:T4, 5%:T5
	var tier_roll: float = randf()
	var reward_tier: int
	if tier_roll < 0.5:
		reward_tier = 2
	elif tier_roll < 0.8:
		reward_tier = 3
	elif tier_roll < 0.95:
		reward_tier = 4
	else:
		reward_tier = 5

	# Original upgrade levels: 50%:+0, 30%:+1, 15%:+2, 5%:+3
	var level_roll: float = randf()
	var item_level: int
	if level_roll < 0.5:
		item_level = 0
	elif level_roll < 0.8:
		item_level = 1
	elif level_roll < 0.95:
		item_level = 2
	else:
		item_level = 3

	# Original: 20% base chance for rewards to be enchanted
	# Generate outcome first so it doesn't affect RNG sequence
	reward_enchanted = randf() < 0.2

	# Generate a weapon reward using the proper tier
	var weapon_ids_by_tier: Dictionary = {
		2: ["shortsword", "hand_axe", "spear", "quarterstaff", "dirk"],
		3: ["sword", "mace", "scimitar", "round_shield", "sai"],
		4: ["longsword", "battle_axe", "flail", "runic_blade", "crossbow"],
		5: ["greatsword", "war_hammer", "glaive", "greataxe", "greatshield"],
	}
	var tier_weapons: Array = weapon_ids_by_tier.get(reward_tier, ["shortsword"])
	var picked_weapon_id: String = tier_weapons[randi() % tier_weapons.size()]
	reward_weapon = Generator.create_item(picked_weapon_id)
	if reward_weapon != null:
		reward_weapon.identified = true
		for _i: int in range(item_level):
			if reward_weapon.has_method("upgrade"):
				reward_weapon.upgrade()

	# Generate an armor reward using the proper tier
	var armor_ids_by_tier: Dictionary = {
		2: ["leather_armor"],
		3: ["mail_armor"],
		4: ["scale_armor"],
		5: ["plate_armor"],
	}
	var tier_armors: Array = armor_ids_by_tier.get(reward_tier, ["leather_armor"])
	var picked_armor_id: String = tier_armors[randi() % tier_armors.size()]
	reward_armor = Generator.create_item(picked_armor_id)
	if reward_armor != null:
		reward_armor.identified = true
		for _j: int in range(item_level):
			if reward_armor.has_method("upgrade"):
				reward_armor.upgrade()

# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func interact(hero: Variant) -> void:
	if hero == null:
		return
	_remember_interacting_hero(hero)
	if EventBus:
		EventBus.npc_interacted.emit(npc_name)

	if reward_given:
		_deliver_message("The ghost has already found peace.", "info", hero)
		return

	if quest_complete or target_slain:
		quest_complete = true
		_deliver_message(dialogue_lines[2], "info", hero)
		_offer_reward(hero)
		return

	if quest_active:
		_deliver_message(dialogue_lines[1] % quest_target_name, "info", hero)
		return

	quest_active = true
	if not quest_mob_spawned:
		_spawn_quest_mob()
	_deliver_message(dialogue_lines[0] % quest_target_name, "info", hero)
	if EventBus:
		EventBus.quest_updated.emit(quest_id, "active")

# ---------------------------------------------------------------------------
# Kill Tracking
# ---------------------------------------------------------------------------

func on_mob_defeated(_mob_pos: int, mob_name_str: String, mob_id: String = "") -> void:
	if not quest_active or reward_given or target_slain or quest_target_id == "":
		return
	var target_lower: String = quest_target_id.to_lower()
	var defeated_id: String = mob_id.to_lower()
	var defeated_name: String = mob_name_str.to_lower()
	if defeated_id == target_lower or defeated_name == target_lower or defeated_name.begins_with(target_lower):
		target_slain = true
		quest_complete = true
		_deliver_message("You have avenged the sad ghost.", "positive")
		if EventBus:
			EventBus.quest_updated.emit(quest_id, "complete")

# ---------------------------------------------------------------------------
# Quest Mob Spawning
# ---------------------------------------------------------------------------

func _spawn_quest_mob() -> void:
	if quest_mob_spawned or level == null:
		return
	var mob: Mob = MobFactory.create_mob(quest_target_id)
	if mob == null:
		return
	var spawn_pos: int = _find_quest_spawn_pos()
	if spawn_pos < 0:
		return
	mob.pos = spawn_pos
	mob.level = level
	level.add_mob(mob)
	if TurnManager:
		TurnManager.add_actor(mob)
	if level.has_method("get_terrain") and level.has_method("set_terrain"):
		var terrain: int = level.get_terrain(spawn_pos)
		if terrain == ConstantsData.Terrain.HIGH_GRASS or terrain == ConstantsData.Terrain.FURROWED_GRASS:
			level.set_terrain(spawn_pos, ConstantsData.Terrain.GRASS)
	if EventBus:
		EventBus.mob_revealed.emit(mob)
	quest_mob_spawned = true

func _find_quest_spawn_pos() -> int:
	if level == null:
		return -1
	var hero: Variant = GameManager.hero if GameManager else null
	for _attempt: int in range(80):
		var candidate: int = randi() % ConstantsData.LENGTH
		if not level.has_method("is_passable") or not level.is_passable(candidate):
			continue
		if level.has_method("find_char_at") and level.find_char_at(candidate) != null:
			continue
		if hero != null and hero.has_method("distance_to") and hero.distance_to(candidate) < 6:
			continue
		return candidate
	return -1

# ---------------------------------------------------------------------------
# Reward
# ---------------------------------------------------------------------------

func _offer_reward(hero: Variant) -> void:
	var rewards: Array = []
	if reward_weapon != null:
		rewards.append(reward_weapon)
	if reward_armor != null:
		rewards.append(reward_armor)
	if rewards.is_empty():
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
					"quest_name": "Ghost's Gratitude",
					"quest_description": "Choose a keepsake from the ghost.",
					"reward_items": reward_data,
				})
			return

	var wnd: Node = load("res://src/ui/windows/wnd_quest_reward.gd").new()
	wnd.setup("Ghost's Gratitude", "Choose a keepsake from the ghost.", rewards, hero, int(ConstantsData.get_prop(self, "actor_id", -1)))
	if wnd.has_signal("reward_chosen"):
		wnd.reward_chosen.connect(_on_reward_window_closed)

	if EventBus and EventBus.has_signal("show_window"):
		EventBus.show_window.emit(wnd)
	else:
		if hero and hero.get("belongings") != null and hero.belongings.has_method("add_item"):
			hero.belongings.add_item(rewards[0])
		_on_reward_window_closed(rewards[0])

func _on_reward_window_closed(_chosen_item: Variant) -> void:
	if reward_given:
		return
	reward_given = true
	if EventBus:
		EventBus.quest_updated.emit(quest_id, "reward_chosen")
	_deliver_message("The sad ghost smiles faintly and fades away.", "info")
	_depart()

func _depart() -> void:
	is_alive = false
	deactivate()
	if EventBus and EventBus.has_signal("mob_defeated") and EventBus.mob_defeated.is_connected(on_mob_defeated):
		EventBus.mob_defeated.disconnect(on_mob_defeated)
	if QuestHandler:
		QuestHandler.unregister_npc(self)
		QuestHandler.complete_quest(quest_id)
	if level and level.has_method("remove_mob"):
		level.remove_mob(self)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["quest_target_id"] = quest_target_id
	data["quest_target_name"] = quest_target_name
	data["target_slain"] = target_slain
	data["reward_given"] = reward_given
	data["quest_mob_spawned"] = quest_mob_spawned
	data["reward_enchanted"] = reward_enchanted
	data["reward_weapon"] = reward_weapon.serialize() if reward_weapon != null and reward_weapon.has_method("serialize") else {}
	data["reward_armor"] = reward_armor.serialize() if reward_armor != null and reward_armor.has_method("serialize") else {}
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	quest_target_id = str(data.get("quest_target_id", quest_target_id))
	quest_target_name = str(data.get("quest_target_name", quest_target_name))
	target_slain = bool(data.get("target_slain", target_slain))
	reward_given = bool(data.get("reward_given", reward_given))
	quest_mob_spawned = bool(data.get("quest_mob_spawned", quest_mob_spawned))
	reward_enchanted = bool(data.get("reward_enchanted", reward_enchanted))
	var reward_weapon_data: Variant = data.get("reward_weapon", {})
	if reward_weapon_data is Dictionary and not (reward_weapon_data as Dictionary).is_empty():
		var item_id: String = str((reward_weapon_data as Dictionary).get("item_id", ""))
		if item_id != "":
			reward_weapon = Generator.create_item(item_id)
			if reward_weapon != null and reward_weapon.has_method("deserialize"):
				reward_weapon.deserialize(reward_weapon_data as Dictionary)
	var reward_armor_data: Variant = data.get("reward_armor", {})
	if reward_armor_data is Dictionary and not (reward_armor_data as Dictionary).is_empty():
		var item_id_armor: String = str((reward_armor_data as Dictionary).get("item_id", ""))
		if item_id_armor != "":
			reward_armor = Generator.create_item(item_id_armor)
			if reward_armor != null and reward_armor.has_method("deserialize"):
				reward_armor.deserialize(reward_armor_data as Dictionary)
