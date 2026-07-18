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

	# --- Icon ---
	var icon_container: CenterContainer = CenterContainer.new()
	var icon_slot: ItemSlot = ItemSlot.new()
	icon_slot.item = _item
	icon_slot.custom_minimum_size = Vector2(48, 48)
	icon_slot.size = Vector2(48, 48)
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_container.add_child(icon_slot)
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
	if _item is SpiritBow:
		_add_button(container, "Shoot", _action_shoot)
	match cat:
		ConstantsData.ItemCategory.POTION:
			_add_button(container, "Drink", _action_use)
		ConstantsData.ItemCategory.SCROLL:
			_add_button(container, "Read", _action_use)
		ConstantsData.ItemCategory.FOOD:
			_add_button(container, "Eat", _action_use)
		ConstantsData.ItemCategory.SEED:
			_add_button(container, "Plant", _action_use)
			if _can_feed_seed_to_sandals():
				_add_button(container, "Feed", _action_feed_to_sandals)
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

func _can_feed_seed_to_sandals() -> bool:
	if _hero == null or _hero.belongings == null or _item == null:
		return false
	var artifact: Variant = _hero.belongings.get_equipped_artifact()
	if artifact == null:
		return false
	return str(ConstantsData.get_prop(artifact, "item_id", "")) == "sandals_of_nature" and artifact.has_method("feed_seed")

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _action_equip() -> void:
	if not _hero or not _hero.belongings or not _item:
		close_window()
		return
	if EventBus and EventBus.has_signal("request_hero_action"):
		EventBus.request_hero_action.emit({"type": "equip_item", "item": _item})
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
	elif _hero.belongings.spirit_bow == _item:
		slot = "spirit_bow"
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

	if slot != "" and EventBus and EventBus.has_signal("request_hero_action"):
		EventBus.request_hero_action.emit({"type": "unequip_item", "slot": slot})
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
		var zap_callback: Callable = func(cell: int) -> void:
			if EventBus and EventBus.has_signal("request_hero_action"):
				EventBus.request_hero_action.emit({"type": "zap_wand", "item": wand_ref, "target_pos": cell})
		close_window()
		if EventBus and EventBus.has_signal("enter_targeting"):
			var max_range: int = ConstantsData.get_prop(wand_ref, "zap_range", 8) if ConstantsData.get_prop(wand_ref, "zap_range") else 8
			EventBus.enter_targeting.emit(wand_ref, max_range, zap_callback)
		return

	if EventBus and EventBus.has_signal("request_hero_action"):
		EventBus.request_hero_action.emit({"type": "use_item", "item": _item})

	close_window()

func _action_feed_to_sandals() -> void:
	if not _can_feed_seed_to_sandals():
		close_window()
		return
	if EventBus and EventBus.has_signal("request_hero_action"):
		EventBus.request_hero_action.emit({"type": "feed_seed_to_sandals", "item": _item})
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
	var equip_slot: String = ""
	if _is_equipped:
		var slot: String = ""
		if _hero.belongings.weapon == _item:
			slot = "weapon"
		elif _hero.belongings.spirit_bow == _item:
			slot = "spirit_bow"
		elif _hero.belongings.armor == _item:
			slot = "armor"
		elif _hero.belongings.artifact == _item:
			slot = "artifact"
		elif _hero.belongings.misc == _item:
			slot = "misc"
		elif _hero.belongings.ring_left == _item:
			slot = "ring_left"
		elif _hero.belongings.ring_right == _item:
			slot = "ring_right"
		equip_slot = slot
	if EventBus and EventBus.has_signal("request_hero_action"):
		EventBus.request_hero_action.emit({"type": "drop_item", "item": _item, "equip_slot": equip_slot})
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
	if EventBus and EventBus.has_signal("request_hero_action"):
		EventBus.request_hero_action.emit({"type": "throw_item", "item": _item, "target_pos": target_cell})

func _action_shoot() -> void:
	var item_name_str: String = ConstantsData.get_prop(_item, "item_name", "item")
	if MessageLog:
		MessageLog.add("Select a target for the %s." % item_name_str)
	if EventBus:
		EventBus.enter_targeting.emit(_item, 8, _execute_throw_callback)
	close_window()

func _action_quickslot() -> void:
	if _hero == null or _hero.belongings == null or _item == null:
		close_window()
		return
	var wnd: WndQuickslotSelect = WndQuickslotSelect.new()
	wnd.setup(_hero, _item)
	open_sub_window.emit(wnd)
	close_window()
