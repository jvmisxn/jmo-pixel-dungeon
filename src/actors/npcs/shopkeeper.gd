class_name Shopkeeper
extends NPC
## The Shopkeeper stands in shop rooms on certain floors. Interacting opens a shop
## window where the hero can buy items. If attacked, the shopkeeper teleports away
## and takes all remaining shop items with him.

# --- Shop Inventory ---
## Items currently for sale. Each entry: {item: Item, price: int}
var shop_inventory: Array[Dictionary] = []
## Whether the shopkeeper has fled (attacked or stolen from).
var has_fled: bool = false
## The depth this shopkeeper was spawned on (affects inventory).
var shop_depth: int = 0
## Original: shopkeeper warns first, then flees on second harm (1-turn buffer).
## -1 = never harmed, 0+ = turns since first harm.
var turns_since_harmed: int = -1
## Buyback history — items the hero recently sold that can be repurchased.
## Original: MAX_BUYBACK_HISTORY = 3.
const MAX_BUYBACK_HISTORY: int = 3
var buyback_items: Array = []

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func _init() -> void:
	super._init()
	npc_name = "Shopkeeper"
	mob_name = npc_name
	mob_id = "shopkeeper"
	quest_id = ""  # No quest, just a merchant
	description = "A rotund fellow with a keen eye for gold."

	# Original Shopkeeper has Property.IMMOVABLE — stays in place.
	setup(1, 0, 100, 0, 0, 100, 1.0)  # Very high defense — effectively invulnerable

	dialogue_lines = [
		"Welcome! Browse my wares.",
		"Buy something or move along.",
		"Pleasure doing business!",
	]

# ---------------------------------------------------------------------------
# Turn — tick the harm warning timer
# ---------------------------------------------------------------------------

## Original Shopkeeper.act() faces the hero each turn, ticks the harm timer, and
## has Property.IMMOVABLE. Spends TICK (1 turn) explicitly.
func act() -> void:
	if turns_since_harmed >= 0:
		turns_since_harmed += 1
	# Original: sprite.turnTo(pos, Dungeon.hero.pos) — face the hero each turn.
	# We emit a signal or set facing direction if sprite system supports it.
	if EventBus and EventBus.has_signal("npc_face_hero"):
		EventBus.npc_face_hero.emit(self)
	process_buffs()
	spend_turn()

# ---------------------------------------------------------------------------
# Shop Setup
# ---------------------------------------------------------------------------

## Generate shop inventory appropriate for the given depth.
func stock_shop(depth: int) -> void:
	shop_depth = depth
	shop_inventory.clear()

	var region: int = ConstantsData.region_for_depth(depth)

	# Healing potions (always available)
	_add_shop_item(_make_item("potion_healing", "Potion of Healing", ConstantsData.ItemCategory.POTION), 50)

	# Identify scroll (always available)
	_add_shop_item(_make_item("scroll_identify", "Scroll of Identify", ConstantsData.ItemCategory.SCROLL), 30)

	# Remove curse scroll
	_add_shop_item(_make_item("scroll_remove_curse", "Scroll of Remove Curse", ConstantsData.ItemCategory.SCROLL), 40)

	# Region-specific items
	match region:
		ConstantsData.Region.SEWERS:
			_add_shop_item(_make_item("potion_mind_vision", "Potion of Mind Vision", ConstantsData.ItemCategory.POTION), 50)
			_add_shop_item(_make_item("scroll_magic_mapping", "Scroll of Magic Mapping", ConstantsData.ItemCategory.SCROLL), 70)
			_add_shop_item(_make_item("stone_augmentation", "Stone of Augmentation", ConstantsData.ItemCategory.STONE), 30)
		ConstantsData.Region.PRISON:
			_add_shop_item(_make_item("potion_invisibility", "Potion of Invisibility", ConstantsData.ItemCategory.POTION), 50)
			_add_shop_item(_make_item("potion_haste", "Potion of Haste", ConstantsData.ItemCategory.POTION), 50)
			_add_shop_item(_make_item("scroll_teleportation", "Scroll of Teleportation", ConstantsData.ItemCategory.SCROLL), 60)
			_add_shop_item(_make_item("torch", "Torch", ConstantsData.ItemCategory.MISC), 20)
		ConstantsData.Region.CAVES:
			_add_shop_item(_make_item("potion_healing", "Potion of Healing", ConstantsData.ItemCategory.POTION), 50)
			_add_shop_item(_make_item("potion_experience", "Potion of Experience", ConstantsData.ItemCategory.POTION), 100)
			_add_shop_item(_make_item("scroll_mirror_image", "Scroll of Mirror Image", ConstantsData.ItemCategory.SCROLL), 80)
			_add_shop_item(_make_item("scroll_lullaby", "Scroll of Lullaby", ConstantsData.ItemCategory.SCROLL), 60)
		ConstantsData.Region.CITY:
			_add_shop_item(_make_item("potion_healing", "Potion of Healing", ConstantsData.ItemCategory.POTION), 50)
			_add_shop_item(_make_item("potion_mind_vision", "Potion of Mind Vision", ConstantsData.ItemCategory.POTION), 80)
			_add_shop_item(_make_item("scroll_teleportation", "Scroll of Teleportation", ConstantsData.ItemCategory.SCROLL), 80)
			_add_shop_item(_make_item("ankh", "Ankh", ConstantsData.ItemCategory.MISC), 250)
		ConstantsData.Region.HALLS:
			_add_shop_item(_make_item("potion_healing", "Potion of Healing", ConstantsData.ItemCategory.POTION), 50)
			_add_shop_item(_make_item("potion_haste", "Potion of Haste", ConstantsData.ItemCategory.POTION), 80)
			_add_shop_item(_make_item("scroll_rage", "Scroll of Rage", ConstantsData.ItemCategory.SCROLL), 80)
			_add_shop_item(_make_item("ankh", "Ankh", ConstantsData.ItemCategory.MISC), 300)

	# Add some food
	_add_shop_item(_make_item("ration", "Food Ration", ConstantsData.ItemCategory.FOOD), 20)

	# Add a Torch on all floors (original always stocks torches)
	if region != ConstantsData.Region.PRISON:  # Prison already adds one above
		_add_shop_item(_make_item("torch", "Torch", ConstantsData.ItemCategory.MISC), 20)

func _make_item(id: String, display_name: String, cat: int) -> Variant:
	var item: Variant = load("res://src/items/item.gd").new()
	item.item_id = id
	item.item_name = display_name
	item.category = cat
	item.identified = true
	return item

func _add_shop_item(item: Variant, price: int) -> void:
	shop_inventory.append({"item": item, "price": price})

# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func interact(hero: Variant) -> void:
	if hero == null:
		return

	if has_fled:
		return  # Shopkeeper is gone

	if shop_inventory.is_empty():
		if MessageLog:
			MessageLog.add_info("\"I'm all sold out! Come back another time.\"")
		return

	# Show shop contents
	if MessageLog:
		MessageLog.add_info("\"Welcome! Browse my wares.\"")
		for entry: Dictionary in shop_inventory:
			var item: Variant = entry["item"]
			var price: int = entry["price"] as int
			MessageLog.add_info("  %s — %d gold" % [item.get_display_name(), price])

## Returns the list of items for sale (for UI integration).
func get_shop_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in shop_inventory:
		result.append({
			"item": entry["item"],
			"price": entry["price"],
		})
	return result

## Buy an item from the shop. Returns true on success.
func buy_item(hero: Variant, item_index: int) -> bool:
	if has_fled:
		return false
	if item_index < 0 or item_index >= shop_inventory.size():
		return false

	var entry: Dictionary = shop_inventory[item_index]
	var item: Variant = entry["item"]
	var price: int = entry["price"] as int

	if GameManager and GameManager.gold < price:
		if MessageLog:
			MessageLog.add_warning("\"You can't afford that!\" (%d gold needed)" % price)
		return false

	# Deduct gold
	if GameManager:
		GameManager.gold -= price
		GameManager.gold_changed.emit(GameManager.gold)
		if EventBus:
			EventBus.gold_collected.emit(-price, GameManager.gold)

	# Give item to hero
	var belongings: Variant = hero.get("belongings") if hero else null
	if belongings and belongings.has_method("add_item"):
		belongings.add_item(item)

	# Remove from shop
	shop_inventory.remove_at(item_index)

	if MessageLog:
		MessageLog.add_positive("You purchased %s for %d gold." % [item.get_display_name(), price])

	return true

# ---------------------------------------------------------------------------
# Attack Response — Flee
# ---------------------------------------------------------------------------

## Returns true if the item can be sold to the shopkeeper.
## Original restrictions: no 0-value items, no unique non-stackables, no cursed equipped, no sealed armor.
static func can_sell(item: Variant) -> bool:
	if item == null:
		return false
	var value: int = item.get("price") if item.get("price") != null else 0
	if value <= 0:
		return false
	# Cannot sell cursed equipped items
	if item.get("cursed") == true and item.get("equipped") == true:
		return false
	# Cannot sell unique items that are not stackable
	if item.get("unique") == true and item.get("stackable") != true:
		return false
	return true

## Sell an item to the shopkeeper. Returns the gold received.
func sell_item(hero: Variant, item: Variant) -> int:
	if item == null or has_fled:
		return 0
	if not Shopkeeper.can_sell(item):
		return 0
	var sell_price: int = item.get("price") if item.get("price") != null else 0
	# Original: sell price is item value (not full shop price)
	if sell_price <= 0:
		return 0

	# Remove item from hero inventory
	var belongings: Variant = hero.get("belongings") if hero else null
	if belongings and belongings.has_method("remove_item"):
		belongings.remove_item(item)

	# Give gold
	if GameManager:
		GameManager.gold += sell_price
		if GameManager.has_signal("gold_changed"):
			GameManager.gold_changed.emit(GameManager.gold)

	# Add to buyback list
	if buyback_items.size() >= MAX_BUYBACK_HISTORY:
		buyback_items.pop_front()
	buyback_items.append({"item": item, "price": sell_price})

	if MessageLog:
		MessageLog.add_positive("You sold %s for %d gold." % [item.get_display_name(), sell_price])

	return sell_price

## Called when the shopkeeper is attacked. Warns first, then flees.
func take_damage(dmg: int, source: Variant = null) -> int:
	if turns_since_harmed < 0:
		turns_since_harmed = 0
		if MessageLog:
			MessageLog.add_warning("\"How dare you! One more time and I'm leaving!\"")
		return 0
	# Second offense — flee
	_flee()
	return 0

func _flee() -> void:
	has_fled = true
	shop_inventory.clear()
	if MessageLog:
		MessageLog.add_negative("The shopkeeper vanishes in a puff of smoke, taking his wares!")
	if level and level.has_method("remove_mob"):
		level.remove_mob(self)
