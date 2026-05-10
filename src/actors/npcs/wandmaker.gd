class_name Wandmaker
extends NPC
## The Old Wandmaker appears in the Prison (depth 7-9). He asks the hero to bring
## him a specific seed — either a Rotberry Seed or a Corpseweed Seed. In return,
## he offers a choice between two random wands.

# --- Quest Specifics ---
## Which quest item the wandmaker wants.
var requested_seed_id: String = ""
var requested_seed_name: String = ""

# --- Rewards ---
var wand_choice_a: Variant = null
var wand_choice_b: Variant = null
var reward_given: bool = false

# --- Wand Pool ---
const WAND_POOL: Array = [
	["wand_of_magic_missile", "Wand of Magic Missile"],
	["wand_of_fire_bolt", "Wand of Fire Bolt"],
	["wand_of_frost", "Wand of Frost"],
	["wand_of_lightning", "Wand of Lightning"],
	["wand_of_disintegration", "Wand of Disintegration"],
	["wand_of_corruption", "Wand of Corruption"],
	["wand_of_blast_wave", "Wand of Blast Wave"],
	["wand_of_living_earth", "Wand of Living Earth"],
	["wand_of_prismatic_light", "Wand of Prismatic Light"],
	["wand_of_transfusion", "Wand of Transfusion"],
	["wand_of_warding", "Wand of Warding"],
	["wand_of_regrowth", "Wand of Regrowth"],
	["wand_of_corrosion", "Wand of Corrosion"],
]

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func _init() -> void:
	super._init()
	npc_name = "Old Wandmaker"
	mob_name = npc_name
	mob_id = "wandmaker"
	quest_id = "wandmaker_quest"
	description = "An elderly man clutching a gnarled staff. His eyes hold ancient knowledge."

	setup(1, 0, 0, 0, 0, 0, 1.0)

	# Original Wandmaker has Property.IMMOVABLE — stays in place, never wanders.
	# NPC base class enforces PASSIVE state which effectively makes it immovable.

	dialogue_lines = [
		"I've lost my most precious reagent... bring me a %s and I'll reward you handsomely.",
		"Have you found the %s yet? I can feel it growing somewhere on this floor...",
		"Wonderful! Let me see... yes, yes! Now, which wand would you prefer?",
	]

	_pick_requested_seed()
	_generate_wand_rewards()

# ---------------------------------------------------------------------------
# Quest Setup
# ---------------------------------------------------------------------------

func _pick_requested_seed() -> void:
	# Original has 3 quest types: 1=corpse dust, 2=elemental embers, 3=rotberry seed
	# Each tied to a dedicated quest room (MassGrave, RitualSite, RotGarden)
	var quest_type: int = randi() % 3 + 1
	match quest_type:
		1:
			requested_seed_id = "corpse_dust"
			requested_seed_name = "Corpse Dust"
		2:
			requested_seed_id = "elemental_embers"
			requested_seed_name = "Elemental Embers"
		3, _:
			requested_seed_id = "seed_of_rotberry"
			requested_seed_name = "Rotberry Seed"

func _generate_wand_rewards() -> void:
	# Pick two distinct random wands from the pool
	var indices: Array[int] = []
	for i: int in range(WAND_POOL.size()):
		indices.append(i)
	indices.shuffle()

	var pick_a: Array = WAND_POOL[indices[0]]
	var pick_b: Array = WAND_POOL[indices[1]]

	wand_choice_a = _create_reward_wand(pick_a[0], pick_a[1])
	wand_choice_b = _create_reward_wand(pick_b[0], pick_b[1])

func _create_reward_wand(wand_id: String, fallback_name: String) -> Variant:
	var wand: Variant = Generator.create_item(wand_id)
	if wand == null:
		wand = Wand.create(wand_id)
	if wand == null:
		return null
	wand.item_name = fallback_name
	if wand.has_method("identify"):
		wand.identify()
	else:
		wand.identified = true
	return wand

# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func interact(hero: Variant) -> void:
	if hero == null:
		return
	_remember_interacting_hero(hero)

	if reward_given:
		_deliver_message("The wandmaker nods knowingly and returns to his work.", "info", hero)
		return

	if quest_complete:
		_offer_reward(hero)
		return

	if quest_active:
		# Check if hero has the requested seed
		if _hero_has_seed(hero):
			_take_seed(hero)
			quest_complete = true
			_deliver_message(dialogue_lines[2], "info", hero)
			_offer_reward(hero)
		else:
			_deliver_message(dialogue_lines[1] % requested_seed_name, "info", hero)
		return

	# First interaction — give the quest
	quest_active = true
	_deliver_message(dialogue_lines[0] % requested_seed_name, "info", hero)
	if EventBus:
		EventBus.quest_updated.emit(quest_id, "active")

func _hero_has_seed(hero: Variant) -> bool:
	if hero == null:
		return false
	var belongings: Variant = hero.get("belongings")
	if belongings == null:
		return false
	if belongings.has_method("has_item_by_id"):
		return belongings.has_item_by_id(requested_seed_id)
	# Fallback: check backpack array
	if belongings.has_method("get_items"):
		var items: Array = belongings.get_items()
		for item: Variant in items:
			if item != null and item.get("item_id") == requested_seed_id:
				return true
	return false

func _take_seed(hero: Variant) -> void:
	var belongings: Variant = hero.get("belongings")
	if belongings == null:
		return
	var removed: int = 0
	if belongings.has_method("remove_item_quantity"):
		removed = belongings.remove_item_quantity(requested_seed_id, 1)
	elif belongings.has_method("remove_item_by_id"):
		removed = 1 if belongings.remove_item_by_id(requested_seed_id) != null else 0
	if removed > 0:
		_deliver_message("You hand over the %s." % requested_seed_name)

func _offer_reward(hero: Variant) -> void:
	# Open the quest reward window for the player to choose a wand.
	var rewards: Array = []
	if wand_choice_a:
		rewards.append(wand_choice_a)
	if wand_choice_b:
		rewards.append(wand_choice_b)

	if rewards.is_empty():
		_deliver_message("The wandmaker has nothing left to offer.")
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
					"quest_name": "Wandmaker's Gift",
					"quest_description": "Choose a wand as your reward.",
					"reward_items": reward_data,
				})
			return

	var wnd: Node = load("res://src/ui/windows/wnd_quest_reward.gd").new()
	wnd.setup("Wandmaker's Gift", "Choose a wand as your reward.", rewards, hero, int(ConstantsData.get_prop(self, "actor_id", -1)))
	if wnd.has_signal("reward_chosen"):
		wnd.reward_chosen.connect(_on_reward_chosen)

	if EventBus and EventBus.has_signal("show_window"):
		EventBus.show_window.emit(wnd)
	else:
		# Fallback: give first wand directly if we can't show the window
		if hero and hero.get("belongings") != null:
			var belongings: Variant = hero.belongings
			if belongings.has_method("add_item"):
				belongings.add_item(wand_choice_a)
		_deliver_message("You receive the %s." % wand_choice_a.item_name, "positive", hero)
		_on_reward_chosen(wand_choice_a)

func _on_reward_chosen(_chosen_item: Variant) -> void:
	if reward_given:
		return
	reward_given = true
	if EventBus:
		EventBus.quest_updated.emit(quest_id, "complete")
	_deliver_message("The wandmaker bows and shuffles away into the shadows.")
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
	data["requested_seed_id"] = requested_seed_id
	data["requested_seed_name"] = requested_seed_name
	data["reward_given"] = reward_given
	data["wand_choice_a"] = wand_choice_a.serialize() if wand_choice_a != null and wand_choice_a.has_method("serialize") else {}
	data["wand_choice_b"] = wand_choice_b.serialize() if wand_choice_b != null and wand_choice_b.has_method("serialize") else {}
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	requested_seed_id = str(data.get("requested_seed_id", requested_seed_id))
	requested_seed_name = str(data.get("requested_seed_name", requested_seed_name))
	reward_given = bool(data.get("reward_given", reward_given))
	var wand_a_data: Variant = data.get("wand_choice_a", {})
	if wand_a_data is Dictionary and not (wand_a_data as Dictionary).is_empty():
		var wand_a_id: String = str((wand_a_data as Dictionary).get("item_id", ""))
		if wand_a_id != "":
			wand_choice_a = Generator.create_item(wand_a_id)
			if wand_choice_a != null and wand_choice_a.has_method("deserialize"):
				wand_choice_a.deserialize(wand_a_data as Dictionary)
	var wand_b_data: Variant = data.get("wand_choice_b", {})
	if wand_b_data is Dictionary and not (wand_b_data as Dictionary).is_empty():
		var wand_b_id: String = str((wand_b_data as Dictionary).get("item_id", ""))
		if wand_b_id != "":
			wand_choice_b = Generator.create_item(wand_b_id)
			if wand_choice_b != null and wand_choice_b.has_method("deserialize"):
				wand_choice_b.deserialize(wand_b_data as Dictionary)

# ---------------------------------------------------------------------------
# Quest Seed Item Creation
# ---------------------------------------------------------------------------

## Create the quest seed item for placing on the level.
## Create the quest item for placing on the level.
static func create_quest_item(item_id: String) -> Variant:
	var quest_item: Variant = load("res://src/items/item.gd").new()
	match item_id:
		"corpse_dust":
			quest_item.item_id = "corpse_dust"
			quest_item.item_name = "Corpse Dust"
			quest_item.description = "Fine powdery remains found in a mass grave. The wandmaker wants this."
			quest_item.category = ConstantsData.ItemCategory.MISC
			quest_item.stackable = false
			quest_item.unique = true
		"elemental_embers":
			quest_item.item_id = "elemental_embers"
			quest_item.item_name = "Elemental Embers"
			quest_item.description = "Glowing embers from a fire elemental. The wandmaker wants this."
			quest_item.category = ConstantsData.ItemCategory.MISC
			quest_item.stackable = false
			quest_item.unique = true
		"seed_of_rotberry":
			quest_item = SeedItem.create("seed_of_rotberry")
			quest_item.quantity = 1
			quest_item.unique = true
			quest_item.description = "A seed from a rotberry bush. The wandmaker wants this."
		_:
			quest_item.item_id = item_id
			quest_item.item_name = item_id.replace("_", " ").capitalize()
			quest_item.category = ConstantsData.ItemCategory.MISC
	return quest_item
