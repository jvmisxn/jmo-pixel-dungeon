class_name Belongings
extends RefCounted
## Manages the hero's inventory, equipment slots, and quickslots.
## Designed to work with Item nodes (Phase 3) via duck typing.

## Maximum inventory capacity.
const MAX_INVENTORY: int = 20
## Number of quickslot positions.
const QUICKSLOT_COUNT: int = 6

# --- Equipment Slots ---
## Currently equipped weapon (Item subclass or null).
var weapon: Item = null
## Currently equipped armor (Item subclass or null).
var armor: Item = null
## Currently equipped artifact (Item subclass or null).
var artifact: Item = null
## Currently equipped misc item (Item subclass or null).
var misc: Item = null
## Huntress spirit bow slot. Separate from melee weapon so ranged combat is explicit.
var spirit_bow: Item = null
## Currently equipped ring (left hand).
var ring_left: Item = null
## Currently equipped ring (right hand).
var ring_right: Item = null

# --- Inventory ---
## Array of item nodes in the backpack.
var backpack: Array[Item] = []

# --- Quickslots ---
## References to items assigned to quickslots.
var quickslots: Array[Item] = []

# --- Owner ---
var owner: Char = null

func _init(hero: Char = null) -> void:
	owner = hero
	quickslots.resize(QUICKSLOT_COUNT)

# ---------------------------------------------------------------------------
# Inventory Management
# ---------------------------------------------------------------------------

## Add an item to the inventory. Returns true if successful.
func add_item(item: Item) -> bool:
	if item == null:
		return false
	# Route matching pickups into a held bag before consuming a backpack slot.
	# A bag never nests inside another bag.
	if not (item is Bag):
		var bag: Bag = _bag_that_accepts(item)
		if bag != null and bag.add_to_bag(item):
			if item.has_method("on_pickup"):
				item.on_pickup(owner)
			return true
	# Try to stack with existing items
	if item.has_method("is_stackable") and item.is_stackable():
		for existing in backpack:
			if existing.has_method("can_stack_with") and existing.can_stack_with(item):
				if existing.has_method("merge_stack"):
					existing.merge_stack(item)
					return true
	# Check capacity
	if backpack.size() >= MAX_INVENTORY:
		if MessageLog:
			MessageLog.add_warning("Your inventory is full!")
		return false
	backpack.append(item)
	if item.has_method("on_pickup"):
		item.on_pickup(owner)
	return true

## Return the first bag in the backpack that will accept [item], or null.
func _bag_that_accepts(item: Item) -> Bag:
	for entry: Item in backpack:
		if entry is Bag and (entry as Bag).can_hold(item):
			return entry as Bag
	return null

## Backpack items plus the contents of any bags, as a flat snapshot. Used by
## lookups so items tucked inside a bag stay reachable to the rest of the game.
func _all_backpack_items() -> Array[Item]:
	var result: Array[Item] = []
	for entry: Item in backpack:
		result.append(entry)
		if entry is Bag:
			result.append_array((entry as Bag).items)
	return result

## Clear an item from every quickslot it occupies.
func _clear_from_quickslots(item: Item) -> void:
	for i: int in range(QUICKSLOT_COUNT):
		if quickslots[i] == item:
			quickslots[i] = null

## Remove a specific item object from the backpack or from whichever bag holds
## it. Returns true if it was found and removed.
func _remove_item_object(item: Item) -> bool:
	var idx: int = backpack.find(item)
	if idx >= 0:
		backpack.remove_at(idx)
		_clear_from_quickslots(item)
		return true
	for entry: Item in backpack:
		if entry is Bag and (entry as Bag).remove_from_bag(item) != null:
			_clear_from_quickslots(item)
			return true
	return false

## Remove an item from inventory. Returns the item or null.
func remove_item(item: Item) -> Item:
	if _remove_item_object(item):
		return item
	return null

## Check if an item is in the inventory (backpack or a held bag).
func has_item(item: Item) -> bool:
	if item in backpack:
		return true
	for entry: Item in backpack:
		if entry is Bag and item in (entry as Bag).items:
			return true
	return false

## Find an item by its class name or item_id.
func find_item_by_id(search_id: String) -> Item:
	for item: Item in _all_backpack_items():
		if item.item_id == search_id:
			return item
	# Also check equipped items
	var slots: Array[Item] = [weapon, armor, artifact, misc, spirit_bow, ring_left, ring_right]
	for slot: Item in slots:
		if slot != null and slot.item_id == search_id:
			return slot
	return null

## Returns true if any item with the given item_id is in inventory or equipped.
func has_item_by_id(search_id: String) -> bool:
	return find_item_by_id(search_id) != null

## Get current inventory count.
func item_count() -> int:
	return backpack.size()

## Check if inventory has space.
func has_space() -> bool:
	return backpack.size() < MAX_INVENTORY

# ---------------------------------------------------------------------------
# Equipment
# ---------------------------------------------------------------------------

## Equip a weapon. Returns the previously equipped weapon (or null).
func equip_weapon(new_weapon: Item) -> Item:
	var old: Item = weapon
	weapon = new_weapon
	if new_weapon and new_weapon.has_method("on_equip"):
		new_weapon.on_equip(owner)
	if old and old.has_method("on_unequip"):
		old.on_unequip(owner)
	return old

## Equip armor. Returns the previously equipped armor (or null).
func equip_armor(new_armor: Item) -> Item:
	var old: Item = armor
	armor = new_armor
	if new_armor and new_armor.has_method("on_equip"):
		new_armor.on_equip(owner)
	if old and old.has_method("on_unequip"):
		old.on_unequip(owner)
	return old

## Equip artifact. Returns the previously equipped artifact (or null).
func equip_artifact(new_artifact: Item) -> Item:
	var old: Item = artifact
	artifact = new_artifact
	if new_artifact and new_artifact.has_method("on_equip"):
		new_artifact.on_equip(owner)
	if old and old.has_method("on_unequip"):
		old.on_unequip(owner)
	return old

## Equip a misc item such as a wand. Returns the previously equipped misc item.
func equip_misc(new_misc: Item) -> Item:
	var old: Item = misc
	misc = new_misc
	if new_misc and new_misc.has_method("on_equip"):
		new_misc.on_equip(owner)
	if old and old.has_method("on_unequip"):
		old.on_unequip(owner)
	return old

## Equip the Huntress spirit bow. Returns the previously slotted bow, if any.
func equip_spirit_bow(new_bow: Item) -> Item:
	var old: Item = spirit_bow
	spirit_bow = new_bow
	if new_bow and new_bow.has_method("on_equip"):
		new_bow.on_equip(owner)
	if old and old.has_method("on_unequip"):
		old.on_unequip(owner)
	return old

## Equip ring to left or right hand. Returns the old ring.
func equip_ring(new_ring: Item, left: bool = true) -> Item:
	var old: Item
	if left:
		old = ring_left
		ring_left = new_ring
	else:
		old = ring_right
		ring_right = new_ring
	if new_ring and new_ring.has_method("on_equip"):
		new_ring.on_equip(owner)
	if old and old.has_method("on_unequip"):
		old.on_unequip(owner)
	return old

## Unequip from a given slot name. Returns the removed item.
func unequip(slot: String) -> Item:
	var item: Item = null
	match slot:
		"weapon":
			item = weapon
			weapon = null
		"armor":
			item = armor
			armor = null
		"artifact":
			item = artifact
			artifact = null
		"misc":
			item = misc
			misc = null
		"spirit_bow":
			item = spirit_bow
			spirit_bow = null
		"ring_left":
			item = ring_left
			ring_left = null
		"ring_right":
			item = ring_right
			ring_right = null
	if item and item.has_method("on_unequip"):
		item.on_unequip(owner)
	return item

## Get total armor value from equipped armor and rings.
func total_armor() -> int:
	var total: int = 0
	if armor and armor.has_method("get_armor_value"):
		total += armor.get_armor_value()
	return total

## Get weapon damage range [min, max].
func weapon_damage_range() -> Array[int]:
	if weapon and weapon.has_method("get_damage_range"):
		return weapon.get_damage_range()
	# Unarmed
	return [1, owner.str_val] if owner else [1, 4]

# ---------------------------------------------------------------------------
# Quickslots
# ---------------------------------------------------------------------------

## Assign an item to a quickslot.
func set_quickslot(slot_idx: int, item: Item) -> void:
	if slot_idx < 0 or slot_idx >= QUICKSLOT_COUNT:
		return
	for i: int in range(QUICKSLOT_COUNT):
		if i != slot_idx and quickslots[i] == item:
			quickslots[i] = null
	quickslots[slot_idx] = item
	if EventBus:
		EventBus.hero_stats_changed.emit()

## Get item in a quickslot.
func get_quickslot(slot_idx: int) -> Item:
	if slot_idx < 0 or slot_idx >= QUICKSLOT_COUNT:
		return null
	return quickslots[slot_idx]

func clear_quickslot(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= QUICKSLOT_COUNT:
		return
	quickslots[slot_idx] = null
	if EventBus:
		EventBus.hero_stats_changed.emit()

func get_quickslot_index(item: Item) -> int:
	for i: int in range(QUICKSLOT_COUNT):
		if quickslots[i] == item:
			return i
	return -1

# ---------------------------------------------------------------------------
# Lookup Helpers
# ---------------------------------------------------------------------------

## Find an item by its item_name (e.g. "ankh"). Checks backpack then equipment.
func find_item(search_name: String) -> Item:
	for item: Item in _all_backpack_items():
		if item.item_name == search_name:
			return item
		if item.item_id == search_name:
			return item
	var slots: Array[Item] = [weapon, armor, artifact, misc, spirit_bow, ring_left, ring_right]
	for slot: Item in slots:
		if slot != null:
			if slot.item_name == search_name or slot.item_id == search_name:
				return slot
	return null

## Return the currently equipped weapon.
func get_equipped_weapon() -> Item:
	return weapon

## Return the currently equipped armor.
func get_equipped_armor() -> Item:
	return armor

## Return the currently equipped artifact.
func get_equipped_artifact() -> Item:
	return artifact

## Return the equipped spirit bow, if any.
func get_equipped_spirit_bow() -> Item:
	return spirit_bow

## Return all items (backpack + equipped). Useful for NPC quests scanning inventory.
func get_items() -> Array[Item]:
	var result: Array[Item] = _all_backpack_items()
	for slot in [weapon, armor, artifact, misc, spirit_bow, ring_left, ring_right]:
		if slot != null:
			result.append(slot)
	return result

## Alias for get_items() — used by scroll effects.
func get_all_items() -> Array[Item]:
	return get_items()

## Recharge every wand the hero is carrying or has equipped.
func recharge_wands(turns: int = 1) -> void:
	for item: Item in get_items():
		if item != null and item.has_method("recharge"):
			var wand: Variant = item
			wand.recharge(turns, owner)

## Notify carried items (wands) that the hero earned XP so their use-based
## identification pools can regenerate. Mirrors SPD Hero.earnExp iterating
## belongings and calling Item.onHeroGainExp(levelPercent, hero).
func notify_hero_gain_exp(level_percent: float) -> void:
	for item: Item in get_items():
		if item != null and item.has_method("on_hero_gain_exp"):
			item.on_hero_gain_exp(level_percent)

## Count items with the given item_id in backpack.
func count_item(search_id: String) -> int:
	var count: int = 0
	for item: Item in _all_backpack_items():
		if item.item_id == search_id:
			count += item.quantity if item.quantity > 0 else 1
	return count

## Remove the first item matching item_id from the backpack or a held bag.
## Returns the removed item or null.
func remove_item_by_id(search_id: String) -> Item:
	for item: Item in _all_backpack_items():
		if item.item_id == search_id:
			_remove_item_object(item)
			return item
	return null

## Remove up to [amount] quantity of items matching [search_id] from the
## backpack or any held bag. Returns the number of units removed.
func remove_item_quantity(search_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var remaining: int = amount
	# Snapshot so removing items mid-iteration is safe.
	for item: Item in _all_backpack_items():
		if remaining <= 0:
			break
		if item == null or item.item_id != search_id:
			continue
		var item_amount: int = item.quantity if item.stackable else 1
		var removed_here: int = mini(item_amount, remaining)
		remaining -= removed_here
		if item.stackable and item.quantity > removed_here:
			item.quantity -= removed_here
		else:
			_remove_item_object(item)
	return amount - remaining

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = {
		"backpack_count": backpack.size(),
	}
	# Serialize backpack items
	var items_data: Array[Dictionary] = []
	for item: Item in backpack:
		if item != null and item.has_method("serialize"):
			items_data.append(item.serialize())
	data["backpack"] = items_data

	# Serialize equipped items
	var slot_names: Array[String] = ["weapon", "armor", "artifact", "misc", "spirit_bow", "ring_left", "ring_right"]
	var slot_values: Array[Item] = [weapon, armor, artifact, misc, spirit_bow, ring_left, ring_right]
	for i: int in range(slot_names.size()):
		var slot_item: Item = slot_values[i]
		if slot_item != null and slot_item.has_method("serialize"):
			data[slot_names[i]] = slot_item.serialize()

	var quickslot_ids: Array[String] = []
	for item: Item in quickslots:
		quickslot_ids.append(item.item_id if item != null else "")
	data["quickslots"] = quickslot_ids

	return data

func deserialize(data: Dictionary) -> void:
	# Clear current backpack
	backpack.clear()

	# Restore backpack items
	var items_data: Variant = data.get("backpack", [])
	if items_data is Array:
		for item_data: Variant in items_data:
			if item_data is Dictionary:
				var item_id: String = item_data.get("item_id", "")
				if item_id != "":
					var item: Item = Generator.create_item(item_id) as Item
					if item != null:
						if item.has_method("deserialize"):
							item.deserialize(item_data)
						backpack.append(item)

	# Restore equipped items — assign directly to avoid triggering gameplay effects
	var slot_names: Array[String] = ["weapon", "armor", "artifact", "misc", "spirit_bow", "ring_left", "ring_right"]
	for slot_name: String in slot_names:
		var slot_data: Variant = data.get(slot_name, null)
		if slot_data is Dictionary:
			var item_id: String = slot_data.get("item_id", "")
			if item_id != "":
				var item: Item = Generator.create_item(item_id) as Item
				if item != null:
					if item.has_method("deserialize"):
						item.deserialize(slot_data)
					set(slot_name, item)

	quickslots.resize(QUICKSLOT_COUNT)
	quickslots.fill(null)
	var quickslot_ids: Variant = data.get("quickslots", [])
	if quickslot_ids is Array:
		for i: int in range(mini(QUICKSLOT_COUNT, quickslot_ids.size())):
			var item_id: String = str(quickslot_ids[i])
			if item_id == "":
				continue
			var resolved: Item = find_item_by_id(item_id)
			if resolved != null:
				quickslots[i] = resolved
