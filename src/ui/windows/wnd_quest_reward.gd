class_name WndQuestReward
extends WndBase
## Quest reward selection window. Shows 2-3 item choices and lets the player
## pick one. Used by NPCs (Ghost, Wandmaker, Imp) when rewarding completed quests.

signal reward_chosen(chosen_item: Variant)

var _quest_name: String = ""
var _quest_description: String = ""
var _reward_items: Array = []
var _selected_index: int = -1
var _item_slots: Array[ItemSlot] = []
var _select_button: Button = null
var _info_label: RichTextLabel = null
var _hero: Variant = null


func _init() -> void:
	custom_minimum_size = Vector2(380, 320)


## Call before adding to tree to configure the window.
func setup(quest_name: String, description: String, rewards: Array, hero: Variant = null) -> void:
	_quest_name = quest_name
	_quest_description = description
	_reward_items = rewards
	_hero = hero


func _build_content() -> Control:
	window_title = _quest_name
	if _title_label:
		_title_label.text = _quest_name

	if _hero == null and GameManager:
		_hero = GameManager.hero

	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)

	# --- Description ---
	var desc_label: RichTextLabel = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.custom_minimum_size = Vector2(0, 36)
	desc_label.text = _quest_description
	main.add_child(desc_label)

	# --- Separator ---
	var sep1: HSeparator = HSeparator.new()
	main.add_child(sep1)

	# --- Reward label ---
	var reward_label: Label = Label.new()
	reward_label.text = "Choose your reward:"
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(reward_label)

	# --- Item Slots Row ---
	var slot_row: HBoxContainer = HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 12)
	main.add_child(slot_row)

	_item_slots.clear()
	for i: int in range(_reward_items.size()):
		var slot: ItemSlot = ItemSlot.new()
		slot.item = _reward_items[i]
		slot.slot_clicked.connect(_on_slot_clicked.bind(i))
		slot_row.add_child(slot)
		_item_slots.append(slot)

	# --- Item Info Panel ---
	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = true
	_info_label.custom_minimum_size = Vector2(0, 60)
	_info_label.text = "[i]Click an item to see its details.[/i]"
	main.add_child(_info_label)

	# --- Separator ---
	var sep2: HSeparator = HSeparator.new()
	main.add_child(sep2)

	# --- Choose Button ---
	var btn_row: CenterContainer = CenterContainer.new()
	main.add_child(btn_row)

	_select_button = Button.new()
	_select_button.text = "Choose"
	_select_button.custom_minimum_size = Vector2(120, 36)
	_select_button.disabled = true
	_select_button.pressed.connect(_on_choose_pressed)
	btn_row.add_child(_select_button)

	return main


func _on_slot_clicked(_item: RefCounted, index: int) -> void:
	# Deselect previous
	if _selected_index >= 0 and _selected_index < _item_slots.size():
		_item_slots[_selected_index].selected = false

	_selected_index = index
	_item_slots[index].selected = true
	_select_button.disabled = false

	# Update info label with item details
	var item: Variant = _reward_items[index]
	var info_text: String = ""
	var item_name: String = ConstantsData.get_prop(item, "item_name", "Unknown Item")
	var item_desc: String = ConstantsData.get_prop(item, "description", "")
	var item_level: int = ConstantsData.get_prop(item, "level", 0)

	info_text = "[b]%s[/b]" % item_name
	if item_level > 0:
		info_text += " [color=#4dff4d]+%d[/color]" % item_level
	if item_desc != "":
		info_text += "\n%s" % item_desc

	# Show stats if available
	if item.has_method("get_stats_text"):
		var stats_text: String = item.get_stats_text()
		if stats_text != "":
			info_text += "\n[color=#b3d9ff]%s[/color]" % stats_text

	_info_label.text = info_text


func _on_choose_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _reward_items.size():
		return

	var chosen_item: Variant = _reward_items[_selected_index]

	# Give item to hero
	if _hero and _hero.get("belongings") != null:
		var belongings: Variant = _hero.belongings
		if belongings.has_method("add_item"):
			belongings.add_item(chosen_item)

	if MessageLog:
		var chosen_name: String = ConstantsData.get_prop(chosen_item, "item_name", "item")
		if chosen_item.has_method("get_display_name"):
			chosen_name = chosen_item.get_display_name()
		MessageLog.add_positive("You receive the %s!" % chosen_name)

	reward_chosen.emit(chosen_item)

	# Emit quest completion signal
	if EventBus and _quest_name != "":
		EventBus.quest_updated.emit(_quest_name, "reward_chosen")

	close_window()
