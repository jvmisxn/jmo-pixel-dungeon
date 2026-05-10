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
## Buyback history - items the hero recently sold that can be repurchased.
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

	# Original Shopkeeper has Property.IMMOVABLE - stays in place.
	setup(1, 0, 100, 0, 0, 100, 1.0)  # Very high defense - effectively invulnerable

	dialogue_lines = [
		"Welcome! Browse my wares.",
		"Buy something or move along.",
		"Pleasure doing business!",
	]

# ---------------------------------------------------------------------------
# Turn - tick the harm warning timer
# ---------------------------------------------------------------------------

## Original Shopkeeper.act() faces the hero each turn, ticks the harm timer, and
## has Property.IMMOVABLE. Spends TICK (1 turn) explicitly.
func act() -> void:
	if turns_since_harmed >= 0:
		turns_since_harmed += 1
	# Original: sprite.turnTo(pos, Dungeon.hero.pos) - face the hero each turn.
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
	_add_shop_item(_make_item("healing", "Potion of Healing", ConstantsData.ItemCategory.POTION), 50)

	# Identify scroll (always available)
	_add_shop_item(_make_item("identify", "Scroll of Identify", ConstantsData.ItemCategory.SCROLL), 30)

	# Remove curse scroll
	_add_shop_item(_make_item("remove_curse", "Scroll of Remove Curse", ConstantsData.ItemCategory.SCROLL), 40)

	# Region-specific items
	match region:
		ConstantsData.Region.SEWERS:
			_add_shop_item(_make_item("mind_vision", "Potion of Mind Vision", ConstantsData.ItemCategory.POTION), 50)
			_add_shop_item(_make_item("magic_mapping", "Scroll of Magic Mapping", ConstantsData.ItemCategory.SCROLL), 70)
			_add_shop_item(_make_item("augmentation", "Stone of Augmentation", ConstantsData.ItemCategory.STONE), 30)
		ConstantsData.Region.PRISON:
			_add_shop_item(_make_item("invisibility", "Potion of Invisibility", ConstantsData.ItemCategory.POTION), 50)
			_add_shop_item(_make_item("haste", "Potion of Haste", ConstantsData.ItemCategory.POTION), 50)
			_add_shop_item(_make_item("teleportation", "Scroll of Teleportation", ConstantsData.ItemCategory.SCROLL), 60)
			_add_shop_item(_make_item("torch", "Torch", ConstantsData.ItemCategory.MISC), 20)
		ConstantsData.Region.CAVES:
			_add_shop_item(_make_item("healing", "Potion of Healing", ConstantsData.ItemCategory.POTION), 50)
			_add_shop_item(_make_item("experience", "Potion of Experience", ConstantsData.ItemCategory.POTION), 100)
			_add_shop_item(_make_item("mirror_image", "Scroll of Mirror Image", ConstantsData.ItemCategory.SCROLL), 80)
			_add_shop_item(_make_item("lullaby", "Scroll of Lullaby", ConstantsData.ItemCategory.SCROLL), 60)
		ConstantsData.Region.CITY:
			_add_shop_item(_make_item("healing", "Potion of Healing", ConstantsData.ItemCategory.POTION), 50)
			_add_shop_item(_make_item("mind_vision", "Potion of Mind Vision", ConstantsData.ItemCategory.POTION), 80)
			_add_shop_item(_make_item("teleportation", "Scroll of Teleportation", ConstantsData.ItemCategory.SCROLL), 80)
			_add_shop_item(_make_item("ankh", "Ankh", ConstantsData.ItemCategory.MISC), 250)
		ConstantsData.Region.HALLS:
			_add_shop_item(_make_item("healing", "Potion of Healing", ConstantsData.ItemCategory.POTION), 50)
			_add_shop_item(_make_item("haste", "Potion of Haste", ConstantsData.ItemCategory.POTION), 80)
			_add_shop_item(_make_item("rage", "Scroll of Rage", ConstantsData.ItemCategory.SCROLL), 80)
			_add_shop_item(_make_item("ankh", "Ankh", ConstantsData.ItemCategory.MISC), 300)

	# Add some food
	_add_shop_item(_make_item("ration", "Food Ration", ConstantsData.ItemCategory.FOOD), 20)

	# Add a Torch on all floors (original always stocks torches)
	if region != ConstantsData.Region.PRISON:  # Prison already adds one above
		_add_shop_item(_make_item("torch", "Torch", ConstantsData.ItemCategory.MISC), 20)

func _make_item(id: String, display_name: String, cat: int) -> Variant:
	var item: Variant = Generator.create_item(id) if Generator else null
	if item == null:
		item = load("res://src/items/item.gd").new()
		item.item_id = id
		item.item_name = display_name
		item.category = cat
	item.identified = true
	item.cursed_known = true
	return item

func _add_shop_item(item: Variant, price: int) -> void:
	shop_inventory.append({"item": item, "price": price})

# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func interact(hero: Variant) -> void:
	if hero == null:
		return
	_remember_interacting_hero(hero)

	if has_fled:
		return

	if shop_inventory.is_empty():
		_deliver_message("\"I'm all sold out! Come back another time.\"", "info", hero)
		return

	if NetworkManager != null and NetworkManager.has_method("is_host") and NetworkManager.is_host():
		var owner_peer_id: int = int(ConstantsData.get_prop(hero, "owner_peer_id", 1))
		var local_peer_id: int = NetworkManager.get_local_peer_id() if NetworkManager.has_method("get_local_peer_id") else 1
		if owner_peer_id != local_peer_id:
			var shop_items_data: Array[Dictionary] = []
			for entry: Dictionary in shop_inventory:
				var event_entry: Dictionary = {"price": int(entry.get("price", 0))}
				var item: Variant = entry.get("item")
				if item != null and item.has_method("serialize"):
					event_entry["item_data"] = item.serialize()
				shop_items_data.append(event_entry)
			if NetworkManager.has_method("send_ui_event_to_peer"):
				NetworkManager.send_ui_event_to_peer(owner_peer_id, {
					"type": "shop_open",
					"hero_actor_id": int(ConstantsData.get_prop(hero, "actor_id", -1)),
					"shopkeeper_actor_id": int(ConstantsData.get_prop(self, "actor_id", -1)),
					"shop_items": shop_items_data,
				})
			return

	var wnd: Variant = load("res://src/ui/windows/wnd_shop.gd").new()
	if wnd.has_method("setup"):
		wnd.setup(get_shop_items(), hero, self)
	if EventBus and EventBus.has_signal("show_window"):
		EventBus.show_window.emit(wnd)
	else:
		_deliver_message("\"Welcome! Browse my wares.\"", "info", hero)

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
		_deliver_message("\"You can't afford that!\" (%d gold needed)" % price, "warning", hero)
		return false

	var belongings: Variant = hero.get("belongings") if hero else null
	if belongings == null or not belongings.has_method("add_item"):
		return false
	if not belongings.add_item(item):
		return false

	# Deduct gold only after the item was accepted.
	if GameManager:
		GameManager.gold -= price
		GameManager.gold_changed.emit(GameManager.gold)
		if EventBus:
			EventBus.gold_collected.emit(-price, GameManager.gold)

	shop_inventory.remove_at(item_index)

	_deliver_message("You purchased %s for %d gold." % [item.get_display_name(), price], "positive", hero)

	return true

# ---------------------------------------------------------------------------
# Attack Response - Flee
# ---------------------------------------------------------------------------

## Returns true if the item can be sold to the shopkeeper.
## Original restrictions: no 0-value items, no unique non-stackables, no cursed equipped, no sealed armor.
static func can_sell(item: Variant) -> bool:
	if item == null:
		return false
	var value: int = item.value() if item.has_method("value") else 0
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
	var base_value: int = item.value() if item.has_method("value") else 0
	var sell_price: int = maxi(1, int(float(base_value) * 0.5))
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

	_deliver_message("You sold %s for %d gold." % [item.get_display_name(), sell_price], "positive", hero)

	return sell_price

## Called when the shopkeeper is attacked. Warns first, then flees.
func take_damage(_dmg: int, _source: Variant = null) -> int:
	if turns_since_harmed < 0:
		turns_since_harmed = 0
		_deliver_message("\"How dare you! One more time and I'm leaving!\"", "warning")
		return 0
	_flee()
	return 0

func _flee() -> void:
	has_fled = true
	shop_inventory.clear()
	_deliver_message("The shopkeeper vanishes in a puff of smoke, taking his wares!", "negative")
	if level and level.has_method("remove_mob"):
		level.remove_mob(self)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["has_fled"] = has_fled
	data["shop_depth"] = shop_depth
	data["turns_since_harmed"] = turns_since_harmed
	var inventory_data: Array[Dictionary] = []
	for entry: Dictionary in shop_inventory:
		var item: Variant = entry.get("item")
		if item != null and item.has_method("serialize"):
			inventory_data.append({
				"price": int(entry.get("price", 0)),
				"item": item.serialize(),
			})
	data["shop_inventory"] = inventory_data
	var buyback_data: Array[Dictionary] = []
	for entry: Variant in buyback_items:
		if entry is Dictionary:
			var buyback_entry: Dictionary = entry as Dictionary
			var buyback_item: Variant = buyback_entry.get("item")
			if buyback_item != null and buyback_item.has_method("serialize"):
				buyback_data.append({
					"price": int(buyback_entry.get("price", 0)),
					"item": buyback_item.serialize(),
				})
	data["buyback_items"] = buyback_data
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	has_fled = bool(data.get("has_fled", has_fled))
	shop_depth = int(data.get("shop_depth", shop_depth))
	turns_since_harmed = int(data.get("turns_since_harmed", turns_since_harmed))
	shop_inventory.clear()
	var inventory_data: Variant = data.get("shop_inventory", [])
	if inventory_data is Array:
		for entry_variant: Variant in inventory_data:
			if not (entry_variant is Dictionary):
				continue
			var entry_data: Dictionary = entry_variant as Dictionary
			var item_data: Variant = entry_data.get("item", {})
			if item_data is Dictionary:
				var item_id: String = str((item_data as Dictionary).get("item_id", ""))
				if item_id != "":
					var item: Variant = Generator.create_item(item_id)
					if item != null and item.has_method("deserialize"):
						item.deserialize(item_data as Dictionary)
						shop_inventory.append({"item": item, "price": int(entry_data.get("price", 0))})
	buyback_items.clear()
	var buyback_data: Variant = data.get("buyback_items", [])
	if buyback_data is Array:
		for entry_variant: Variant in buyback_data:
			if not (entry_variant is Dictionary):
				continue
			var entry_data: Dictionary = entry_variant as Dictionary
			var item_data: Variant = entry_data.get("item", {})
			if item_data is Dictionary:
				var item_id: String = str((item_data as Dictionary).get("item_id", ""))
				if item_id != "":
					var item: Variant = Generator.create_item(item_id)
					if item != null and item.has_method("deserialize"):
						item.deserialize(item_data as Dictionary)
						buyback_items.append({"item": item, "price": int(entry_data.get("price", 0))})
