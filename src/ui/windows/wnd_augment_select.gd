class_name WndAugmentSelect
extends WndBase
## Simple selector for choosing an augmentation mode for a weapon or armor.

var _item: Item = null
var _callback: Callable = Callable()

func _init() -> void:
	window_title = "Augment"
	custom_minimum_size = Vector2(300, 180)

func setup(item: Item, callback: Callable) -> void:
	_item = item
	_callback = callback

func _build_content() -> Control:
	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)

	var label: Label = Label.new()
	label.text = "Choose an augmentation for %s" % ConstantsData.get_prop(_item, "item_name", "item")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(label)

	for option: Dictionary in _options_for_item():
		var btn: Button = create_spd_button(str(option.get("label", "Option")))
		btn.pressed.connect(_choose.bind(str(option.get("value", ""))))
		main.add_child(btn)

	return main

func _options_for_item() -> Array[Dictionary]:
	if _item is Armor:
		return [
			{"label": "Evasion", "value": "evasion"},
			{"label": "Defense", "value": "defense"},
		]
	return [
		{"label": "Speed", "value": "speed"},
		{"label": "Damage", "value": "damage"},
	]

func _choose(value: String) -> void:
	if _callback.is_valid():
		_callback.call(_item, value)
	close_window()
