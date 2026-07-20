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

const COMPACT_VIEWPORT_WIDTH: float = 480.0
const DESKTOP_EQUIP_SLOT_SIZE: float = 56.0
const MOBILE_EQUIP_SLOT_SIZE: float = 44.0


func _init() -> void:
	window_title = "Inventory"
	custom_minimum_size = Vector2(420, 480)


func _build_content() -> Control:
	_hero = GameManager.get_local_hero() if GameManager and GameManager.has_method("get_local_hero") else (GameManager.hero if GameManager else null)

	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 6)

	# --- Equipment Row ---
	var equip_label: Label = Label.new()
	equip_label.text = "Equipment"
	main.add_child(equip_label)

	var equip_row: HFlowContainer = HFlowContainer.new()
	equip_row.add_theme_constant_override("separation", 4)
	equip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(equip_row)

	var slot_names: Array[String] = ["weapon", "spirit_bow", "armor", "artifact", "ring_left", "ring_right", "misc"]
	var slot_labels: Array[String] = ["Weapon", "Bow", "Armor", "Artifact", "Ring L", "Ring R", "Misc"]
	var equip_slot_size: float = _inventory_equip_slot_size()
	for i: int in range(slot_names.size()):
		var equip_slot: ItemSlot = ItemSlot.new()
		equip_slot.custom_minimum_size = Vector2(equip_slot_size, equip_slot_size)
		equip_slot.size = equip_slot.custom_minimum_size
		equip_slot.tooltip_text = slot_labels[i]
		# Set the equipped item on the slot
		var equipped_item: Variant = _get_equipped_item(slot_names[i])
		if equipped_item:
			equip_slot.item = equipped_item
		equip_slot.slot_clicked.connect(_on_equip_slot_item_clicked.bind(slot_names[i]))
		equip_row.add_child(equip_slot)
		_equip_slots[slot_names[i]] = equip_slot

	# --- Gold Display ---
	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_gold_label.add_theme_font_size_override("font_size", 13)
	_update_gold_display()
	main.add_child(_gold_label)

	# --- Filter Tabs ---
	var filter_row: HFlowContainer = HFlowContainer.new()
	filter_row.add_theme_constant_override("separation", 2)
	filter_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(filter_row)

	var filter_names: Array[String] = ["All", "Weapons", "Armor", "Potions", "Scrolls", "Other"]
	for i: int in range(filter_names.size()):
		var fb: Button = Button.new()
		fb.text = filter_names[i]
		fb.toggle_mode = true
		fb.button_pressed = (i == 0)
		fb.custom_minimum_size = Vector2(72, 32)
		fb.pressed.connect(_on_filter_pressed.bind(i))
		filter_row.add_child(fb)
		_filter_buttons.append(fb)

	# --- Sort Button ---
	var sort_btn: Button = Button.new()
	sort_btn.text = "Sort"
	sort_btn.custom_minimum_size = Vector2(72, 32)
	sort_btn.pressed.connect(_on_sort_pressed)
	filter_row.add_child(sort_btn)

	# --- Item Grid (5 columns x 4 rows = 20 slots) ---
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 240)
	main.add_child(scroll)

	_item_grid = GridContainer.new()
	_item_grid.columns = _inventory_grid_columns()
	_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_grid.add_theme_constant_override("h_separation", 4)
	_item_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_item_grid)

	_refresh_grid()

	return main


func _get_equipped_item(slot_name: String) -> Variant:
	if not _hero or not _hero.belongings:
		return null
	match slot_name:
		"weapon": return _hero.belongings.weapon
		"spirit_bow": return _hero.belongings.spirit_bow
		"armor": return _hero.belongings.armor
		"artifact": return _hero.belongings.artifact
		"ring_left": return _hero.belongings.ring_left
		"ring_right": return _hero.belongings.ring_right
		"misc": return _hero.belongings.misc
	return null


## Called when an equipment slot's ItemSlot is clicked.
func _on_equip_slot_item_clicked(_clicked_item: RefCounted, slot_name: String) -> void:
	_on_equip_slot_pressed(slot_name)


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

	# Fill grid up to 20 slots using ItemSlot for proper item icons
	for i: int in range(Belongings.MAX_INVENTORY):
		var slot: ItemSlot = ItemSlot.new()
		if i < items.size():
			var itm: Variant = items[i]
			slot.item = itm
			slot.slot_clicked.connect(_on_item_pressed)
			slot.tooltip_text = ConstantsData.get_prop(itm, "item_name", "")
		_item_grid.add_child(slot)


func _inventory_equip_slot_size() -> float:
	return _inventory_equip_slot_size_for_width(_viewport_width())


func _inventory_grid_columns() -> int:
	return _inventory_grid_columns_for_width(_viewport_width())


func _viewport_width() -> float:
	var vp: Viewport = get_viewport()
	if vp == null:
		return 1280.0
	return vp.get_visible_rect().size.x


func _inventory_equip_slot_size_for_width(width: float) -> float:
	return MOBILE_EQUIP_SLOT_SIZE if width <= COMPACT_VIEWPORT_WIDTH else DESKTOP_EQUIP_SLOT_SIZE


func _inventory_grid_columns_for_width(width: float) -> int:
	return 4 if width <= COMPACT_VIEWPORT_WIDTH else 5


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


func _on_equip_slot_pressed(slot_name: String) -> void:
	if not _hero or not _hero.belongings:
		return
	var item: Variant = null
	match slot_name:
		"weapon": item = _hero.belongings.weapon
		"spirit_bow": item = _hero.belongings.spirit_bow
		"armor": item = _hero.belongings.armor
		"artifact": item = _hero.belongings.artifact
		"ring_left": item = _hero.belongings.ring_left
		"ring_right": item = _hero.belongings.ring_right
		"misc": item = _hero.belongings.misc
	if item == null:
		return
	# Open item detail sub-window for the equipped item
	var wnd_item: WndItem = WndItem.new()
	wnd_item.setup(item, _hero, true)
	wnd_item.window_closed.connect(_on_sub_window_closed)
	open_sub_window.emit(wnd_item)


func _on_item_pressed(item: Variant) -> void:
	# Signal up to parent (HUD) to open sub-window — avoids get_parent()
	var wnd_item: WndItem = WndItem.new()
	wnd_item.setup(item, _hero)
	wnd_item.window_closed.connect(_on_sub_window_closed)
	open_sub_window.emit(wnd_item)


func _on_sub_window_closed() -> void:
	# Refresh inventory display after a sub-window (item detail) closes
	_refresh_grid()
	_update_gold_display()
	# Update equipment slot icons in case something was equipped/unequipped
	for slot_name: String in _equip_slots:
		var slot: ItemSlot = _equip_slots[slot_name] as ItemSlot
		if slot:
			slot.item = _get_equipped_item(slot_name)
