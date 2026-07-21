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
var _btn_quickslot_page: Button = null
var _quickslot_sep: VSeparator = null
var _settings_sep: VSeparator = null

# --- Quickslot references ---
var _quickslots: Array[Button] = []
var _quickslot_items: Array[RefCounted] = [null, null, null, null, null, null]
var _quickslot_icons: Array[TextureRect] = []
var _quickslot_labels: Array[Label] = []
var _quickslot_page: int = 0

const QUICKSLOT_COUNT: int = 6
const MOBILE_VISIBLE_QUICKSLOTS: int = 2
const QUICKSLOT_SIZE: Vector2 = Vector2(44, 36)
const QUICKSLOT_ICON_SIZE: Vector2 = Vector2(24, 24)
const MOBILE_QUICKSLOT_SIZE: Vector2 = Vector2(50, 56)
const MOBILE_QUICKSLOT_ICON_SIZE: Vector2 = Vector2(32, 32)
const MOBILE_NARROW_BUTTON_MIN_SIZE: Vector2 = Vector2(50, 56)
const MOBILE_NARROW_PAGE_BUTTON_MIN_SIZE: Vector2 = Vector2(36, 56)
const MOBILE_NARROW_QUICKSLOT_SIZE: Vector2 = Vector2(44, 56)
const MOBILE_NARROW_QUICKSLOT_ICON_SIZE: Vector2 = Vector2(28, 28)
const MOBILE_NARROW_BREAKPOINT: float = 430.0
const MOBILE_ULTRA_NARROW_BREAKPOINT: float = 300.0
const MOBILE_REST_VISIBLE_MIN_WIDTH: float = 560.0
const MOBILE_TOUCH_HIT_SLOP: float = 8.0

# --- Constants ---
const BUTTON_MIN_SIZE: Vector2 = Vector2(80, 36)
const MOBILE_BUTTON_MIN_SIZE: Vector2 = Vector2(58, 56)
const TOOLBAR_PATH: String = "res://assets/spd/interfaces/toolbar.png"
const ICONS_PATH: String = "res://assets/spd/interfaces/icons.png"
const ITEM_SHEET_PATH: String = "res://assets/spd/sprites/items.png"
const ITEM_SPRITE_SIZE: int = 16
const ITEM_SHEET_COLUMNS: int = 16
const ICON_REGION_INVENTORY: Rect2 = Rect2(161, 0, 14, 15)
const ICON_REGION_MAP: Rect2 = Rect2(136, 0, 17, 15)
const ICON_REGION_WAIT: Rect2 = Rect2(178, 2, 12, 12)
const ICON_REGION_REST: Rect2 = Rect2(178, 2, 12, 12)
const ICON_REGION_SEARCH: Rect2 = Rect2(194, 2, 12, 12)
const ICON_REGION_SETTINGS: Rect2 = Rect2(102, 0, 14, 14)
const ICON_REGION_MORE: Rect2 = Rect2(128, 0, 21, 23)
const TOOLBAR_BUTTON_REGION: Rect2 = Rect2(0, 0, 22, 22)
const TOOLBAR_QUICKSLOT_REGION: Rect2 = Rect2(64, 0, 20, 22)

## Tracks last known enabled state to avoid re-applying every frame.
var _last_enabled: bool = true
var _last_action_controls_enabled: bool = true
var _compact_mode: bool = false
var _available_width: float = 0.0

static var _item_sheet_texture: Texture2D = null
static var _item_sprite_cache: Dictionary = {}


func _ready() -> void:
	name = "ToolbarButtons"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)

	_btn_inventory = _create_spd_button("Inventory", "I", TOOLBAR_PATH, ICON_REGION_INVENTORY)
	_btn_map = _create_spd_button("Map", "M", ICONS_PATH, ICON_REGION_MAP)
	_btn_wait = _create_spd_button("Wait", "Space", TOOLBAR_PATH, ICON_REGION_WAIT)
	_btn_rest = _create_spd_button("Rest until interrupted", "R", TOOLBAR_PATH, ICON_REGION_REST)
	_btn_search = _create_spd_button("Search", "S", TOOLBAR_PATH, ICON_REGION_SEARCH)

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

	_btn_quickslot_page = _create_spd_button("More quickslots", "Tab", TOOLBAR_PATH, ICON_REGION_MORE)
	add_child(_btn_quickslot_page)

	# --- Another separator before settings ---
	_settings_sep = VSeparator.new()
	_settings_sep.custom_minimum_size = Vector2(2, 0)
	_settings_sep.modulate = Color(0.5, 0.45, 0.35)
	add_child(_settings_sep)

	_btn_settings = _create_spd_button("Menu", "Esc", ICONS_PATH, ICON_REGION_SETTINGS)
	add_child(_btn_settings)

	_btn_inventory.pressed.connect(_on_inventory)
	_btn_map.pressed.connect(_on_map)
	_btn_wait.pressed.connect(_on_wait)
	_btn_rest.pressed.connect(_on_rest)
	_btn_search.pressed.connect(_on_search)
	_btn_quickslot_page.pressed.connect(_on_quickslot_page)
	_btn_settings.pressed.connect(_on_settings)
	_apply_button_labels()


## Create an SPD atlas-backed button matching the stone/chrome toolbar aesthetic.
func _create_spd_button(label: String, shortcut_key: String, icon_path: String, icon_region: Rect2) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.tooltip_text = "%s [%s]" % [label, shortcut_key]
	btn.custom_minimum_size = BUTTON_MIN_SIZE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.icon = UIUtils.atlas_texture(icon_path, icon_region)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 24)
	btn.add_theme_font_size_override("font_size", 1)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.65, 0.5))

	var normal: StyleBoxTexture = UIUtils.toolbar_stylebox(
		TOOLBAR_BUTTON_REGION,
		Vector4(5, 5, 5, 5),
		Vector4(6, 6, 6, 6),
		Color(1, 1, 1, 0.96)
	)
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxTexture = normal.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.18, 1.15, 0.98, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxTexture = normal.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.78, 0.78, 0.7, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn


## Create a quickslot button.
func _create_quickslot_button(index: int) -> Button:
	var btn := Button.new()
	btn.name = "Quickslot%d" % index
	btn.custom_minimum_size = QUICKSLOT_SIZE
	btn.clip_text = false
	btn.text = ""

	var normal: StyleBoxTexture = UIUtils.toolbar_stylebox(
		TOOLBAR_QUICKSLOT_REGION,
		Vector4(5, 5, 5, 5),
		Vector4(4, 4, 4, 4),
		Color(1, 1, 1, 0.96)
	)
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxTexture = normal.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.18, 1.15, 0.98, 1.0)
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
	var region := Rect2(
		col * ITEM_SPRITE_SIZE,
		row * ITEM_SPRITE_SIZE,
		ITEM_SPRITE_SIZE,
		ITEM_SPRITE_SIZE
	)
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


func set_available_width(available_width: float) -> void:
	if is_equal_approx(_available_width, available_width):
		return
	var first_visible_quickslot: int = _quickslot_page * _visible_quickslots_per_page()
	_available_width = maxf(0.0, available_width)
	_quickslot_page = floori(float(first_visible_quickslot) / float(maxi(1, _visible_quickslots_per_page())))
	_apply_button_labels()


func _is_narrow_compact_mode() -> bool:
	return _compact_mode and _available_width > 0.0 and _available_width <= MOBILE_NARROW_BREAKPOINT


func _is_ultra_narrow_compact_mode() -> bool:
	return _compact_mode and _available_width > 0.0 and _available_width <= MOBILE_ULTRA_NARROW_BREAKPOINT


func _can_show_compact_rest_button() -> bool:
	return _compact_mode and _available_width >= MOBILE_REST_VISIBLE_MIN_WIDTH


func _visible_quickslots_per_page() -> int:
	return 1 if _is_ultra_narrow_compact_mode() else MOBILE_VISIBLE_QUICKSLOTS


func _apply_button_labels() -> void:
	var is_narrow_compact: bool = _is_narrow_compact_mode()
	var visible_quickslots_per_page: int = _visible_quickslots_per_page()
	_quickslot_page = clampi(_quickslot_page, 0, _quickslot_page_count() - 1)
	alignment = BoxContainer.ALIGNMENT_CENTER
	var button_size: Vector2 = (
		MOBILE_NARROW_BUTTON_MIN_SIZE
		if is_narrow_compact
		else (MOBILE_BUTTON_MIN_SIZE if _compact_mode else BUTTON_MIN_SIZE)
	)
	var action_font_size: int = 13 if is_narrow_compact else (16 if _compact_mode else 13)
	var quickslot_size: Vector2 = (
		MOBILE_NARROW_QUICKSLOT_SIZE
		if is_narrow_compact
		else (MOBILE_QUICKSLOT_SIZE if _compact_mode else QUICKSLOT_SIZE)
	)
	var quickslot_icon_size: Vector2 = (
		MOBILE_NARROW_QUICKSLOT_ICON_SIZE
		if is_narrow_compact
		else (MOBILE_QUICKSLOT_ICON_SIZE if _compact_mode else QUICKSLOT_ICON_SIZE)
	)
	add_theme_constant_override("separation", 3 if is_narrow_compact else (4 if _compact_mode else 6))

	if _btn_inventory:
		_btn_inventory.text = ""
		_btn_inventory.tooltip_text = "Inventory [I]"
		_btn_inventory.custom_minimum_size = button_size
		_btn_inventory.size = button_size
		_btn_inventory.add_theme_font_size_override("font_size", action_font_size)
	if _btn_map:
		# Map access is essential on mobile: the minimap widget and the M
		# keyboard shortcut are both unavailable there, so keep the toolbar
		# Map button visible in compact mode instead of desktop-only.
		_btn_map.text = ""
		_btn_map.tooltip_text = "Map [M]"
		_btn_map.visible = true
		_btn_map.custom_minimum_size = button_size
		_btn_map.size = button_size
		_btn_map.add_theme_font_size_override("font_size", action_font_size)
	if _btn_wait:
		_btn_wait.text = ""
		_btn_wait.tooltip_text = "Wait [Space]"
		_btn_wait.custom_minimum_size = button_size
		_btn_wait.size = button_size
		_btn_wait.add_theme_font_size_override("font_size", action_font_size)
	if _btn_rest:
		_btn_rest.text = ""
		_btn_rest.tooltip_text = "Rest until interrupted [R]"
		_btn_rest.visible = not _compact_mode or _can_show_compact_rest_button()
		_btn_rest.custom_minimum_size = button_size
		_btn_rest.size = button_size
		_btn_rest.add_theme_font_size_override("font_size", action_font_size)
	if _btn_search:
		_btn_search.text = ""
		_btn_search.tooltip_text = "Search [S]"
		_btn_search.visible = not _is_ultra_narrow_compact_mode()
		_btn_search.custom_minimum_size = button_size
		_btn_search.size = button_size
		_btn_search.add_theme_font_size_override("font_size", action_font_size)
	if _btn_settings:
		_btn_settings.text = ""
		_btn_settings.tooltip_text = "Menu [Esc]"
		_btn_settings.custom_minimum_size = button_size
		_btn_settings.size = button_size
		_btn_settings.add_theme_font_size_override("font_size", action_font_size)
	if _btn_quickslot_page:
		_btn_quickslot_page.visible = _compact_mode
		_btn_quickslot_page.custom_minimum_size = (
			MOBILE_NARROW_PAGE_BUTTON_MIN_SIZE
			if is_narrow_compact
			else button_size
		)
		_btn_quickslot_page.size = _btn_quickslot_page.custom_minimum_size
		_btn_quickslot_page.add_theme_font_size_override(
			"font_size",
			13 if is_narrow_compact else action_font_size
		)
		var next_page: int = (_quickslot_page + 1) % _quickslot_page_count()
		var next_start: int = next_page * visible_quickslots_per_page
		var next_end: int = mini(QUICKSLOT_COUNT, next_start + visible_quickslots_per_page)
		_btn_quickslot_page.text = ""
		_btn_quickslot_page.tooltip_text = (
			"Show quickslots %d-%d" % [next_start + 1, next_end]
		)
	if _quickslot_sep:
		_quickslot_sep.visible = not is_narrow_compact
	if _settings_sep:
		_settings_sep.visible = not is_narrow_compact
	var first_visible_quickslot: int = _quickslot_page * visible_quickslots_per_page
	var last_visible_quickslot: int = first_visible_quickslot + visible_quickslots_per_page
	for i: int in range(_quickslots.size()):
		var is_mobile_hidden_slot: bool = (
			_compact_mode
			and (i < first_visible_quickslot or i >= last_visible_quickslot)
		)
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
	_fit_compact_width_to_viewport()


func _fit_compact_width_to_viewport() -> void:
	if not _compact_mode or _available_width <= 0.0:
		return
	var min_width: float = _visible_min_width()
	if min_width <= _available_width:
		return
	var scale_factor: float = maxf(0.6, _available_width / min_width)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	for button: Button in [_btn_inventory, _btn_map, _btn_wait, _btn_rest, _btn_search, _btn_settings]:
		if button == null or not button.visible:
			continue
		button.custom_minimum_size.x = floorf(button.custom_minimum_size.x * scale_factor)
		button.size.x = button.custom_minimum_size.x
		button.add_theme_font_size_override("font_size", 12 if scale_factor < 0.85 else 13)
	if _btn_quickslot_page != null and _btn_quickslot_page.visible:
		_btn_quickslot_page.custom_minimum_size.x = floorf(_btn_quickslot_page.custom_minimum_size.x * scale_factor)
		_btn_quickslot_page.size.x = _btn_quickslot_page.custom_minimum_size.x
		_btn_quickslot_page.add_theme_font_size_override("font_size", 12 if scale_factor < 0.85 else 13)
	for i: int in range(_quickslots.size()):
		if not _quickslots[i].visible:
			continue
		_quickslots[i].custom_minimum_size.x = floorf(_quickslots[i].custom_minimum_size.x * scale_factor)
		_quickslots[i].size.x = _quickslots[i].custom_minimum_size.x
		if i < _quickslot_icons.size():
			var icon: TextureRect = _quickslot_icons[i]
			icon.size.x = minf(icon.size.x, maxf(24.0, _quickslots[i].custom_minimum_size.x - 10.0))
			icon.custom_minimum_size.x = icon.size.x
			icon.position.x = (_quickslots[i].custom_minimum_size.x - icon.size.x) * 0.5


func _visible_min_width() -> float:
	var width: float = 0.0
	var visible_controls: int = 0
	for child: Node in get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		width += control.custom_minimum_size.x
		visible_controls += 1
	if visible_controls > 1:
		width += float(visible_controls - 1) * float(get_theme_constant("separation"))
	return width


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
	if _btn_quickslot_page:
		_btn_quickslot_page.disabled = not is_enabled
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
	var toolbar_pos: Vector2 = _to_toolbar_position(screen_pos)
	var button_actions: Array[Dictionary] = [
		{"button": _btn_inventory, "callback": Callable(self, "_on_inventory")},
		{"button": _btn_map, "callback": Callable(self, "_on_map")},
		{"button": _btn_wait, "callback": Callable(self, "_on_wait")},
		{"button": _btn_rest, "callback": Callable(self, "_on_rest")},
		{"button": _btn_search, "callback": Callable(self, "_on_search")},
		{"button": _btn_quickslot_page, "callback": Callable(self, "_on_quickslot_page")},
		{"button": _btn_settings, "callback": Callable(self, "_on_settings")},
	]
	for entry: Dictionary in button_actions:
		var button: Button = entry.get("button") as Button
		if _button_accepts_position(button, screen_pos, toolbar_pos):
			var callback: Callable = entry.get("callback") as Callable
			callback.call()
			return true

	for index: int in range(_quickslots.size()):
		var button: Button = _quickslots[index]
		if _button_accepts_position(button, screen_pos, toolbar_pos):
			_on_quickslot_pressed(index)
			return true
	return false


func _to_toolbar_position(screen_pos: Vector2) -> Vector2:
	var global_rect: Rect2 = get_global_rect()
	if global_rect.has_point(screen_pos):
		return screen_pos - global_rect.position
	return screen_pos


func _button_accepts_position(button: Button, screen_pos: Vector2, toolbar_pos: Vector2) -> bool:
	if button == null or not button.visible or button.disabled:
		return false
	var hit_slop: float = MOBILE_TOUCH_HIT_SLOP if _compact_mode else 0.0
	if button.get_global_rect().grow(hit_slop).has_point(screen_pos):
		return true
	return Rect2(button.position, _hit_size_for_button(button)).grow(hit_slop).has_point(toolbar_pos)


func _hit_size_for_button(button: Button) -> Vector2:
	return Vector2(
		maxf(button.size.x, button.custom_minimum_size.x),
		maxf(button.size.y, button.custom_minimum_size.y)
	)


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

func _on_quickslot_page() -> void:
	_quickslot_page = (_quickslot_page + 1) % _quickslot_page_count()
	_apply_button_labels()

func _quickslot_page_count() -> int:
	return ceili(float(QUICKSLOT_COUNT) / float(_visible_quickslots_per_page()))

func _on_settings() -> void:
	settings_pressed.emit()

func _on_quickslot_pressed(index: int) -> void:
	var item: RefCounted = _quickslot_items[index] if index < _quickslot_items.size() else null
	quickslot_used.emit(index, item)
