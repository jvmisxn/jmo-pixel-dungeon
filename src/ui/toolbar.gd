class_name Toolbar
extends HBoxContainer
## Bottom toolbar with SPD-styled icon buttons for common actions and quickslot item buttons.
## Uses the original SPD toolbar.png asset for background styling.
## Each button displays its keyboard shortcut and emits a signal when pressed.
## Quickslots allow one-click use of assigned items (potions, scrolls, throwables).

# --- Signals ---
@warning_ignore("unused_signal")
signal inventory_pressed
@warning_ignore("unused_signal")
signal map_pressed
@warning_ignore("unused_signal")
signal wait_pressed
@warning_ignore("unused_signal")
signal search_pressed
@warning_ignore("unused_signal")
signal rest_pressed
@warning_ignore("unused_signal")
signal settings_pressed
@warning_ignore("unused_signal")
signal quickslot_used(slot_index: int, item: RefCounted)

# --- Button references ---
var _btn_inventory: Button = null
var _btn_map: Button = null
var _btn_wait: Button = null
var _btn_search: Button = null
var _btn_settings: Button = null

# --- Quickslot references ---
var _quickslots: Array[Button] = []
var _quickslot_items: Array[RefCounted] = [null, null, null, null, null, null]

const QUICKSLOT_COUNT: int = 6
const QUICKSLOT_SIZE: Vector2 = Vector2(44, 36)

# --- Constants ---
const BUTTON_MIN_SIZE: Vector2 = Vector2(80, 36)
const TOOLBAR_PATH: String = "res://assets/spd/interfaces/toolbar.png"

## Tracks last known enabled state to avoid re-applying every frame.
var _last_enabled: bool = true


func _ready() -> void:
	name = "ToolbarButtons"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)

	_btn_inventory = _create_spd_button("Inventory", "I")
	_btn_map = _create_spd_button("Map", "M")
	_btn_wait = _create_spd_button("Wait", "Space")
	_btn_search = _create_spd_button("Search", "S")

	add_child(_btn_inventory)
	add_child(_btn_map)
	add_child(_btn_wait)
	add_child(_btn_search)

	# --- Quickslot separator ---
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(2, 0)
	sep.modulate = Color(0.5, 0.45, 0.35)
	add_child(sep)

	# --- Quickslot buttons ---
	for i in QUICKSLOT_COUNT:
		var qs_btn: Button = _create_quickslot_button(i)
		_quickslots.append(qs_btn)
		add_child(qs_btn)

	# --- Another separator before settings ---
	var sep2 := VSeparator.new()
	sep2.custom_minimum_size = Vector2(2, 0)
	sep2.modulate = Color(0.5, 0.45, 0.35)
	add_child(sep2)

	_btn_settings = _create_spd_button("Settings", "Esc")
	add_child(_btn_settings)

	_btn_inventory.pressed.connect(_on_inventory)
	_btn_map.pressed.connect(_on_map)
	_btn_wait.pressed.connect(_on_wait)
	_btn_search.pressed.connect(_on_search)
	_btn_settings.pressed.connect(_on_settings)


## Create an SPD-styled button matching the stone/chrome aesthetic.
func _create_spd_button(label: String, shortcut_key: String) -> Button:
	var btn := Button.new()
	btn.text = "%s [%s]" % [label, shortcut_key]
	btn.custom_minimum_size = BUTTON_MIN_SIZE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.65, 0.5))

	# Normal style — dark stone toolbar look
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.16, 0.14)
	normal.border_color = Color(0.45, 0.4, 0.35)
	normal.set_border_width_all(1)
	normal.border_width_top = 2
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("normal", normal)

	# Hover — slightly lighter stone
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.24, 0.21, 0.17)
	hover.border_color = Color(0.6, 0.55, 0.45)
	hover.set_border_width_all(1)
	hover.border_width_top = 2
	hover.set_corner_radius_all(2)
	hover.content_margin_left = 8.0
	hover.content_margin_right = 8.0
	hover.content_margin_top = 6.0
	hover.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed — darker inset
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.12, 0.1, 0.08)
	pressed.border_color = Color(0.35, 0.3, 0.25)
	pressed.set_border_width_all(1)
	pressed.border_width_top = 2
	pressed.set_corner_radius_all(2)
	pressed.content_margin_left = 8.0
	pressed.content_margin_right = 8.0
	pressed.content_margin_top = 6.0
	pressed.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn


## Create a quickslot button.
func _create_quickslot_button(index: int) -> Button:
	var btn := Button.new()
	btn.name = "Quickslot%d" % index
	btn.text = "%d" % (index + 1)
	btn.custom_minimum_size = QUICKSLOT_SIZE
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.12, 0.1)
	normal.border_color = Color(0.4, 0.35, 0.3)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.2, 0.18, 0.14)
	hover.border_color = Color(0.55, 0.5, 0.4)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(2)
	hover.set_content_margin_all(4)
	btn.add_theme_stylebox_override("hover", hover)

	btn.pressed.connect(_on_quickslot_pressed.bind(index))
	return btn


## Assign an item to a quickslot.
func set_quickslot_item(index: int, item: RefCounted) -> void:
	if index < 0 or index >= QUICKSLOT_COUNT:
		return
	_quickslot_items[index] = item
	if index < _quickslots.size():
		if item and item.get("item_name") != null:
			_quickslots[index].text = str(item.item_name).left(4)
		else:
			_quickslots[index].text = "%d" % (index + 1)


## Enable or disable all toolbar buttons.
func set_enabled(is_enabled: bool) -> void:
	if is_enabled == _last_enabled:
		return
	_last_enabled = is_enabled
	if _btn_inventory:
		_btn_inventory.disabled = not is_enabled
	if _btn_map:
		_btn_map.disabled = not is_enabled
	if _btn_wait:
		_btn_wait.disabled = not is_enabled
	if _btn_search:
		_btn_search.disabled = not is_enabled
	if _btn_settings:
		_btn_settings.disabled = not is_enabled
	for qs: Button in _quickslots:
		qs.disabled = not is_enabled


# --- Signal Callbacks ---

func _on_inventory() -> void:
	inventory_pressed.emit()

func _on_map() -> void:
	map_pressed.emit()

func _on_wait() -> void:
	wait_pressed.emit()

func _on_search() -> void:
	search_pressed.emit()

func _on_settings() -> void:
	settings_pressed.emit()

func _on_quickslot_pressed(index: int) -> void:
	var item: RefCounted = _quickslot_items[index] if index < _quickslot_items.size() else null
	quickslot_used.emit(index, item)
