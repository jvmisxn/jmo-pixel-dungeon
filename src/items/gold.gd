class_name Gold
extends Item
## Gold currency item. Automatically adds to the hero's gold total on pickup.
## Stackable and quantity-based. Cannot be upgraded.

func _init(amount: int = 1) -> void:
	item_id = "gold"
	item_name = "Gold"
	description = "A pile of gold coins."
	category = ConstantsData.ItemCategory.GOLD
	stackable = true
	quantity = amount
	identified = true
	cursed_known = true
	icon_color = Color.GOLD
	default_action = "PICK UP"
	unique = false
	str_requirement = 0

## Gold is never upgradeable.
func is_upgradeable() -> bool:
	return false

## Override upgrade to no-op (safety).
func upgrade() -> Item:
	return self

## Override degrade to no-op (safety).
func degrade() -> Item:
	return self

## On pickup, add gold to the GameManager and log a message.
func on_pickup(hero: Char) -> void:
	if GameManager:
		GameManager.add_gold(quantity)
	if MessageLog:
		MessageLog.add_positive("You collected %d gold." % quantity)
	# Do NOT call super — gold doesn't go into inventory, it goes straight
	# to the gold counter. EventBus signal is fired by GameManager.add_gold().

## Gold's sell value is just its quantity (it IS currency).
func value() -> int:
	return quantity

## Display name shows the quantity.
func get_display_name() -> String:
	if quantity == 1:
		return "Gold"
	return "%d gold" % quantity

## Create a copy of this gold item.
func duplicate_item() -> Item:
	var copy: Gold = Gold.new(quantity)
	copy.level = level
	return copy

## Serialize gold-specific data.
func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["_class"] = "Gold"
	return data
