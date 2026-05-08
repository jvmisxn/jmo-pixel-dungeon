class_name Dewdrop
extends Item
## A small dewdrop that heals 1-3 HP on pickup. Dewdrops are auto-collected
## when walked over and do not take up inventory space. Stackable for storage
## in a Dew Vial if one is present.

func _init() -> void:
	item_id = "dewdrop"
	item_name = "Dewdrop"
	description = "A shimmering drop of dew. Heals a tiny amount when collected."
	category = ConstantsData.ItemCategory.MISC
	stackable = true
	identified = true
	cursed_known = true
	icon_color = Color(0.4, 0.8, 1.0)
	default_action = "PICK UP"
	unique = false

func is_upgradeable() -> bool:
	return false

# ---------------------------------------------------------------------------
# Pickup (auto-collect behavior)
# ---------------------------------------------------------------------------

## When picked up, heal the hero for 1-3 HP immediately.
## Dewdrops do not go into the regular inventory; they are consumed on contact.
func on_pickup(hero: Char) -> void:
	if hero == null:
		return
	var heal_amount: int = randi_range(1, 3)
	if hero.has_method("heal"):
		hero.heal(heal_amount)
	if MessageLog:
		MessageLog.add_positive("The dewdrop heals you for %d HP." % heal_amount)
	if GameManager:
		GameManager.record_stat("healing_done", heal_amount)
	# Dewdrops are consumed on pickup -- do NOT add to inventory.
	# The caller (heap/level) should check for this behavior.

## Execute does nothing special; dewdrops are auto-consumed on pickup.
func execute(_hero: Char) -> void:
	pass

## Dewdrops have no sell value.
func value() -> int:
	return 0

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

func get_display_name() -> String:
	if quantity > 1:
		return "Dewdrop x%d" % quantity
	return "Dewdrop"

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["_class"] = "Dewdrop"
	return data
