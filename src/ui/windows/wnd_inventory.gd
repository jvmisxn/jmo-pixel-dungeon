class_name WndInventory
extends WndBase
## Full inventory window showing backpack grid, equipment slots, gold, and filter tabs.

# --- Filter State ---
enum FilterTab {
	ALL,
	WEAPONS,
	ARMOR,
	POTIONS,
	SCROLLS,
	OTHER,
}

var _current_filter: FilterTab = FilterTab.ALL
var _item_grid: GridContainer = null
var _equip_slots: Dictionary = {}  # slot_name -> Button
var _gold_label: Label = null
var _filter_buttons: Array[Button] = []
var _hero: Hero = null


func _init() -> void:
	window_title = "Inventory"
	custom_minimum_size = Vector2(420, 480)


func _build_content() -> Control:
	_hero = GameManager.hero if GameManager else null

	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 6)

	# --- Equipment Row ---
	var equip_label: Label = Label.new()
	equip_label.text = "Equipment"
	main.add_child(equip_label)

	var equip_row: HBoxContainer = HBoxContainer.new()
	equip_row.add_theme_constant_override("separation", 4)
	main.add_child(equip_row)

	var slot_names: Array[String] = ["weapon", "armor", "artifact", "ring_left", "ring_right", "misc"]
	var slot_labels: Array[String] = ["Weapon", "Armor", "Artifact", "Ring L", "Ring R", "Misc"]
	for i: int in range(slot_names.size()):
		var slot_btn: Button = Button.new()
		slot_btn.custom_minimum_size = Vector2(56, 56)
		slot_btn.tooltip_text = slot_labels[i]
		slot_btn.text = _get_equip_slot_text(slot_names[i])
		slot_btn.add_theme_font_size_override("font_size", 10)
		slot_btn.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
		# SPD stone slot style
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.12, 0.1, 0.08)
		slot_style.border_color = Color(0.45, 0.38, 0.28)
		slot_style.set_border_width_all(1)
		slot_style.set_corner_radius_all(2)
		slot_btn.add_theme_stylebox_override("normal", slot_style)
		var slot_hover := StyleBoxFlat.new()
		slot_hover.bg_color = Color(0.18, 0.15, 0.12)
		slot_hover.border_color = Color(0.6, 0.5, 0.35)
		slot_hover.set_border_width_all(1)
		slot_hover.set_corner_radius_all(2)
		slot_btn.add_theme_stylebox_override("hover", slot_hover)
		slot_btn.pressed.connect(_on_equip_slot_pressed.bind(slot_names[i]))
		equip_row.add_child(slot_btn)
		_equip_slots[slot_names[i]] = slot_btn

	# --- Gold Display ---
	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_gold_label.add_theme_font_size_override("font_size", 13)
	_update_gold_display()
	main.add_child(_gold_label)

	# --- Filter Tabs ---
	var filter_row: HBoxContainer = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 2)
	main.add_child(filter_row)

	var filter_names: Array[String] = ["All", "Weapons", "Armor", "Potions", "Scrolls", "Other"]
	for i: int in range(filter_names.size()):
		var fb: Button = Button.new()
		fb.text = filter_names[i]
		fb.toggle_mode = true
		fb.button_pressed = (i == 0)
		fb.pressed.connect(_on_filter_pressed.bind(i))
		filter_row.add_child(fb)
		_filter_buttons.append(fb)

	# --- Sort Button ---
	var sort_btn: Button = Button.new()
	sort_btn.text = "Sort"
	sort_btn.pressed.connect(_on_sort_pressed)
	filter_row.add_child(sort_btn)

	# --- Item Grid (5 columns x 4 rows = 20 slots) ---
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 240)
	main.add_child(scroll)

	_item_grid = GridContainer.new()
	_item_grid.columns = 5
	_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_grid.add_theme_constant_override("h_separation", 4)
	_item_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_item_grid)

	_refresh_grid()
	return main


func _get_equip_slot_text(slot_name: String) -> String:
	if not _hero or not _hero.belongings:
		return "---"
	var item: Variant = null
	match slot_name:
		"weapon": item = _hero.belongings.weapon
		"armor": item = _hero.belongings.armor
		"artifact": item = _hero.belongings.artifact
		"ring_left": item = _hero.belongings.ring_left
		"ring_right": item = _hero.belongings.ring_right
		"misc": item = _hero.belongings.misc
	if item and item.get("item_name"):
		return item.item_name.substr(0, 6)
	return "---"


func _update_gold_display() -> void:
	if _gold_label:
		var gold: int = GameManager.gold if GameManager else 0
		_gold_label.text = "Gold: %d" % gold


func _refresh_grid() -> void:
	if not _item_grid:
		return
	# Clear existing
	for child: Node in _item_grid.get_children():
		child.queue_free()

	var items: Array = _get_filtered_items()

	# Fill grid up to 20 slots
	for i: int in range(Belongings.MAX_INVENTORY):
		var slot_btn: Button = Button.new()
		slot_btn.custom_minimum_size = Vector2(56, 56)
		if i < items.size():
			var item: Variant = items[i]
			slot_btn.text = _get_item_display_text(item)
			if item.get("icon_color"):
				slot_btn.modulate = item.icon_color
			slot_btn.pressed.connect(_on_item_pressed.bind(item))
			slot_btn.tooltip_text = ConstantsData.get_prop(item, "item_name", "")
		else:
			slot_btn.text = ""
			slot_btn.disabled = false  # Keep interactive for future drag targets
		_item_grid.add_child(slot_btn)


func _get_item_display_text(item: Variant) -> String:
	var text: String = ""
	if item.get("item_name"):
		text = item.item_name.substr(0, 5)
	if ConstantsData.get_prop(item, "stackable") and ConstantsData.get_prop(item, "quantity", 1) > 1:
		text += "\nx%d" % item.quantity
	if ConstantsData.get_prop(item, "level", 0) > 0:
		text += "\n+%d" % item.level
	return text


func _get_filtered_items() -> Array:
	if not _hero or not _hero.belongings:
		return []
	var all_items: Array = _hero.belongings.backpack
	if _current_filter == FilterTab.ALL:
		return all_items

	var filtered: Array[Item] = []
	for item: Item in all_items:
		var cat: int = ConstantsData.get_prop(item, "category", -1)
		var passes: bool = false
		match _current_filter:
			FilterTab.WEAPONS:
				passes = (cat == ConstantsData.ItemCategory.WEAPON)
			FilterTab.ARMOR:
				passes = (cat == ConstantsData.ItemCategory.ARMOR)
			FilterTab.POTIONS:
				passes = (cat == ConstantsData.ItemCategory.POTION)
			FilterTab.SCROLLS:
				passes = (cat == ConstantsData.ItemCategory.SCROLL)
			FilterTab.OTHER:
				passes = cat not in [
					ConstantsData.ItemCategory.WEAPON,
					ConstantsData.ItemCategory.ARMOR,
					ConstantsData.ItemCategory.POTION,
					ConstantsData.ItemCategory.SCROLL,
				]
		if passes:
			filtered.append(item)
	return filtered


func _on_filter_pressed(filter_idx: int) -> void:
	_current_filter = filter_idx as FilterTab
	# Update toggle states
	for i: int in range(_filter_buttons.size()):
		_filter_buttons[i].button_pressed = (i == filter_idx)
	_refresh_grid()


func _on_sort_pressed() -> void:
	if not _hero or not _hero.belongings:
		return
	_hero.belongings.backpack.sort_custom(func(a: Variant, b: Variant) -> bool:
		var cat_a: int = ConstantsData.get_prop(a, "category", 99)
		var cat_b: int = ConstantsData.get_prop(b, "category", 99)
		if cat_a != cat_b:
			return cat_a < cat_b
		var name_a: String = ConstantsData.get_prop(a, "item_name", "")
		var name_b: String = ConstantsData.get_prop(b, "item_name", "")
		return name_a < name_b
	)
	_refresh_grid()


func _on_item_pressed(item: Variant) -> void:
	# Signal up to parent (HUD) to open sub-window — avoids get_parent()
	var wnd_item: WndItem = WndItem.new()
	wnd_item.setup(item, _hero)
	wnd_item.window_closed.connect(_on_sub_window_closed)
	open_sub_window.emit(wnd_item)
