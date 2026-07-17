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
var _btn_rest: Button = null
var _btn_search: Button = null
var _btn_settings: Button = null
var _quickslot_sep: VSeparator = null
var _settings_sep: VSeparator = null

# --- Quickslot references ---
var _quickslots: Array[Button] = []
var _quickslot_items: Array[RefCounted] = [null, null, null, null, null, null]
var _quickslot_icons: Array[TextureRect] = []
var _quickslot_labels: Array[Label] = []

const QUICKSLOT_COUNT: int = 6
const QUICKSLOT_SIZE: Vector2 = Vector2(44, 36)
const QUICKSLOT_ICON_SIZE: Vector2 = Vector2(24, 24)
const MOBILE_QUICKSLOT_SIZE: Vector2 = Vector2(50, 56)
const MOBILE_QUICKSLOT_ICON_SIZE: Vector2 = Vector2(32, 32)

# --- Constants ---
const BUTTON_MIN_SIZE: Vector2 = Vector2(80, 36)
const MOBILE_BUTTON_MIN_SIZE: Vector2 = Vector2(58, 56)
const TOOLBAR_PATH: String = "res://assets/spd/interfaces/toolbar.png"
const ITEM_SHEET_PATH: String = "res://assets/spd/sprites/items.png"
const ITEM_SPRITE_SIZE: int = 16
const ITEM_SHEET_COLUMNS: int = 16

## Tracks last known enabled state to avoid re-applying every frame.
var _last_enabled: bool = true
var _last_action_controls_enabled: bool = true
var _compact_mode: bool = false

static var _item_sheet_texture: Texture2D = null
static var _item_sprite_cache: Dictionary = {}


func _ready() -> void:
	name = "ToolbarButtons"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)

	_btn_inventory = _create_spd_button("Inventory", "I")
	_btn_map = _create_spd_button("Map", "M")
	_btn_wait = _create_spd_button("Wait", "Space")
	_btn_rest = _create_spd_button("Rest", "R")
	_btn_search = _create_spd_button("Search", "S")

	add_child(_btn_inventory)
	add_child(_btn_map)
	add_child(_btn_wait)
	add_child(_btn_rest)
	add_child(_btn_search)

	# --- Quickslot separator ---
	_quickslot_sep = VSeparator.new()
	_quickslot_sep.custom_minimum_size = Vector2(2, 0)
	_quickslot_sep.modulate = Color(0.5, 0.45, 0.35)
	add_child(_quickslot_sep)

	# --- Quickslot buttons ---
	for i in QUICKSLOT_COUNT:
		var qs_btn: Button = _create_quickslot_button(i)
		_quickslots.append(qs_btn)
		add_child(qs_btn)

	# --- Another separator before settings ---
	_settings_sep = VSeparator.new()
	_settings_sep.custom_minimum_size = Vector2(2, 0)
	_settings_sep.modulate = Color(0.5, 0.45, 0.35)
	add_child(_settings_sep)

	_btn_settings = _create_spd_button("Settings", "Esc")
	add_child(_btn_settings)

	_btn_inventory.pressed.connect(_on_inventory)
	_btn_map.pressed.connect(_on_map)
	_btn_wait.pressed.connect(_on_wait)
	_btn_rest.pressed.connect(_on_rest)
	_btn_search.pressed.connect(_on_search)
	_btn_settings.pressed.connect(_on_settings)
	_apply_button_labels()


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
	btn.custom_minimum_size = QUICKSLOT_SIZE
	btn.clip_text = false

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

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = QUICKSLOT_ICON_SIZE
	icon.size = QUICKSLOT_ICON_SIZE
	icon.position = Vector2((QUICKSLOT_SIZE.x - QUICKSLOT_ICON_SIZE.x) * 0.5, 4)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	_quickslot_icons.append(icon)

	var slot_label := Label.new()
	slot_label.name = "SlotLabel"
	slot_label.text = str(index + 1)
	slot_label.position = Vector2(4, QUICKSLOT_SIZE.y - 16)
	slot_label.add_theme_font_size_override("font_size", 11)
	slot_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	slot_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	slot_label.add_theme_constant_override("shadow_offset_x", 1)
	slot_label.add_theme_constant_override("shadow_offset_y", 1)
	slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(slot_label)
	_quickslot_labels.append(slot_label)

	btn.pressed.connect(_on_quickslot_pressed.bind(index))
	return btn


## Assign an item to a quickslot.
func set_quickslot_item(index: int, item: RefCounted) -> void:
	if index < 0 or index >= QUICKSLOT_COUNT:
		return
	_quickslot_items[index] = item
	if index < _quickslots.size():
		if item and item.get("item_name") != null:
			_quickslots[index].tooltip_text = str(item.item_name)
		else:
			_quickslots[index].tooltip_text = "Empty quickslot"
	if index < _quickslot_icons.size():
		_quickslot_icons[index].texture = _get_item_texture(item)
		_quickslot_icons[index].visible = _quickslot_icons[index].texture != null


func _get_item_texture(item: RefCounted) -> Texture2D:
	if item == null or item.get("sprite_index") == null:
		return null
	var sprite_index: int = int(item.sprite_index)
	if sprite_index < 0:
		return null
	if _item_sprite_cache.has(sprite_index):
		return _item_sprite_cache[sprite_index] as Texture2D
	if _item_sheet_texture == null:
		if ResourceLoader.exists(ITEM_SHEET_PATH):
			_item_sheet_texture = load(ITEM_SHEET_PATH) as Texture2D
		if _item_sheet_texture == null:
			return null
	var col: int = sprite_index % ITEM_SHEET_COLUMNS
	var row: int = sprite_index / ITEM_SHEET_COLUMNS
	var region := Rect2(col * ITEM_SPRITE_SIZE, row * ITEM_SPRITE_SIZE, ITEM_SPRITE_SIZE, ITEM_SPRITE_SIZE)
	var atlas := AtlasTexture.new()
	atlas.atlas = _item_sheet_texture
	atlas.region = region
	atlas.filter_clip = true
	_item_sprite_cache[sprite_index] = atlas
	return atlas


func set_compact_mode(is_compact: bool) -> void:
	if _compact_mode == is_compact:
		return
	_compact_mode = is_compact
	_apply_button_labels()


func _apply_button_labels() -> void:
	var button_size: Vector2 = MOBILE_BUTTON_MIN_SIZE if _compact_mode else BUTTON_MIN_SIZE
	var action_font_size: int = 16 if _compact_mode else 13
	var quickslot_size: Vector2 = MOBILE_QUICKSLOT_SIZE if _compact_mode else QUICKSLOT_SIZE
	var quickslot_icon_size: Vector2 = MOBILE_QUICKSLOT_ICON_SIZE if _compact_mode else QUICKSLOT_ICON_SIZE
	add_theme_constant_override("separation", 4 if _compact_mode else 6)

	if _btn_inventory:
		_btn_inventory.text = "Bag" if _compact_mode else "Inventory [I]"
		_btn_inventory.custom_minimum_size = button_size
		_btn_inventory.add_theme_font_size_override("font_size", action_font_size)
	if _btn_map:
		_btn_map.text = "Map [M]"
		_btn_map.visible = not _compact_mode
		_btn_map.custom_minimum_size = button_size
		_btn_map.add_theme_font_size_override("font_size", action_font_size)
	if _btn_wait:
		_btn_wait.text = "Wait" if _compact_mode else "Wait [Space]"
		_btn_wait.custom_minimum_size = button_size
		_btn_wait.add_theme_font_size_override("font_size", action_font_size)
	if _btn_rest:
		_btn_rest.text = "Rest [R]"
		_btn_rest.visible = not _compact_mode
		_btn_rest.custom_minimum_size = button_size
		_btn_rest.add_theme_font_size_override("font_size", action_font_size)
	if _btn_search:
		_btn_search.text = "Find" if _compact_mode else "Search [S]"
		_btn_search.custom_minimum_size = button_size
		_btn_search.add_theme_font_size_override("font_size", action_font_size)
	if _btn_settings:
		_btn_settings.text = "Menu" if _compact_mode else "Settings [Esc]"
		_btn_settings.custom_minimum_size = button_size
		_btn_settings.add_theme_font_size_override("font_size", action_font_size)
	if _quickslot_sep:
		_quickslot_sep.visible = true
	if _settings_sep:
		_settings_sep.visible = true
	for i: int in range(_quickslots.size()):
		var is_mobile_hidden_slot: bool = _compact_mode and i >= 2
		_quickslots[i].visible = not is_mobile_hidden_slot
		_quickslots[i].custom_minimum_size = quickslot_size
		_quickslots[i].size = quickslot_size
		if i < _quickslot_icons.size():
			var icon: TextureRect = _quickslot_icons[i]
			icon.custom_minimum_size = quickslot_icon_size
			icon.size = quickslot_icon_size
			icon.position = Vector2(
				(quickslot_size.x - quickslot_icon_size.x) * 0.5,
				5.0 if _compact_mode else 4.0
			)
		if i < _quickslot_labels.size():
			var slot_label: Label = _quickslot_labels[i]
			slot_label.position = Vector2(5.0, quickslot_size.y - 20.0)
			slot_label.add_theme_font_size_override("font_size", 13 if _compact_mode else 11)


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
	if _btn_rest:
		_btn_rest.disabled = not is_enabled
	if _btn_search:
		_btn_search.disabled = not is_enabled
	if _btn_settings:
		_btn_settings.disabled = not is_enabled
	for qs: Button in _quickslots:
		qs.disabled = not is_enabled

func set_action_controls_enabled(is_enabled: bool) -> void:
	if is_enabled == _last_action_controls_enabled:
		return
	_last_action_controls_enabled = is_enabled
	if _btn_inventory:
		_btn_inventory.disabled = not is_enabled
		_btn_inventory.modulate = Color.WHITE if is_enabled else Color(0.72, 0.72, 0.72, 0.9)
	if _btn_wait:
		_btn_wait.disabled = not is_enabled
		_btn_wait.modulate = Color.WHITE if is_enabled else Color(0.72, 0.72, 0.72, 0.9)
	if _btn_rest:
		_btn_rest.disabled = not is_enabled
		_btn_rest.modulate = Color.WHITE if is_enabled else Color(0.72, 0.72, 0.72, 0.9)
	if _btn_search:
		_btn_search.disabled = not is_enabled
		_btn_search.modulate = Color.WHITE if is_enabled else Color(0.72, 0.72, 0.72, 0.9)
	for qs: Button in _quickslots:
		qs.disabled = not is_enabled
		qs.modulate = Color.WHITE if is_enabled else Color(0.72, 0.72, 0.72, 0.9)


func activate_button_at_screen_position(screen_pos: Vector2) -> bool:
	var button_actions: Array[Dictionary] = [
		{"button": _btn_inventory, "callback": Callable(self, "_on_inventory")},
		{"button": _btn_map, "callback": Callable(self, "_on_map")},
		{"button": _btn_wait, "callback": Callable(self, "_on_wait")},
		{"button": _btn_rest, "callback": Callable(self, "_on_rest")},
		{"button": _btn_search, "callback": Callable(self, "_on_search")},
		{"button": _btn_settings, "callback": Callable(self, "_on_settings")},
	]
	for entry: Dictionary in button_actions:
		var button: Button = entry.get("button") as Button
		if _button_accepts_screen_position(button, screen_pos):
			var callback: Callable = entry.get("callback") as Callable
			callback.call()
			return true

	for index: int in range(_quickslots.size()):
		var button: Button = _quickslots[index]
		if _button_accepts_screen_position(button, screen_pos):
			_on_quickslot_pressed(index)
			return true
	return false


func _button_accepts_screen_position(button: Button, screen_pos: Vector2) -> bool:
	return button != null \
			and button.visible \
			and not button.disabled \
			and button.get_global_rect().has_point(screen_pos)


# --- Signal Callbacks ---

func _on_inventory() -> void:
	inventory_pressed.emit()

func _on_map() -> void:
	map_pressed.emit()

func _on_wait() -> void:
	wait_pressed.emit()

func _on_rest() -> void:
	rest_pressed.emit()

func _on_search() -> void:
	search_pressed.emit()

func _on_settings() -> void:
	settings_pressed.emit()

func _on_quickslot_pressed(index: int) -> void:
	var item: RefCounted = _quickslot_items[index] if index < _quickslot_items.size() else null
	quickslot_used.emit(index, item)
