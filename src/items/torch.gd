class_name Torch
extends Item
## A torch that increases the hero's view distance by 2 for 200 turns when
## activated. Torches are stackable consumables, primarily useful in darker
## dungeon regions.

# --- Constants ---
const LIGHT_BONUS: int = 2
const LIGHT_DURATION: float = 200.0

func _init() -> void:
	item_id = "torch"
	item_name = "Torch"
	description = "A wooden torch soaked in pitch. Light it to see further in the dark for a while."
	category = ConstantsData.ItemCategory.MISC
	stackable = true
	identified = true
	cursed_known = true
	icon_color = Color(1.0, 0.7, 0.2)
	default_action = "LIGHT"
	unique = false

func is_upgradeable() -> bool:
	return false

# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------

## Light the torch, granting increased view distance.
func execute(hero: Char) -> void:
	if hero == null:
		return
	_light(hero)
	if EventBus:
		EventBus.item_used.emit(item_name)
	_consume_one(hero)

## Apply the torch's light buff to the hero.
func _light(hero: Char) -> void:
	if hero.has_method("add_buff"):
		var light_buff: TorchLight = TorchLight.new()
		light_buff.set_duration(LIGHT_DURATION)
		hero.add_buff(light_buff)
	if MessageLog:
		MessageLog.add_positive("You light the torch! The darkness recedes.")

## Remove one from the stack.
func _consume_one(hero: Char) -> void:
	quantity -= 1
	if quantity <= 0:
		if hero != null and hero.get("belongings") != null:
			hero.belongings.remove_item(self)

# ---------------------------------------------------------------------------
# Pickup
# ---------------------------------------------------------------------------

func on_pickup(_hero: Char) -> void:
	if MessageLog:
		MessageLog.add("You pick up a torch.")

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

func get_display_name() -> String:
	if quantity > 1:
		return "Torch x%d" % quantity
	return "Torch"

# ---------------------------------------------------------------------------
# Value
# ---------------------------------------------------------------------------

func value() -> int:
	return 10 * quantity

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["_class"] = "Torch"
	return data


# ==========================================================================
# TorchLight Buff (inner helper)
# ==========================================================================

## Buff that increases the hero's view distance while a torch is lit.
## Defined here to keep torch logic self-contained.
class TorchLight:
	extends Buff

	func _init() -> void:
		buff_id = "TorchLight"
		buff_name = "Torch Light"
		is_debuff = false
		icon_color = Color(1.0, 0.7, 0.2)

	func on_attach() -> void:
		if MessageLog:
			pass  # Light message handled by torch

	func on_detach() -> void:
		if MessageLog:
			MessageLog.add("The torch burns out.")

	## Modify view distance: add LIGHT_BONUS cells.
	func modify_view_distance(dist: int) -> int:
		return dist + Torch.LIGHT_BONUS

	func description() -> String:
		return "Torch illumination. +%d view distance." % Torch.LIGHT_BONUS
