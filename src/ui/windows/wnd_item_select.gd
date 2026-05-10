class_name WndItemSelect
extends WndBase
## A popup window that shows a list of items for the player to choose one.
## Used by Scroll of Identify, Scroll of Upgrade, Scroll of Transmutation, etc.
## The selected item is passed to the provided callback.

var _items: Array[Item] = []
var _prompt: String = "Select an item:"
var _callback: Callable = Callable()
var _online_action_type: String = ""

func _init() -> void:
	window_title = "Select Item"
	custom_minimum_size = Vector2(320, 200)


## Configure before adding to the scene tree.
## items: Array of items to choose from.
## prompt: Text shown at the top.
## callback: Callable that takes the selected item as argument.
func setup(items: Array, prompt: String, callback: Callable) -> void:
	_items = items
	_prompt = prompt
	_callback = callback

func setup_online(items: Array, prompt: String, action_type: String) -> void:
	_items = items
	_prompt = prompt
	_online_action_type = action_type
	_callback = Callable()


func _build_content() -> Control:
	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 6)

	# Prompt label
	var prompt_label: Label = Label.new()
	prompt_label.text = _prompt
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(prompt_label)

	# Scrollable item list
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 150)
	main.add_child(scroll)

	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	for i: int in range(_items.size()):
		var item: Variant = _items[i]
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var icon_slot: ItemSlot = ItemSlot.new()
		icon_slot.item = item
		icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_slot)

		var btn: Button = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Build display text
		var display_name: String = "Unknown Item"
		if item.has_method("get_display_name"):
			display_name = item.get_display_name()
		elif item.get("item_name"):
			display_name = item.item_name

		# Add level/upgrade info if available
		var level_str: String = ""
		if ConstantsData.get_prop(item, "level", 0) > 0:
			level_str = " +%d" % item.level

		btn.text = display_name + level_str

		# Color the text based on item quality
		var item_color: Color = ConstantsData.get_prop(item, "icon_color", Color.WHITE) if item is Object else Color.WHITE
		btn.add_theme_color_override("font_color", item_color)

		# Capture the item for the callback
		var item_ref: Variant = item
		btn.pressed.connect(func() -> void: _on_item_selected(item_ref))
		row.add_child(btn)
		list.add_child(row)

	return main


func _on_item_selected(item: Variant) -> void:
	if not _online_action_type.is_empty():
		if EventBus and EventBus.has_signal("request_hero_action"):
			EventBus.request_hero_action.emit({
				"type": _online_action_type,
				"item": item,
			})
		close_window()
		return
	if _callback.is_valid():
		_callback.call(item)
	close_window()
