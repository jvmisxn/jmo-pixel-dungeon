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
func _revive_unblessed(hero: Char) -> bool:
	hero.is_alive = true
	@warning_ignore("integer_division")
	var revive_hp: int = maxi(1, hero.hp_max / 4)
	hero.hp = revive_hp

	# Lose all unequipped items in the backpack
	if hero.get("belongings") != null:
		hero.belongings.backpack.clear()

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
		MessageLog.add_warning("The ankh shatters! You return to life, but your belongings are lost!")
	if GameManager:
		GameManager.record_stat("ankhs_used")

	# Consume the ankh (already removed from backpack via clear)
	return true

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
