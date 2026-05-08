class_name Wandmaker
extends NPC
## The Old Wandmaker appears in the Prison (depth 7-9). He asks the hero to bring
## him a specific seed — either a Rotberry Seed or a Corpseweed Seed. In return,
## he offers a choice between two random wands.

# --- Quest Specifics ---
## Which seed the wandmaker wants: "rotberry_seed" or "corpseweed_seed"
var requested_seed_id: String = ""
var requested_seed_name: String = ""

# --- Rewards ---
var wand_choice_a: Variant = null
var wand_choice_b: Variant = null
var reward_given: bool = false

# --- Wand Pool ---
const WAND_POOL: Array = [
	["wand_magic_missile", "Wand of Magic Missile"],
	["wand_fireblast", "Wand of Fireblast"],
	["wand_frost", "Wand of Frost"],
	["wand_lightning", "Wand of Lightning"],
	["wand_disintegration", "Wand of Disintegration"],
	["wand_corruption", "Wand of Corruption"],
	["wand_blast_wave", "Wand of Blast Wave"],
	["wand_living_earth", "Wand of Living Earth"],
	["wand_prismatic_light", "Wand of Prismatic Light"],
	["wand_transfusion", "Wand of Transfusion"],
	["wand_warding", "Wand of Warding"],
	["wand_regrowth", "Wand of Regrowth"],
	["wand_corrosion", "Wand of Corrosion"],
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
			requested_seed_id = "rotberry_seed"
			requested_seed_name = "Rotberry Seed"

func _generate_wand_rewards() -> void:
	# Pick two distinct random wands from the pool
	var indices: Array[int] = []
	for i: int in range(WAND_POOL.size()):
		indices.append(i)
	indices.shuffle()

	var pick_a: Array = WAND_POOL[indices[0]]
	var pick_b: Array = WAND_POOL[indices[1]]

	var _ItemScript: GDScript = load("res://src/items/item.gd")
	wand_choice_a = _ItemScript.new()
	wand_choice_a.item_id = pick_a[0]
	wand_choice_a.item_name = pick_a[1]
	wand_choice_a.description = "A magical wand gifted by the Wandmaker."
	wand_choice_a.category = ConstantsData.ItemCategory.WAND
	wand_choice_a.identified = true
	wand_choice_a.level = 1

	wand_choice_b = _ItemScript.new()
	wand_choice_b.item_id = pick_b[0]
	wand_choice_b.item_name = pick_b[1]
	wand_choice_b.description = "A magical wand gifted by the Wandmaker."
	wand_choice_b.category = ConstantsData.ItemCategory.WAND
	wand_choice_b.identified = true
	wand_choice_b.level = 1

# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func interact(hero: Variant) -> void:
	if hero == null:
		return

	if reward_given:
		if MessageLog:
			MessageLog.add_info("The wandmaker nods knowingly and returns to his work.")
		return

	if quest_complete:
		_offer_reward(hero)
		return

	if quest_active:
		# Check if hero has the requested seed
		if _hero_has_seed(hero):
			_take_seed(hero)
			quest_complete = true
			if MessageLog:
				MessageLog.add_info(dialogue_lines[2])
			_offer_reward(hero)
		else:
			if MessageLog:
				MessageLog.add_info(dialogue_lines[1] % requested_seed_name)
		return

	# First interaction — give the quest
	quest_active = true
	if MessageLog:
		MessageLog.add_info(dialogue_lines[0] % requested_seed_name)
	if EventBus:
		EventBus.quest_updated.emit(quest_id, "active")

func _hero_has_seed(hero: Variant) -> bool:
	if hero == null:
		return false
	var belongings: Variant = hero.get("belongings")
	if belongings == null:
		return false
	if belongings.has_method("has_item"):
		return belongings.has_item(requested_seed_id)
	# Fallback: check backpack array
	if belongings.has_method("get_items"):
		var items: Array = belongings.get_items()
		for item: Variant in items:
			if item != null and item.get("item_id") == requested_seed_id:
				return true
			elif item != null and item.get("item_id") == requested_seed_id:
				return true
	return false

func _take_seed(hero: Variant) -> void:
	var belongings: Variant = hero.get("belongings")
	if belongings == null:
		return
	if belongings.has_method("remove_item_by_id"):
		belongings.remove_item_by_id(requested_seed_id, 1)
	if MessageLog:
		MessageLog.add_info("You hand over the %s." % requested_seed_name)

func _offer_reward(hero: Variant) -> void:
	# Open the quest reward window for the player to choose a wand.
	var rewards: Array = []
	if wand_choice_a:
		rewards.append(wand_choice_a)
	if wand_choice_b:
		rewards.append(wand_choice_b)

	if rewards.is_empty():
		if MessageLog:
			MessageLog.add_info("The wandmaker has nothing left to offer.")
		_depart()
		return

	var wnd: Node = load("res://src/ui/windows/wnd_quest_reward.gd").new()
	wnd.setup("Wandmaker's Gift", "Choose a wand as your reward.", rewards, hero)
	wnd.tree_exited.connect(_on_reward_window_closed)

	if EventBus and EventBus.has_signal("show_window"):
		EventBus.show_window.emit(wnd)
	else:
		# Fallback: give first wand directly if we can't show the window
		if hero and hero.get("belongings") != null:
			var belongings: Variant = hero.belongings
			if belongings.has_method("add_item"):
				belongings.add_item(wand_choice_a)
		if MessageLog:
			MessageLog.add_positive("You receive the %s." % wand_choice_a.item_name)
		_on_reward_window_closed()

func _on_reward_window_closed() -> void:
	reward_given = true
	if EventBus:
		EventBus.quest_updated.emit(quest_id, "complete")
	if MessageLog:
		MessageLog.add_info("The wandmaker bows and shuffles away into the shadows.")
	_depart()

func _depart() -> void:
	is_alive = false
	deactivate()
	if level and level.has_method("remove_mob"):
		level.remove_mob(self)

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
		"rotberry_seed":
			quest_item.item_id = "rotberry_seed"
			quest_item.item_name = "Rotberry Seed"
			quest_item.description = "A seed from a rotberry bush. The wandmaker wants this."
			quest_item.category = ConstantsData.ItemCategory.SEED
			quest_item.stackable = false
			quest_item.unique = true
		_:
			quest_item.item_id = item_id
			quest_item.item_name = item_id.replace("_", " ").capitalize()
			quest_item.category = ConstantsData.ItemCategory.MISC
	return quest_item
