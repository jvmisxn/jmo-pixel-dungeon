class_name AmuletOfYendor
extends Item
## The Amulet of Yendor -- the ultimate prize at the bottom of the dungeon.
## Picking it up and using it triggers the victory sequence. There is only one
## per run. It cannot be dropped, sold, or destroyed.

func _init() -> void:
	item_id = "amulet_of_yendor"
	item_name = "Amulet of Yendor"
	description = "The legendary Amulet of Yendor. Its golden surface pulses with immense power. With this, you can ascend and claim victory."
	category = ConstantsData.ItemCategory.MISC
	stackable = false
	unique = true
	identified = true
	cursed_known = true
	icon_color = Color(1.0, 0.9, 0.3)
	default_action = "END"
	str_requirement = 0

func is_upgradeable() -> bool:
	return false

func is_stackable() -> bool:
	return false

# ---------------------------------------------------------------------------
# Pickup
# ---------------------------------------------------------------------------

func on_pickup(_hero: Char) -> void:
	if MessageLog:
		MessageLog.add_positive("You pick up the Amulet of Yendor!")
		MessageLog.add_info("Ascend back to the surface to claim victory!")
	if EventBus:
		EventBus.item_picked_up.emit(item_name)

# ---------------------------------------------------------------------------
# Execution -- trigger the victory sequence
# ---------------------------------------------------------------------------

## Using the amulet triggers the victory ending.
func execute(_hero: Char) -> void:
	if MessageLog:
		MessageLog.add_positive("You hold the Amulet of Yendor aloft!")
		MessageLog.add_positive("Light floods the dungeon as the ancient power is unleashed!")
	if GameManager:
		GameManager.end_game(true)

# ---------------------------------------------------------------------------
# Prevent dropping / selling
# ---------------------------------------------------------------------------

## The amulet has no gold value (cannot be sold).
func value() -> int:
	return 0

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

func get_display_name() -> String:
	return "Amulet of Yendor"

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["_class"] = "AmuletOfYendor"
	return data
