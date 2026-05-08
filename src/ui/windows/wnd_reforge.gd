class_name WndReforge
extends WndBase
## Blacksmith reforge window. The player selects two equipment items from their
## inventory — upgrades from item 2 are transferred to item 1, and item 2 is
## consumed. Only weapons and armor are eligible for reforging.

var _slot_1: ItemSlot = null
var _slot_2: ItemSlot = null
var _item_1: Variant = null
var _item_2: Variant = null
var _inventory_grid: GridContainer = null
var _reforge_button: Button = null
var _info_label: Label = null
var _hero: Variant = null
var _scroll_container: ScrollContainer = null

## Which target slot is being filled next (1 or 2). 0 = auto-pick first empty.
var _active_target: int = 0


func _init() -> void:
	window_title = "Blacksmith's Reforge"
	custom_minimum_size = Vector2(400, 440)


func _build_content() -> Control:
	_hero = GameManager.hero if GameManager else null

	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 6)

	# --- Description ---
	var desc: Label = Label.new()
	desc.text = "Place two items below. Upgrades from the right item\nwill transfer to the left item."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(desc)

	# --- Target Slots Row ---
	var target_row: HBoxContainer = HBoxContainer.new()
	target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	target_row.add_theme_constant_override("separation", 8)
	main.add_child(target_row)

	# Slot 1 (receives upgrades)
	var slot1_container: VBoxContainer = VBoxContainer.new()
	slot1_container.alignment = BoxContainer.ALIGNMENT_CENTER
	target_row.add_child(slot1_container)

	var label_1: Label = Label.new()
	label_1.text = "Keep"
	label_1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_1.add_theme_font_size_override("font_size", 11)
	slot1_container.add_child(label_1)

	_slot_1 = ItemSlot.new()
	_slot_1.slot_clicked.connect(_on_target_slot_clicked.bind(1))
	slot1_container.add_child(_slot_1)

	# Plus label
	var plus_label: Label = Label.new()
	plus_label.text = "+"
	plus_label.add_theme_font_size_override("font_size", 24)
	target_row.add_child(plus_label)

	# Slot 2 (consumed)
	var slot2_container: VBoxContainer = VBoxContainer.new()
	slot2_container.alignment = BoxContainer.ALIGNMENT_CENTER
	target_row.add_child(slot2_container)

	var label_2: Label = Label.new()
	label_2.text = "Consume"
	label_2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_2.add_theme_font_size_override("font_size", 11)
	slot2_container.add_child(label_2)

	_slot_2 = ItemSlot.new()
	_slot_2.slot_clicked.connect(_on_target_slot_clicked.bind(2))
	slot2_container.add_child(_slot_2)

	# --- Info Label ---
	_info_label = Label.new()
	_info_label.text = "Select weapons or armor from your inventory."
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	main.add_child(_info_label)

	# --- Separator ---
	var sep: HSeparator = HSeparator.new()
	main.add_child(sep)

	# --- Inventory label ---
	var inv_label: Label = Label.new()
	inv_label.text = "Eligible Items"
	inv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(inv_label)

	# --- Scrollable Inventory Grid ---
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.custom_minimum_size = Vector2(0, 180)
	main.add_child(_scroll_container)

	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = 7
	_inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_grid.add_theme_constant_override("h_separation", 4)
	_inventory_grid.add_theme_constant_override("v_separation", 4)
	_scroll_container.add_child(_inventory_grid)

	_refresh_inventory_grid()

	# --- Separator ---
	var sep2: HSeparator = HSeparator.new()
	main.add_child(sep2)

	# --- Reforge Button ---
	var btn_row: CenterContainer = CenterContainer.new()
	main.add_child(btn_row)

	_reforge_button = Button.new()
	_reforge_button.text = "Reforge"
	_reforge_button.custom_minimum_size = Vector2(120, 36)
	_reforge_button.disabled = true
	_reforge_button.pressed.connect(_on_reforge_pressed)
	btn_row.add_child(_reforge_button)

	return main


# ---------------------------------------------------------------------------
# Inventory Grid
# ---------------------------------------------------------------------------

func _refresh_inventory_grid() -> void:
	if not _inventory_grid:
		return
	for child: Node in _inventory_grid.get_children():
		child.queue_free()

	var eligible: Array = _get_eligible_items()
	for item: Variant in eligible:
		var slot: ItemSlot = ItemSlot.new()
		slot.item = item
		slot.slot_clicked.connect(_on_inventory_item_clicked.bind(item))
		_inventory_grid.add_child(slot)

	if eligible.size() == 0:
		var empty_label: Label = Label.new()
		empty_label.text = "No eligible items."
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_inventory_grid.add_child(empty_label)


func _get_eligible_items() -> Array:
	if not _hero or not _hero.belongings:
		return []
	var result: Array = []
	for item: Variant in _hero.belongings.backpack:
		if item == null:
			continue
		var cat: int = ConstantsData.get_prop(item, "category", -1)
		if cat == ConstantsData.ItemCategory.WEAPON or cat == ConstantsData.ItemCategory.ARMOR:
			# Skip items already placed in target slots
			if item == _item_1 or item == _item_2:
				continue
			result.append(item)
	# Also check equipped weapon/armor
	var equipped_weapon: Variant = _hero.belongings.weapon
	if equipped_weapon != null and equipped_weapon != _item_1 and equipped_weapon != _item_2:
		result.append(equipped_weapon)
	var equipped_armor: Variant = _hero.belongings.armor
	if equipped_armor != null and equipped_armor != _item_1 and equipped_armor != _item_2:
		result.append(equipped_armor)
	return result


# ---------------------------------------------------------------------------
# Slot Interaction
# ---------------------------------------------------------------------------

func _on_inventory_item_clicked(clicked_ref: RefCounted, item: Variant) -> void:
	# Determine which slot to fill
	var target: int = _active_target
	if target == 0:
		# Auto-fill first empty slot
		if _item_1 == null:
			target = 1
		elif _item_2 == null:
			target = 2
		else:
			# Both full — replace slot 1
			target = 1

	if target == 1:
		_item_1 = item
		_slot_1.item = item
		_slot_1.selected = true
	else:
		_item_2 = item
		_slot_2.item = item
		_slot_2.selected = true

	_active_target = 0
	_update_state()


func _on_target_slot_clicked(_item_ref: RefCounted, slot_index: int) -> void:
	if slot_index == 1:
		if _item_1 != null:
			# Return item to grid
			_item_1 = null
			_slot_1.item = null
			_slot_1.selected = false
		else:
			# Set this as the active target
			_active_target = 1
			_slot_1.selected = true
			_slot_2.selected = false
	elif slot_index == 2:
		if _item_2 != null:
			# Return item to grid
			_item_2 = null
			_slot_2.item = null
			_slot_2.selected = false
		else:
			_active_target = 2
			_slot_2.selected = true
			_slot_1.selected = false

	_update_state()


func _update_state() -> void:
	_refresh_inventory_grid()

	var both_filled: bool = (_item_1 != null and _item_2 != null)
	_reforge_button.disabled = not both_filled

	if both_filled:
		var lvl_1: int = ConstantsData.get_prop(_item_1, "level", 0)
		var lvl_2: int = ConstantsData.get_prop(_item_2, "level", 0)
		# Original reforge: item_a gains +1 plus item_b's upgrade level
		var result_level: int = lvl_1 + 1 + maxi(0, lvl_2)
		var name_1: String = _item_1.get_display_name() if _item_1.has_method("get_display_name") else ConstantsData.get_prop(_item_1, "item_name", "item")
		var name_2: String = _item_2.get_display_name() if _item_2.has_method("get_display_name") else ConstantsData.get_prop(_item_2, "item_name", "item")
		_info_label.text = "%s (+%d) will absorb %s (+%d) -> +%d" % [
			name_1, lvl_1, name_2, lvl_2, result_level
		]
	elif _item_1 != null:
		_info_label.text = "Now select the item to consume."
	elif _item_2 != null:
		_info_label.text = "Now select the item to keep."
	else:
		_info_label.text = "Select weapons or armor from your inventory."


# ---------------------------------------------------------------------------
# Reforge Action
# ---------------------------------------------------------------------------

func _on_reforge_pressed() -> void:
	if _item_1 == null or _item_2 == null:
		return

	var lvl_transfer: int = ConstantsData.get_prop(_item_2, "level", 0)
	var old_name_1: String = ConstantsData.get_prop(_item_1, "item_name", "item")
	if _item_1.has_method("get_display_name"):
		old_name_1 = _item_1.get_display_name()
	var old_name_2: String = ConstantsData.get_prop(_item_2, "item_name", "item")
	if _item_2.has_method("get_display_name"):
		old_name_2 = _item_2.get_display_name()

	# Transfer upgrades from item 2 to item 1: +1 bonus plus item_2's level
	var total_upgrades: int = 1 + maxi(0, lvl_transfer)
	if _item_1.has_method("upgrade"):
		for i: int in range(total_upgrades):
			_item_1.upgrade()
	else:
		_item_1.level = ConstantsData.get_prop(_item_1, "level", 0) + total_upgrades

	# Remove curse from the kept item
	if "cursed" in _item_1:
		_item_1.cursed = false
	if "cursed_known" in _item_1:
		_item_1.cursed_known = true

	# Identify the kept item
	if _item_1.has_method("identify"):
		_item_1.identify()

	# Remove item 2 from inventory
	if _hero and _hero.belongings:
		# Check if item_2 is equipped
		if _hero.belongings.weapon == _item_2:
			_hero.belongings.unequip("weapon")
		elif _hero.belongings.armor == _item_2:
			_hero.belongings.unequip("armor")
		else:
			_hero.belongings.remove_item(_item_2)

	if MessageLog:
		MessageLog.add_positive("The blacksmith reforges your %s with the %s!" % [old_name_1, old_name_2])

	if EventBus:
		EventBus.quest_updated.emit("blacksmith", "reforge_complete")

	if GameManager:
		GameManager.record_stat("items_reforged")

	close_window()
