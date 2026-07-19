class_name CursingTrap
extends Trap
## Curses a random equipped item on the hero.

func _init() -> void:
	trap_name = "cursing trap"
	color = Color(0.3, 0.0, 0.3)

func _do_effect(triggerer: Variant, _level: Level) -> void:
	if MessageLog:
		MessageLog.add("A dark energy curses your equipment!")

	if triggerer == null:
		return

	var cursed_item: Item = _curse_equipped_item(triggerer)
	if cursed_item != null:
		if MessageLog:
			MessageLog.add_negative("Your %s is cursed!" % cursed_item.item_name)
		return

	# Fallback: apply hex debuff if we can't curse equipment
	if triggerer.has_method("add_buff"):
		var hex_buff: Hex = Hex.new()
		hex_buff.duration = 30.0
		hex_buff.time_left = 30.0
		triggerer.add_buff(hex_buff)

func _curse_equipped_item(triggerer: Variant) -> Item:
	var belongings: Variant = triggerer.get("belongings") if triggerer is Object else null
	if belongings == null:
		return null

	var priority: Array[Item] = []
	var fallback: Array[Item] = []
	var weapon: Item = belongings.get_equipped_weapon() if belongings.has_method("get_equipped_weapon") else null
	var armor: Item = belongings.get_equipped_armor() if belongings.has_method("get_equipped_armor") else null

	if weapon is Weapon and not (weapon is MagesStaff):
		if weapon.enchantment == null:
			priority.append(weapon)
		else:
			fallback.append(weapon)
	if armor is Armor:
		if not armor.has_glyph():
			priority.append(armor)
		else:
			fallback.append(armor)

	priority.shuffle()
	fallback.shuffle()
	if not priority.is_empty():
		return _curse_item(priority[0])
	if not fallback.is_empty():
		return _curse_item(fallback[0])
	return null

func _curse_item(item: Item) -> Item:
	item.cursed = true
	item.cursed_known = true
	if item is Weapon:
		var weapon: Weapon = item as Weapon
		if weapon.enchantment == null:
			weapon.enchant(WeaponEnchantment.random_curse())
	return item
