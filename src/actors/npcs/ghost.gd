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

## Original Ghost.chooseEnemy() returns null — ghost never hunts.
func choose_enemy() -> Variant:
	return null

## Override wander destination: Ghost cannot wander onto heaps or the level exit.
## Matches original Ghost.Wandering.randomDestination() override.
func _get_wander_destination() -> int:
	var dest: int = super._get_wander_destination() if has_method("_get_wander_destination") else -1
	if dest < 0:
		return dest
	# Cannot wander onto heaps
	if level and level.has_method("heap_at") and level.heap_at(dest) != null:
		return -1
	# Cannot wander onto level exit
	if level and level.has_method("get_exit") and dest == level.get_exit():
		return -1
	return dest

## Override _set_state: Ghost wanders (not passive like other NPCs, not hunting).
func _set_state(new_state: AIState) -> void:
	# Ghost can wander but never hunts or flees
	if new_state == AIState.WANDERING or new_state == AIState.PASSIVE:
		super._set_state(new_state)
	else:
		super._set_state(AIState.WANDERING)

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

	var _ItemScript: GDScript = load("res://src/items/item.gd")
	reward_weapon = _ItemScript.new()
	reward_weapon.item_id = picked_weapon_id
	reward_weapon.item_name = picked_weapon_id.capitalize().replace("_", " ")
	reward_weapon.description = "A weapon left behind by the ghost."
	reward_weapon.category = ConstantsData.ItemCategory.WEAPON
	reward_weapon.identified = true
	reward_weapon.level = item_level
	reward_weapon.set("tier", reward_tier)

	# Generate an armor reward using the proper tier
	var armor_ids_by_tier: Dictionary = {
		2: ["leather_armor"],
		3: ["mail_armor"],
		4: ["scale_armor"],
		5: ["plate_armor"],
	}
	var tier_armors: Array = armor_ids_by_tier.get(reward_tier, ["leather_armor"])
	var picked_armor_id: String = tier_armors[randi() % tier_armors.size()]

	reward_armor = _ItemScript.new()
	reward_armor.item_id = picked_armor_id
	reward_armor.item_name = picked_armor_id.capitalize().replace("_", " ")
	reward_armor.description = "Armor left behind by the ghost."
	reward_armor.category = ConstantsData.ItemCategory.ARMOR
	reward_armor.identified = true
	reward_armor.level = item_level
	reward_armor.set("tier", reward_tier)
