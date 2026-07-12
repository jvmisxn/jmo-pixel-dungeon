class_name Bag
extends Item
## Container item that expands the hero's inventory for specific item categories.
## Each bag accepts only items of its designated category and has a fixed capacity.

# --- Properties ---
## Maximum number of items this bag can hold.
var size: int = 20
## The item category this bag accepts (from ConstantsData.ItemCategory).
var accepted_category: int = ConstantsData.ItemCategory.MISC
## Secondary accepted category (-1 means none).
var accepted_category_secondary: int = -1
## Items stored in this bag.
var items: Array[Item] = []

func _init() -> void:
	category = ConstantsData.ItemCategory.MISC
	stackable = false
	unique = true
	default_action = "OPEN"
	identified = true
	cursed_known = true
	icon_color = Color(0.6, 0.5, 0.4)

func is_upgradeable() -> bool:
	return false

# ---------------------------------------------------------------------------
# Bag Interface
# ---------------------------------------------------------------------------

## Check whether a given item can be stored in this bag.
func can_hold(item: Item) -> bool:
	if item == null:
		return false
	if items.size() >= size:
		return false
	var item_cat: int = item.category
	if item_cat == accepted_category:
		return true
	if accepted_category_secondary >= 0 and item_cat == accepted_category_secondary:
		return true
	return false

## Add an item to the bag. Returns true if successful.
func add_to_bag(item: Item) -> bool:
	if not can_hold(item):
		return false
	# Try stacking with existing items
	if item.is_stackable():
		for existing: Item in items:
			if existing.can_stack_with(item):
				existing.merge_stack(item)
				return true
	items.append(item)
	return true

## Remove an item from the bag. Returns the removed item or null.
func remove_from_bag(item: Item) -> Item:
	var idx: int = items.find(item)
	if idx >= 0:
		items.remove_at(idx)
		return item
	return null

## Get the number of items currently in the bag.
func item_count() -> int:
	return items.size()

## Check if the bag has space for more items.
func has_space() -> bool:
	return items.size() < size

## Find an item in the bag by item_id.
func find_item(search_id: String) -> Item:
	for item: Item in items:
		if item.item_id == search_id:
			return item
	return null

# ---------------------------------------------------------------------------
# Pickup / Display
# ---------------------------------------------------------------------------

func on_pickup(_hero: Char) -> void:
	if MessageLog:
		MessageLog.add_positive("You now have a %s!" % item_name)

func get_display_name() -> String:
	return "%s (%d/%d)" % [item_name, items.size(), size]

# ---------------------------------------------------------------------------
# Value
# ---------------------------------------------------------------------------

func value() -> int:
	return 50

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["_class"] = "Bag"
	data["size"] = size
	data["accepted_category"] = accepted_category
	data["accepted_category_secondary"] = accepted_category_secondary
	var items_data: Array[Dictionary] = []
	for item: Item in items:
		if item != null:
			items_data.append(item.serialize())
	data["items"] = items_data
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	size = data.get("size", 20)
	accepted_category = data.get("accepted_category", ConstantsData.ItemCategory.MISC)
	accepted_category_secondary = data.get("accepted_category_secondary", -1)
	# Items are deserialized by the item loading system

# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## Create a bag by ID.
static func create(bag_id: String) -> Bag:
	var bag: Bag = Bag.new()
	bag.item_id = bag_id

	match bag_id:
		"velvet_pouch":
			bag.item_name = "Velvet Pouch"
			bag.description = "A soft velvet pouch that can hold stones and seeds."
			bag.size = 20
			bag.accepted_category = ConstantsData.ItemCategory.STONE
			bag.accepted_category_secondary = ConstantsData.ItemCategory.SEED
			bag.icon_color = Color(0.6, 0.3, 0.5)

		"scroll_holder":
			bag.item_name = "Scroll Holder"
			bag.description = "A slim leather case designed to protect scrolls."
			bag.size = 20
			bag.accepted_category = ConstantsData.ItemCategory.SCROLL
			bag.icon_color = Color(0.8, 0.75, 0.55)

		"potion_bandolier":
			bag.item_name = "Potion Bandolier"
			bag.description = "A bandolier lined with padded slots for potions."
			bag.size = 20
			bag.accepted_category = ConstantsData.ItemCategory.POTION
			bag.icon_color = Color(0.4, 0.6, 0.8)

		"magical_holster":
			bag.item_name = "Magical Holster"
			bag.description = "A holster imbued with magic. Holds wands and missile weapons."
			bag.size = 20
			bag.accepted_category = ConstantsData.ItemCategory.WAND
			# Missile weapons would use WEAPON category but are a subtype;
			# for now we accept wands as primary. Missiles handled via can_hold override.
			bag.icon_color = Color(0.5, 0.4, 0.7)

		_:
			bag.item_name = "Bag"
			bag.description = "A plain bag."
			bag.size = 20

	return bag
