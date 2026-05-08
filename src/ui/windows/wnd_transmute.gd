class_name WndTransmute
extends WndBase
## Scroll of Transmutation item selection window. Lets the player pick an item
## from their inventory to transmute into another of the same type/tier.

# --- Transmutation Categories ---
enum TransmuteFilter {
	ALL,
	WEAPONS,
	ARMOR,
	POTIONS,
	SCROLLS,
	RINGS,
	WANDS,
}

var _scroll_ref: Item = null  # Reference to the scroll being used
var _hero: Char = null
var _eligible_items: Array[Item] = []
var _item_slots: Array[ItemSlot] = []
var _selected_item: Item = null
var _transmute_button: Button = null
var _result_label: RichTextLabel = null
var _info_label: RichTextLabel = null
var _item_grid: GridContainer = null
var _filter_buttons: Array[Button] = []
var _current_filter: TransmuteFilter = TransmuteFilter.ALL
var _scroll_container: ScrollContainer = null


func _init() -> void:
	window_title = "Transmutation"
	custom_minimum_size = Vector2(420, 460)


## Call before adding to tree. Pass the scroll instance so it can be consumed.
func setup(scroll: Variant, hero: Variant = null) -> void:
	_scroll_ref = scroll
	_hero = hero


func _build_content() -> Control:
	if _hero == null and GameManager:
		_hero = GameManager.hero

	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 6)

	# --- Description ---
	var desc: Label = Label.new()
	desc.text = "Select an item to transmute into another of its kind."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(desc)

	# --- Filter Tabs ---
	var filter_row: HBoxContainer = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 2)
	main.add_child(filter_row)

	var filter_names: Array[String] = ["All", "Weapons", "Armor", "Potions", "Scrolls", "Rings", "Wands"]
	for i: int in range(filter_names.size()):
		var fb: Button = Button.new()
		fb.text = filter_names[i]
		fb.toggle_mode = true
		fb.button_pressed = (i == 0)
		fb.pressed.connect(_on_filter_pressed.bind(i))
		filter_row.add_child(fb)
		_filter_buttons.append(fb)

	# --- Separator ---
	var sep1: HSeparator = HSeparator.new()
	main.add_child(sep1)

	# --- Scrollable Item Grid ---
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.custom_minimum_size = Vector2(0, 160)
	main.add_child(_scroll_container)

	_item_grid = GridContainer.new()
	_item_grid.columns = 8
	_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_grid.add_theme_constant_override("h_separation", 4)
	_item_grid.add_theme_constant_override("v_separation", 4)
	_scroll_container.add_child(_item_grid)

	# --- Separator ---
	var sep2: HSeparator = HSeparator.new()
	main.add_child(sep2)

	# --- Selected Item Info / Preview ---
	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = true
	_info_label.custom_minimum_size = Vector2(0, 40)
	_info_label.text = "[i]Click an item to select it for transmutation.[/i]"
	main.add_child(_info_label)

	# --- Result Preview ---
	_result_label = RichTextLabel.new()
	_result_label.bbcode_enabled = true
	_result_label.fit_content = true
	_result_label.custom_minimum_size = Vector2(0, 24)
	_result_label.text = ""
	main.add_child(_result_label)

	# --- Transmute Button ---
	var btn_row: CenterContainer = CenterContainer.new()
	main.add_child(btn_row)

	_transmute_button = Button.new()
	_transmute_button.text = "Transmute"
	_transmute_button.custom_minimum_size = Vector2(140, 36)
	_transmute_button.disabled = true
	_transmute_button.pressed.connect(_on_transmute_pressed)
	btn_row.add_child(_transmute_button)

	_refresh_grid()

	return main


# ---------------------------------------------------------------------------
# Filtering
# ---------------------------------------------------------------------------

func _on_filter_pressed(filter_idx: int) -> void:
	_current_filter = filter_idx as TransmuteFilter
	for i: int in range(_filter_buttons.size()):
		_filter_buttons[i].button_pressed = (i == filter_idx)

	# Deselect current selection if it no longer matches filter
	if _selected_item != null:
		var cat: int = ConstantsData.get_prop(_selected_item, "category", -1)
		if not _category_matches_filter(cat):
			_deselect()

	_refresh_grid()


func _category_matches_filter(cat: int) -> bool:
	match _current_filter:
		TransmuteFilter.ALL:
			return true
		TransmuteFilter.WEAPONS:
			return cat == ConstantsData.ItemCategory.WEAPON
		TransmuteFilter.ARMOR:
			return cat == ConstantsData.ItemCategory.ARMOR
		TransmuteFilter.POTIONS:
			return cat == ConstantsData.ItemCategory.POTION
		TransmuteFilter.SCROLLS:
			return cat == ConstantsData.ItemCategory.SCROLL
		TransmuteFilter.RINGS:
			return cat == ConstantsData.ItemCategory.RING
		TransmuteFilter.WANDS:
			return cat == ConstantsData.ItemCategory.WAND
	return false


# ---------------------------------------------------------------------------
# Grid
# ---------------------------------------------------------------------------

func _refresh_grid() -> void:
	if not _item_grid:
		return
	for child: Node in _item_grid.get_children():
		child.queue_free()
	_item_slots.clear()

	_eligible_items = _get_eligible_items()

	for item: Variant in _eligible_items:
		var slot: ItemSlot = ItemSlot.new()
		slot.item = item
		slot.selected = (item == _selected_item)
		slot.slot_clicked.connect(_on_item_clicked.bind(item))
		_item_grid.add_child(slot)
		_item_slots.append(slot)

	if _eligible_items.size() == 0:
		var empty_label: Label = Label.new()
		empty_label.text = "No eligible items."
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_item_grid.add_child(empty_label)


func _get_eligible_items() -> Array:
	if not _hero or not _hero.belongings:
		return []

	var result: Array = []
	var transmutable_cats: Array[int] = [
		ConstantsData.ItemCategory.WEAPON,
		ConstantsData.ItemCategory.ARMOR,
		ConstantsData.ItemCategory.POTION,
		ConstantsData.ItemCategory.SCROLL,
		ConstantsData.ItemCategory.RING,
		ConstantsData.ItemCategory.WAND,
		ConstantsData.ItemCategory.ARTIFACT,
	]

	# Backpack items
	for item: Variant in _hero.belongings.backpack:
		if item == null:
			continue
		var cat: int = ConstantsData.get_prop(item, "category", -1)
		if cat not in transmutable_cats:
			continue
		# Skip the scroll being used
		if item == _scroll_ref:
			continue
		# Skip unique items
		if ConstantsData.get_prop(item, "unique", false):
			continue
		# Apply current filter
		if not _category_matches_filter(cat):
			continue
		result.append(item)

	# Equipped items
	var equipped_slots: Array = [
		_hero.belongings.get("weapon"),
		_hero.belongings.get("armor"),
		_hero.belongings.get("artifact"),
		_hero.belongings.get("ring_left"),
		_hero.belongings.get("ring_right"),
		_hero.belongings.get("misc"),
	]
	for eq: Variant in equipped_slots:
		if eq == null or eq == _scroll_ref:
			continue
		var cat: int = ConstantsData.get_prop(eq, "category", -1)
		if cat not in transmutable_cats:
			continue
		if ConstantsData.get_prop(eq, "unique", false):
			continue
		if not _category_matches_filter(cat):
			continue
		# Avoid duplicates if item is somehow in both lists
		if eq not in result:
			result.append(eq)

	return result


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

func _on_item_clicked(_item_ref: RefCounted, item: Variant) -> void:
	# Deselect all slots
	for slot: ItemSlot in _item_slots:
		slot.selected = false

	_selected_item = item
	_transmute_button.disabled = false

	# Highlight selected slot
	for slot: ItemSlot in _item_slots:
		if slot.item == item:
			slot.selected = true
			break

	# Update info
	var item_name: String = ConstantsData.get_prop(item, "item_name", "Unknown")
	if item.has_method("get_display_name"):
		item_name = item.get_display_name()
	var item_desc: String = ConstantsData.get_prop(item, "description", "")
	_info_label.text = "[b]%s[/b]\n%s" % [item_name, item_desc]
	_result_label.text = "[color=#cc8033]%s[/color]  ->  [color=#cc8033]?[/color]" % item_name


func _deselect() -> void:
	_selected_item = null
	_transmute_button.disabled = true
	for slot: ItemSlot in _item_slots:
		slot.selected = false
	_info_label.text = "[i]Click an item to select it for transmutation.[/i]"
	_result_label.text = ""


# ---------------------------------------------------------------------------
# Transmutation
# ---------------------------------------------------------------------------

func _on_transmute_pressed() -> void:
	if _selected_item == null:
		return

	var original: Variant = _selected_item
	var original_name: String = ConstantsData.get_prop(original, "item_name", "item")
	if original.has_method("get_display_name"):
		original_name = original.get_display_name()
	var original_level: int = ConstantsData.get_prop(original, "level", 0)
	var cat: int = ConstantsData.get_prop(original, "category", -1)

	# Perform the transmutation — create a new item of the same category/tier
	var result: Variant = _transmute_item(original)

	if result == null:
		if MessageLog:
			MessageLog.add_warning("The transmutation fizzles... nothing happens.")
		close_window()
		return

	# Transfer upgrade level to the new item
	if result.get("level") != null:
		result.level = original_level
	# Identify the result
	if result.has_method("identify"):
		result.identify()

	# Replace the original in inventory
	if _hero and _hero.belongings:
		# Check if the original was equipped
		var was_equipped_slot: String = ""
		if _hero.belongings.weapon == original:
			was_equipped_slot = "weapon"
		elif _hero.belongings.armor == original:
			was_equipped_slot = "armor"
		elif _hero.belongings.artifact == original:
			was_equipped_slot = "artifact"
		elif _hero.belongings.ring_left == original:
			was_equipped_slot = "ring_left"
		elif _hero.belongings.ring_right == original:
			was_equipped_slot = "ring_right"
		elif _hero.belongings.misc == original:
			was_equipped_slot = "misc"

		if was_equipped_slot != "":
			_hero.belongings.unequip(was_equipped_slot)
			_hero.belongings.add_item(result)
		else:
			_hero.belongings.remove_item(original)
			_hero.belongings.add_item(result)

	# Consume the scroll
	if _scroll_ref:
		if _scroll_ref.has_method("_consume"):
			_scroll_ref._consume(_hero)
		elif _hero and _hero.belongings:
			# Manual consumption fallback
			var qty: int = ConstantsData.get_prop(_scroll_ref, "quantity", 1)
			if qty <= 1:
				_hero.belongings.remove_item(_scroll_ref)
			else:
				_scroll_ref.quantity -= 1

	var result_name: String = ConstantsData.get_prop(result, "item_name", "item")
	if result.has_method("get_display_name"):
		result_name = result.get_display_name()

	if MessageLog:
		MessageLog.add_positive("Your %s shimmers and transforms into a %s!" % [original_name, result_name])

	if EventBus:
		EventBus.item_used.emit("transmutation")

	if GameManager:
		GameManager.record_stat("items_transmuted")

	close_window()


## Perform the actual transmutation, returning a new item of the same category/tier
## but a different type. Returns null if transmutation is impossible.
func _transmute_item(item: Variant) -> Variant:
	var cat: int = ConstantsData.get_prop(item, "category", -1)

	match cat:
		ConstantsData.ItemCategory.WEAPON:
			return _transmute_weapon(item)
		ConstantsData.ItemCategory.ARMOR:
			return _transmute_armor(item)
		ConstantsData.ItemCategory.POTION:
			return _transmute_potion(item)
		ConstantsData.ItemCategory.SCROLL:
			return _transmute_scroll(item)
		ConstantsData.ItemCategory.RING:
			return _transmute_ring(item)
		ConstantsData.ItemCategory.WAND:
			return _transmute_wand(item)
		ConstantsData.ItemCategory.ARTIFACT:
			return _transmute_artifact(item)
	return null


func _transmute_weapon(item: Variant) -> Variant:
	var item_tier: int = ConstantsData.get_prop(item, "tier", 1)
	var current_id: String = ConstantsData.get_prop(item, "item_id", "")

	# Get all weapon IDs for the same tier
	var tier_ids: Array[String] = _get_weapon_ids_for_tier(item_tier)
	# Remove current weapon
	tier_ids.erase(current_id)

	if tier_ids.size() == 0:
		return null

	var new_id: String = tier_ids[randi() % tier_ids.size()]
	return MeleeWeapon.create(new_id)


func _transmute_armor(item: Variant) -> Variant:
	var item_tier: int = ConstantsData.get_prop(item, "tier", 1)
	var current_id: String = ConstantsData.get_prop(item, "item_id", "")

	# Armors map 1:1 to tiers, so we pick a random different tier's armor
	var all_ids: Array[String] = Armor.all_armor_ids()
	all_ids.erase(current_id)

	if all_ids.size() == 0:
		return null

	# Try to stay same tier — but since there's only one armor per tier, pick random
	var new_id: String = all_ids[randi() % all_ids.size()]
	return Armor.create(new_id)


func _transmute_potion(item: Variant) -> Variant:
	var current_id: String = ConstantsData.get_prop(item, "item_id", "")
	var all_ids: Array[String] = Potion.all_ids()
	all_ids.erase(current_id)

	if all_ids.size() == 0:
		return null

	var new_id: String = all_ids[randi() % all_ids.size()]
	return Potion.create(new_id)


func _transmute_scroll(item: Variant) -> Variant:
	var current_id: String = ConstantsData.get_prop(item, "item_id", "")
	var all_ids: Array[String] = Scroll.all_ids()
	all_ids.erase(current_id)
	# Don't transmute into another transmutation scroll
	all_ids.erase("transmutation")

	if all_ids.size() == 0:
		return null

	var new_id: String = all_ids[randi() % all_ids.size()]
	return Scroll.create(new_id)


func _transmute_ring(item: Variant) -> Variant:
	var current_id: String = ConstantsData.get_prop(item, "item_id", "")
	var all_ring_ids: Array[String] = [
		"ring_of_accuracy", "ring_of_evasion", "ring_of_elements",
		"ring_of_force", "ring_of_furor", "ring_of_haste",
		"ring_of_energy", "ring_of_might", "ring_of_sharpshooting",
		"ring_of_tenacity", "ring_of_wealth",
	]
	all_ring_ids.erase(current_id)

	if all_ring_ids.size() == 0:
		return null

	var new_id: String = all_ring_ids[randi() % all_ring_ids.size()]
	return Ring.create(new_id)


func _transmute_wand(item: Variant) -> Variant:
	var current_id: String = ConstantsData.get_prop(item, "item_id", "")
	var all_wand_ids: Array[String] = [
		"wand_of_magic_missile", "wand_of_fire_bolt", "wand_of_frost",
		"wand_of_lightning", "wand_of_disintegration", "wand_of_corrosion",
		"wand_of_living_earth", "wand_of_blast_wave", "wand_of_prismatic_light",
		"wand_of_warding", "wand_of_transfusion", "wand_of_corruption",
		"wand_of_regrowth",
	]
	all_wand_ids.erase(current_id)

	if all_wand_ids.size() == 0:
		return null

	var new_id: String = all_wand_ids[randi() % all_wand_ids.size()]
	return Wand.create(new_id)


func _transmute_artifact(item: Variant) -> Variant:
	var current_id: String = ConstantsData.get_prop(item, "item_id", "")
	var all_ids: Array[String] = Artifact.all_ids()
	all_ids.erase(current_id)

	if all_ids.size() == 0:
		return null

	var new_id: String = all_ids[randi() % all_ids.size()]
	return Artifact.create(new_id)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Return melee weapon IDs for a given tier (1-5).
func _get_weapon_ids_for_tier(weapon_tier: int) -> Array[String]:
	# MeleeWeapon.ALL_IDS is grouped in 5 per tier
	var ids_per_tier: int = 5
	var start: int = (weapon_tier - 1) * ids_per_tier
	var end_idx: int = mini(start + ids_per_tier, MeleeWeapon.ALL_IDS.size())
	var result: Array[String] = []
	for i: int in range(start, end_idx):
		result.append(MeleeWeapon.ALL_IDS[i])
	return result
