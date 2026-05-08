class_name WndItem
extends WndBase
## Item detail window showing name, description, stats, and context-sensitive action buttons.

var _item: Variant = null
var _hero: Hero = null
var _is_equipped: bool = false
@warning_ignore("unused_variable")
var _quickslot_idx: int = -1


func _init() -> void:
	window_title = "Item"
	custom_minimum_size = Vector2(340, 280)


## Call before adding to tree to configure the window.
func setup(item: Variant, hero: Hero, equipped: bool = false) -> void:
	_item = item
	_hero = hero
	_is_equipped = equipped


func _build_content() -> Control:
	if not _item:
		var empty: Label = Label.new()
		empty.text = "No item"
		return empty

	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)

	# --- Item Name (colored) ---
	var name_label: Label = Label.new()
	name_label.text = _get_display_name()
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", _get_name_color())
	main.add_child(name_label)

	# --- Icon (large colored rect placeholder) ---
	var icon_container: CenterContainer = CenterContainer.new()
	var icon_rect: ColorRect = ColorRect.new()
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.color = ConstantsData.get_prop(_item, "icon_color", Color.WHITE) if ConstantsData.get_prop(_item, "icon_color") else Color.GRAY
	icon_container.add_child(icon_rect)
	main.add_child(icon_container)

	# --- Description ---
	var desc_label: RichTextLabel = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.custom_minimum_size = Vector2(0, 40)
	desc_label.text = ConstantsData.get_prop(_item, "description", "No description available.")
	main.add_child(desc_label)

	# --- Stats ---
	if _item.has_method("get_stats_text"):
		var stats_text: String = _item.get_stats_text()
		if stats_text != "":
			var stats_label: Label = Label.new()
			stats_label.text = stats_text
			stats_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
			main.add_child(stats_label)

	# --- Level indicator ---
	var level_val: int = ConstantsData.get_prop(_item, "level", 0)
	if level_val > 0:
		var lvl_label: Label = Label.new()
		lvl_label.text = "Level: +%d" % level_val
		lvl_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		main.add_child(lvl_label)

	# --- Cursed indicator ---
	if ConstantsData.get_prop(_item, "cursed", false) and ConstantsData.get_prop(_item, "identified", false):
		var curse_label: Label = Label.new()
		curse_label.text = "This item is cursed!"
		curse_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		main.add_child(curse_label)

	# --- Separator ---
	var sep: HSeparator = HSeparator.new()
	main.add_child(sep)

	# --- Action Buttons ---
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_child(actions)

	_add_action_buttons(actions)

	return main


func _get_display_name() -> String:
	var text: String = ConstantsData.get_prop(_item, "item_name", "Unknown Item")
	var level_val: int = ConstantsData.get_prop(_item, "level", 0)
	if level_val > 0:
		text += " +%d" % level_val
	if ConstantsData.get_prop(_item, "cursed", false) and ConstantsData.get_prop(_item, "identified", false):
		text = "Cursed " + text
	if ConstantsData.get_prop(_item, "stackable", false) and ConstantsData.get_prop(_item, "quantity", 1) > 1:
		text += " x%d" % _item.quantity
	return text


func _get_name_color() -> Color:
	if ConstantsData.get_prop(_item, "cursed", false) and ConstantsData.get_prop(_item, "identified", false):
		return Color(1.0, 0.3, 0.3)
	var level_val: int = ConstantsData.get_prop(_item, "level", 0)
	if level_val > 0:
		return Color(0.3, 1.0, 0.5)
	if _item.has_method("is_upgradeable") and _item.is_upgradeable():
		return Color(1.0, 1.0, 1.0)
	return Color(0.85, 0.85, 0.85)


func _add_action_buttons(container: HBoxContainer) -> void:
	# Equip / Unequip
	if _item.has_method("is_equippable") and _item.is_equippable():
		if _is_equipped:
			_add_button(container, "Unequip", _action_unequip)
		else:
			_add_button(container, "Equip", _action_equip)

	# Use / Drink / Read / Eat based on category
	var cat: int = ConstantsData.get_prop(_item, "category", -1)
	match cat:
		ConstantsData.ItemCategory.POTION:
			_add_button(container, "Drink", _action_use)
		ConstantsData.ItemCategory.SCROLL:
			_add_button(container, "Read", _action_use)
		ConstantsData.ItemCategory.FOOD:
			_add_button(container, "Eat", _action_use)
		_:
			if (_item.has_method("execute") or _item.has_method("use")) and not (_item.has_method("is_equippable") and _item.is_equippable()):
				_add_button(container, "Use", _action_use)

	# Drop
	_add_button(container, "Drop", _action_drop)

	# Throw
	_add_button(container, "Throw", _action_throw)

	# Quickslot assignment
	_add_button(container, "Quickslot", _action_quickslot)


func _add_button(container: HBoxContainer, text: String, callback: Callable) -> void:
	var btn: Button = Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	container.add_child(btn)


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _action_equip() -> void:
	if not _hero or not _hero.belongings or not _item:
		close_window()
		return

	var cat: int = ConstantsData.get_prop(_item, "category", -1)
	# Remove from backpack first
	_hero.belongings.remove_item(_item)

	var old_item: Variant = null
	match cat:
		ConstantsData.ItemCategory.WEAPON:
			old_item = _hero.belongings.equip_weapon(_item)
		ConstantsData.ItemCategory.ARMOR:
			old_item = _hero.belongings.equip_armor(_item)
		ConstantsData.ItemCategory.ARTIFACT:
			old_item = _hero.belongings.equip_artifact(_item)
		ConstantsData.ItemCategory.RING:
			# Default to left ring, use right if left is occupied
			if _hero.belongings.ring_left == null:
				old_item = _hero.belongings.equip_ring(_item, true)
			else:
				old_item = _hero.belongings.equip_ring(_item, false)

	# Put old item back in backpack
	if old_item:
		_hero.belongings.add_item(old_item)

	if EventBus:
		EventBus.item_equipped.emit(ConstantsData.get_prop(_item, "item_name", ""), str(cat))
	close_window()


func _action_unequip() -> void:
	if not _hero or not _hero.belongings or not _item:
		close_window()
		return

	# Cannot unequip cursed items
	if ConstantsData.get_prop(_item, "cursed", false) and ConstantsData.get_prop(_item, "cursed_known", false):
		if MessageLog:
			MessageLog.add_warning("You cannot remove the cursed %s!" % ConstantsData.get_prop(_item, "item_name", "item"))
		return

	if not _hero.belongings.has_space():
		if MessageLog:
			MessageLog.add_warning("Your inventory is full!")
		return

	# Find which slot this item is in and unequip
	var slot: String = ""
	if _hero.belongings.weapon == _item:
		slot = "weapon"
	elif _hero.belongings.armor == _item:
		slot = "armor"
	elif _hero.belongings.artifact == _item:
		slot = "artifact"
	elif _hero.belongings.ring_left == _item:
		slot = "ring_left"
	elif _hero.belongings.ring_right == _item:
		slot = "ring_right"
	elif _hero.belongings.misc == _item:
		slot = "misc"

	if slot != "":
		var removed: Variant = _hero.belongings.unequip(slot)
		if removed:
			_hero.belongings.add_item(removed)
			if EventBus:
				EventBus.item_unequipped.emit(ConstantsData.get_prop(removed, "item_name", ""), slot)
	close_window()


func _action_use() -> void:
	if not _hero or not _item:
		close_window()
		return

	# Wands need targeting mode — select a cell to zap
	if _item is Wand:
		if ConstantsData.get_prop(_item, "charges", 0) <= 0:
			if MessageLog:
				MessageLog.add_warning("The %s has no charges left!" % ConstantsData.get_prop(_item, "item_name", "item"))
			close_window()
			return
		var wand_ref: Variant = _item
		var hero_ref: Hero = _hero
		var zap_callback: Callable = func(cell: int) -> void:
			if wand_ref and hero_ref and wand_ref.has_method("zap"):
				wand_ref.zap(hero_ref, cell)
		close_window()
		if EventBus and EventBus.has_signal("enter_targeting"):
			var max_range: int = ConstantsData.get_prop(wand_ref, "zap_range", 8) if ConstantsData.get_prop(wand_ref, "zap_range") else 8
			EventBus.enter_targeting.emit(wand_ref, max_range, zap_callback)
		return

	# Call the item's own execute() method, which handles consumption internally.
	# Potions call drink() + _consume(), Scrolls call read_scroll() + _consume(),
	# Food calls eat() + _consume_one(). Do NOT consume again here — that would
	# double-decrement quantity or double-remove from inventory.
	if _item.has_method("execute"):
		_item.execute(_hero)
	elif _item.has_method("use"):
		_item.use(_hero)

	close_window()


func _action_drop() -> void:
	if not _hero or not _item:
		close_window()
		return

	# Cannot drop cursed equipped items
	if _is_equipped and ConstantsData.get_prop(_item, "cursed", false) and ConstantsData.get_prop(_item, "cursed_known", false):
		if MessageLog:
			MessageLog.add_warning("You cannot remove the cursed %s!" % ConstantsData.get_prop(_item, "item_name", "item"))
		return

	# Unequip first if equipped
	if _is_equipped:
		var slot: String = ""
		if _hero.belongings.weapon == _item:
			slot = "weapon"
		elif _hero.belongings.armor == _item:
			slot = "armor"
		elif _hero.belongings.artifact == _item:
			slot = "artifact"
		elif _hero.belongings.misc == _item:
			slot = "misc"
		elif _hero.belongings.ring == _item:
			slot = "ring"
		if slot != "":
			_hero.belongings.unequip(slot)
		_hero.belongings.add_item(_item)
		if MessageLog:
			var item_name_str: String = ConstantsData.get_prop(_item, "item_name", "item")
			MessageLog.add("You unequip the %s." % item_name_str)
	close_window()

func _action_throw() -> void:
	var item_name_str: String = ConstantsData.get_prop(_item, "item_name", "item")
	if MessageLog:
		MessageLog.add("Select a target to throw the %s." % item_name_str)
	var max_range: int = 6
	var tier: Variant = ConstantsData.get_prop(_item, "tier", null)
	if tier is int:
		max_range = 4 + tier * 2
	if EventBus:
		EventBus.enter_targeting.emit(_item, max_range, _execute_throw_callback)
	close_window()

func _execute_throw_callback(target_cell: int) -> void:
	pass  # Handled by GameScene._execute_throw()

func _action_quickslot() -> void:
	if _hero and _hero.belongings.has_method("set_quickslot"):
		_hero.belongings.set_quickslot(0, _item)
		if MessageLog:
			var item_name_str: String = ConstantsData.get_prop(_item, "item_name", "item")
			MessageLog.add("Set %s to quickslot." % item_name_str)
	close_window()
