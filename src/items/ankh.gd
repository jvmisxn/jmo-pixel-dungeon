class_name Ankh
extends Item
## The Ankh prevents death once. When the hero would die while holding an Ankh,
## it is consumed and the hero is revived. A blessed Ankh (via Dew Vial) revives
## with half HP and keeps all items. An unblessed Ankh revives but the hero
## loses all unequipped items.

# --- Properties ---
## Whether the ankh has been blessed with a Dew Vial.
var blessed: bool = false

func _init() -> void:
	item_id = "ankh"
	item_name = "Ankh"
	description = "An ancient golden ankh. Prevents death once. Bless it with a Dew Vial for a better revival."
	category = ConstantsData.ItemCategory.MISC
	stackable = false
	unique = false
	identified = true
	cursed_known = true
	# SPD: ankhs can appear in a previous hero's remains.
	bones = true
	icon_color = Color(1.0, 0.85, 0.2)
	default_action = "INFO"

func is_upgradeable() -> bool:
	return false

func is_stackable() -> bool:
	return false

# ---------------------------------------------------------------------------
# Blessing
# ---------------------------------------------------------------------------

## Bless this ankh with a Dew Vial, upgrading its revival power.
func bless() -> void:
	blessed = true
	item_name = "Blessed Ankh"
	description = "A blessed ankh radiating golden light. Will revive you with half HP and preserve all your items."
	icon_color = Color(1.0, 1.0, 0.6)
	if MessageLog:
		MessageLog.add_positive("The ankh glows with a warm, golden light!")

# ---------------------------------------------------------------------------
# Revival
# ---------------------------------------------------------------------------

## Attempt to revive the hero. Called by the death system when an Ankh is present.
## Returns true if revival was successful.
func revive(hero: Char) -> bool:
	if hero == null:
		return false

	if blessed:
		return _revive_blessed(hero)
	else:
		return _revive_unblessed(hero)

## Blessed revival: restore half HP, keep all items.
func _revive_blessed(hero: Char) -> bool:
	hero.is_alive = true
	@warning_ignore("integer_division")
	var half_hp: int = maxi(1, hero.hp_max / 2)
	hero.hp = half_hp

	# Satisfy hunger fully
	if hero.has_method("get_buff"):
		var hunger: Variant = hero.get_buff("Hunger")
		if hunger != null and hunger.has_method("fully_satisfy"):
			hunger.fully_satisfy()

	# Remove all debuffs
	if hero.has_method("get_buffs"):
		for buff: Node in hero.get_buffs():
			if buff.get("is_debuff") == true:
				if hero.has_method("remove_buff"):
					hero.remove_buff(buff)

	if MessageLog:
		MessageLog.add_positive("The blessed ankh shatters and restores you to life!")
	if GameManager:
		GameManager.record_stat("ankhs_used")

	# Consume the ankh
	_remove_self(hero)
	return true

## Unblessed revival: restore some HP, but lose all backpack items.
## SPD's lost-inventory contract (adapted): unique items, bags, and anything
## flagged kept-through-lost-inventory stay with the hero; everything else is
## dropped as a recoverable heap where the hero fell instead of being destroyed.
## (Upstream instead applies a LostInventory buff and drops a LostBackpack to
## retrieve, with a two-item keep choice in WndResurrect — not ported yet.)
func _revive_unblessed(hero: Char) -> bool:
	hero.is_alive = true
	@warning_ignore("integer_division")
	var revive_hp: int = maxi(1, hero.hp_max / 4)
	hero.hp = revive_hp

	_lose_backpack_items(hero)

	# Satisfy hunger
	if hero.has_method("get_buff"):
		var hunger: Variant = hero.get_buff("Hunger")
		if hunger != null and hunger.has_method("fully_satisfy"):
			hunger.fully_satisfy()

	# Remove all debuffs
	if hero.has_method("get_buffs"):
		for buff: Node in hero.get_buffs():
			if buff.get("is_debuff") == true:
				if hero.has_method("remove_buff"):
					hero.remove_buff(buff)

	if MessageLog:
		MessageLog.add_warning("The ankh shatters! You return to life, but your belongings scatter around you!")
	if GameManager:
		GameManager.record_stat("ankhs_used")

	# Consume the ankh
	_remove_self(hero)
	return true

## Drop every non-kept backpack item (including held-bag contents) at the hero's
## position as recoverable heaps. The consumed ankh itself is never dropped.
func _lose_backpack_items(hero: Char) -> void:
	if hero.get("belongings") == null:
		return
	var belongings: Variant = hero.belongings
	var lost_items: Array[Item] = []
	for item: Item in belongings.backpack.duplicate():
		if item == self:
			continue
		if item is Bag:
			# Bags are kept (unique), but their contents follow the same rules.
			for held: Item in (item as Bag).items.duplicate():
				if held == self or _is_kept(held):
					continue
				belongings.remove_item(held)
				lost_items.append(held)
			continue
		if _is_kept(item):
			continue
		belongings.remove_item(item)
		lost_items.append(item)

	if lost_items.is_empty():
		return
	var level: Variant = hero.get("level")
	if level == null and GameManager != null:
		level = GameManager.current_level
	if level != null and level.has_method("drop_item"):
		for item: Item in lost_items:
			level.drop_item(int(hero.pos), item)

## Items that survive an unblessed revival in the hero's inventory.
func _is_kept(item: Item) -> bool:
	return item.unique or item.kept_through_lost_inventory()

## Remove the ankh from the hero's inventory.
func _remove_self(hero: Char) -> void:
	if hero != null and hero.get("belongings") != null:
		hero.belongings.remove_item(self)

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

## Execute shows info about the ankh status.
func execute(_hero: Char) -> void:
	if MessageLog:
		if blessed:
			MessageLog.add_info("This blessed ankh will revive you with half HP and all your items.")
		else:
			MessageLog.add_info("This ankh will revive you, but you will lose your unequipped items. Bless it with a Dew Vial!")

func on_pickup(_hero: Char) -> void:
	if MessageLog:
		if blessed:
			MessageLog.add_positive("You pick up a blessed ankh!")
		else:
			MessageLog.add("You pick up an ankh.")

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

func get_display_name() -> String:
	if blessed:
		return "Blessed Ankh"
	return "Ankh"

# ---------------------------------------------------------------------------
# Value
# ---------------------------------------------------------------------------

func value() -> int:
	if blessed:
		return 100
	return 50

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["_class"] = "Ankh"
	data["blessed"] = blessed
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	blessed = data.get("blessed", false)
	if blessed:
		item_name = "Blessed Ankh"
		icon_color = Color(1.0, 0.85, 0.0)
