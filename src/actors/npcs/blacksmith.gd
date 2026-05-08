class_name Blacksmith
extends NPC
## The Troll Blacksmith appears in the Caves (depth 12-14). He asks the hero to
## bring dark gold ore, a special item dropped by bats in the Caves. In return,
## he can reforge (combine) two items, effectively upgrading one by consuming the other.
##
## NOTE: Original SPD Blacksmith is significantly more complex:
## - Gives the hero a Pickaxe to mine dark gold ore from special terrain
## - Has quest types: CRYSTAL (crystal guardians), GNOLL (gnoll geomancers)
## - Uses a "favor" system: ore gives 50 favor/piece (max 2000), quest boss gives 1000
## - Multiple reward options with different favor costs:
##   * Reforge (combine two items)
##   * Harden (apply cursed seal)
##   * Upgrade (+1)
##   * Smith (choose from pre-generated rewards)
## - Currently simplified to: bring ore → one reforge.

# --- Quest Specifics ---
## Dark gold ore count. Original uses Item quantities; we track as int.
## Original gives 50 favor per ore piece. There's no fixed "required" count —
## favor unlocks different reward tiers. We simplify to a threshold.
const REQUIRED_ORE: int = 15
## Whether the hero has delivered enough ore.
var ore_delivered: bool = false

# --- Reforge State ---
## Whether the blacksmith has already reforged an item this run.
## Original supports multiple reward uses based on favor balance.
var has_reforged: bool = false

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func _init() -> void:
	super._init()
	npc_name = "Troll Blacksmith"
	mob_name = npc_name
	mob_id = "blacksmith"
	quest_id = "blacksmith_quest"
	description = "A hulking troll hunched over an anvil, sparks flying from his hammer."

	setup(1, 0, 0, 0, 0, 0, 1.0)

	# Original Blacksmith has Property.IMMOVABLE — stays at his anvil.
	# NPC base class enforces PASSIVE state which effectively makes it immovable.

	dialogue_lines = [
		"Ore. I need dark gold ore. Bring me %d pieces and I'll make it worth your while." % REQUIRED_ORE,
		"Still need more ore. I count what you've got... not enough yet.",
		"Good stuff! Now bring me two items and I'll hammer them into one.",
	]

# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func interact(hero: Variant) -> void:
	if hero == null:
		return

	if has_reforged:
		if MessageLog:
			MessageLog.add_info("The blacksmith grunts. \"Already did my part. Now scram.\"")
		return

	if quest_complete:
		_offer_reforge(hero)
		return

	if quest_active:
		# Check if hero has enough ore
		var ore_count: int = _count_ore(hero)
		if ore_count >= REQUIRED_ORE:
			_take_ore(hero)
			ore_delivered = true
			quest_complete = true
			if MessageLog:
				MessageLog.add_info(dialogue_lines[2])
			_offer_reforge(hero)
		else:
			if MessageLog:
				MessageLog.add_info("\"Got %d ore so far. Need %d total.\"" % [ore_count, REQUIRED_ORE])
		return

	# First interaction — give the quest
	quest_active = true
	if MessageLog:
		MessageLog.add_info(dialogue_lines[0])
	if EventBus:
		EventBus.quest_updated.emit(quest_id, "active")

# ---------------------------------------------------------------------------
# Ore Handling
# ---------------------------------------------------------------------------

func _count_ore(hero: Variant) -> int:
	if hero == null or hero.get("is_hero") != true:
		return 0
	if hero.get("belongings") == null:
		return 0
	var belongings: Variant = hero.belongings
	if belongings.has_method("count_item"):
		return belongings.count_item("dark_gold_ore")
	# Fallback: manually count
	var count: int = 0
	if belongings.get("backpack") != null:
		for item: Variant in belongings.backpack:
			if item != null and item.get("item_id") == "dark_gold_ore":
				count += item.get("quantity") if item.get("quantity") else 0
	return count

func _take_ore(hero: Variant) -> void:
	var belongings: Variant = hero.get("belongings")
	if belongings == null:
		return
	if belongings.has_method("remove_item_by_id"):
		belongings.remove_item_by_id("dark_gold_ore", REQUIRED_ORE)
	if MessageLog:
		MessageLog.add_info("You hand over %d pieces of dark gold ore." % REQUIRED_ORE)

# ---------------------------------------------------------------------------
# Reforge
# ---------------------------------------------------------------------------

func _offer_reforge(hero: Variant) -> void:
	# In a full implementation, this opens a UI where the hero selects two items.
	# The first item keeps its identity; the second is consumed and its upgrade
	# level is transferred (+1 bonus). For now, log the offer.
	if MessageLog:
		MessageLog.add_positive("The blacksmith is ready to reforge! Select two items to combine.")
		MessageLog.add_info("(The second item will be consumed to upgrade the first.)")
	# The actual reforge is triggered by reforge() when the UI makes the call.

## Reforge two items: keep item_a, consume item_b, transfer upgrade bonus.
## Returns true on success.
func reforge(hero: Variant, item_a: Variant, item_b: Variant) -> bool:
	if has_reforged:
		if MessageLog:
			MessageLog.add_warning("The blacksmith has already reforged for you.")
		return false

	if item_a == null or item_b == null:
		if MessageLog:
			MessageLog.add_warning("You need two items to reforge.")
		return false

	if item_a == item_b:
		if MessageLog:
			MessageLog.add_warning("You can't reforge an item with itself.")
		return false

	# Original reforge: the kept item gets the HIGHER of the two levels, plus +1.
	# If item_a is +2 and item_b is +3, item_a becomes +4 (max(2,3)+1).
	# This prevents exploiting by always feeding high-level items.
	var max_level: int = maxi(item_a.level, item_b.level)
	var target_level: int = max_level + 1
	var upgrades_needed: int = maxi(0, target_level - item_a.level)
	for i: int in range(upgrades_needed):
		item_a.upgrade()

	# Remove item_b from inventory
	var belongings: Variant = hero.get("belongings") if hero else null
	if belongings and belongings.has_method("remove_item"):
		belongings.remove_item(item_b)

	has_reforged = true

	if MessageLog:
		MessageLog.add_positive("The blacksmith hammers away... done! %s has been upgraded!" % item_a.get_display_name())
	if EventBus:
		EventBus.quest_updated.emit(quest_id, "complete")

	return true

# ------------------

