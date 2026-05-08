class_name Item
extends RefCounted
## Base class for all items in the game. Provides common properties, identification,
## upgrade logic, stacking, curse handling, and serialization. All concrete items
## extend this class and override virtual methods for specific behavior.

# --- Core Properties ---
## Unique string identifier used for serialization and factory lookup.
var item_id: String = ""
## Human-readable name shown in the UI.
var item_name: String = "Item"
## Flavor / info text shown in item details.
var description: String = ""
## Broad category this item belongs to.
var category: int = ConstantsData.ItemCategory.MISC
## Upgrade level (+1, +2, etc.). Negative means degraded.
var level: int = 0
## Whether this item bears a curse.
var cursed: bool = false
## Whether the player has discovered the cursed status.
var cursed_known: bool = false
## Whether the player knows the upgrade level.
var level_known: bool = false
## Whether the item has been fully identified (both level_known and cursed_known).
var identified: bool = false
## Whether this item can be included in hero's remains (bones).
var bones: bool = false
## Preserved through lost inventory via unblessed ankh.
var kept_though_lost_invent: bool = false
## Whether this item type can stack (seeds, potions, thrown weapons, etc.).
var stackable: bool = false
## Current stack quantity (only meaningful when stackable is true).
var quantity: int = 1
## Default action string shown on the item button (e.g. "THROW", "DRINK").
var default_action: String = ""
## Minimum hero strength required to use without penalty.
var str_requirement: int = 0
## Tint color used for procedural icon rendering.
var icon_color: Color = Color.WHITE
## Whether only one instance of this item can exist in a run.
var unique: bool = false

# ---------------------------------------------------------------------------
# Equipment Interface (virtual)
# ---------------------------------------------------------------------------

## Whether this item can be equipped in a slot. Override in equippable subclasses.
func is_equippable() -> bool:
	return false

## Called when the item is equipped by a hero.
func on_equip(_hero: Char) -> void:
	if EventBus:
		EventBus.item_equipped.emit(get_display_name(), _slot_name())

## Called when the item is unequipped from a hero.
func on_unequip(_hero: Char) -> void:
	if EventBus:
		EventBus.item_unequipped.emit(get_display_name(), _slot_name())

## Called when the item is picked up by a hero.
func on_pickup(_hero: Char) -> void:
	if EventBus:
		EventBus.item_picked_up.emit(get_display_name())
	if GameManager:
		GameManager.record_stat("items_collected")

## Called when the item is dropped on the ground.
func on_drop(_hero: Char) -> void:
	pass

## Primary action when the player taps/clicks the item in inventory.
func execute(_hero: Char) -> void:
	pass

## Secondary use action (virtual — subclasses define behavior).
func use(_hero: Char) -> void:
	pass

## Helper to determine the equipment slot name for EventBus signals.
func _slot_name() -> String:
	match category:
		ConstantsData.ItemCategory.WEAPON:
			return "weapon"
		ConstantsData.ItemCategory.ARMOR:
			return "armor"
		ConstantsData.ItemCategory.RING:
			return "ring"
		ConstantsData.ItemCategory.ARTIFACT:
			return "artifact"
		ConstantsData.ItemCategory.WAND:
			return "misc"
	return "misc"

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

## Returns the display name, accounting for identification, upgrades, and curses.
func get_display_name() -> String:
	var display: String = item_name
	var vis_lvl: int = visibly_upgraded()
	if vis_lvl != 0:
		if vis_lvl > 0:
			display = "%s +%d" % [item_name, vis_lvl]
		else:
			display = "%s %d" % [item_name, vis_lvl]
	if cursed_known and cursed:
		display = "cursed " + display
	if stackable and quantity > 1:
		display = "%s (%d)" % [display, quantity]
	return display

# ---------------------------------------------------------------------------
# Stacking
# ---------------------------------------------------------------------------

## Whether this item can be stacked with others of the same type.
func is_stackable() -> bool:
	return stackable

## Whether this item can stack with another specific item.
func can_stack_with(other: Item) -> bool:
	if not is_stackable():
		return false
	if other == null:
		return false
	if not other.is_stackable():
		return false
	return item_id == other.item_id and level == other.level

## Merge another item's stack into this one.
func merge_stack(other: Item) -> void:
	if other == null:
		return
	quantity += other.quantity
	other.quantity = 0

## Split off a new item with the given amount from this stack.
## Returns a new Item with the split quantity, or null if invalid.
func split(amount: int) -> Item:
	if amount <= 0 or amount >= quantity:
		return null
	var clone: Item = duplicate_item()
	clone.quantity = amount
	quantity -= amount
	return clone

## Create a copy of this item (used internally by split).
func duplicate_item() -> Item:
	var copy: Item = Item.new()
	_copy_base_properties(copy)
	return copy

## Copy all base properties to another item.
func _copy_base_properties(target: Item) -> void:
	target.item_id = item_id
	target.item_name = item_name
	target.description = description
	target.category = category
	target.level = level
	target.cursed = cursed
	target.cursed_known = cursed_known
	target.level_known = level_known
	target.identified = identified
	target.bones = bones
	target.kept_though_lost_invent = kept_though_lost_invent
	target.stackable = stackable
	target.quantity = quantity
	target.default_action = default_action
	target.unique = unique
	target.str_requirement = str_requirement
	target.icon_color = icon_color

# ---------------------------------------------------------------------------
# Identification & Curse
# ---------------------------------------------------------------------------

## Whether the item has been fully identified (level and curse both known).
func is_identified() -> bool:
	return level_known and cursed_known

## Identify this item, revealing its true properties. Returns self for chaining.
func identify() -> Item:
	level_known = true
	cursed_known = true
	identified = true
	return self

## Returns the visible upgrade level (0 if level not known).
func visibly_upgraded() -> int:
	return level if level_known else 0

## Returns true if the item is visibly cursed.
func visibly_cursed() -> bool:
	return cursed and cursed_known

## Returns the true level (ignoring temporary modifiers).
func true_level() -> int:
	return level

## Returns the buffed level (accounting for Degrade debuff).
## Override in subclasses that support curse infusion bonus.
func buffed_lvl() -> int:
	# TODO: Check for Degrade debuff when hero buff system supports it
	return level

## Resets item properties between runs (e.g. for bones items).
func reset_item() -> void:
	kept_though_lost_invent = false

## Whether this item should be kept through lost inventory.
func kept_through_lost_inventory() -> bool:
	return kept_though_lost_invent

## Returns true only if the player knows it is cursed.
func is_cursed() -> bool:
	return cursed and cursed_known

## Returns the actual cursed state regardless of player knowledge.
func is_actually_cursed() -> bool:
	return cursed

# ---------------------------------------------------------------------------
# Upgrade & Degrade
# ---------------------------------------------------------------------------

## Whether this item can be upgraded (scrolls of upgrade, etc.).
func is_upgradeable() -> bool:
	return true

## Upgrade the item by one level. Removes curses. Returns self for chaining.
func upgrade() -> Item:
	level += 1
	if cursed:
		cursed = false
		cursed_known = true
	return self

## Degrade the item by one level. Returns self for chaining.
func degrade() -> Item:
	level -= 1
	return self

# ---------------------------------------------------------------------------
# Value
# ---------------------------------------------------------------------------

## Gold value of this item for shops. Base formula: 5 * (level + 1).
func value() -> int:
	var base: int = 5 * (level + 1)
	if stackable:
		base *= quantity
	return maxi(1, base)

# ---------------------------------------------------------------------------
# Strength Requirement
# ---------------------------------------------------------------------------

## Returns true if the hero's strength meets or exceeds the requirement.
func str_requirement_met(hero_str: int) -> bool:
	return hero_str >= str_requirement

# ---------------------------------------------------------------------------
# Damage / Armor helpers (duck typing interface for Belongings)
# ---------------------------------------------------------------------------

## Override in weapon subclasses to return [min, max] damage.
func get_damage_range() -> Array[int]:
	return [0, 0]

## Override in armor subclasses to return armor DR value.
func get_armor_value() -> int:
	return 0

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

## Serialize this item to a dictionary for saving.
func serialize() -> Dictionary:
	return {
		"item_id": item_id,
		"item_name": item_name,
		"description": description,
		"category": category,
		"level": level,
		"cursed": cursed,
		"cursed_known": cursed_known,
		"identified": identified,
		"quantity": quantity,
		"stackable": stackable,
		"unique": unique,
	}
