class_name HeroSelectScene
extends Control
## Hero class selection screen using original SPD splash art and assets.
## Shows the selected hero's splash art as background with hero buttons,
## description, and start button — matching the original SPD layout.

# --- State ---
var _selected_class: int = ConstantsData.HeroClass.WARRIOR
var _party_size: int = 1
var _editing_party_slot: int = 0
var _party_classes: Array[int] = []
var _hero_buttons: Array[Button] = []
var _party_slot_buttons: Array[Button] = []
var _start_button: Button = null
var _back_button: Button = null
var _hero_name_label: Label = null
var _hero_desc_label: Label = null
var _party_summary_label: Label = null
var _network_notice_label: Label = null
var _title_label: Label = null
var _class_button_row: HBoxContainer = null
var _stats_label: Label = null
var _slots_title_label: Label = null
var _party_slots_row: HBoxContainer = null
var _action_row: HBoxContainer = null
var _main_panel: Panel = null
var _left_panel: Panel = null
var _right_panel: Panel = null
var _content_box: VBoxContainer = null
var _layout_viewport_size: Vector2 = Vector2.ZERO
var _web_layout_poll_elapsed: float = 0.0

# --- Background ---
var _bg_color_rect: ColorRect = null
var _back_clusters_sprite: TextureRect = null
var _mid_mixed_sprite: TextureRect = null
var _archs_sprite: TextureRect = null
var _bg_sprite: TextureRect = null
var _fade_overlay: ColorRect = null

# --- Constants ---
const CLASS_COUNT: int = 5
const GOLD_COLOR: Color = Color(1.0, 0.85, 0.3)
const BACK_CLUSTERS_PATH: String = "res://assets/spd/splashes/title/back_clusters.png"
const MID_MIXED_PATH: String = "res://assets/spd/splashes/title/mid_mixed.png"
const ARCHS_PATH: String = "res://assets/spd/splashes/title/archs.png"
const OUTER_PANEL_SIZE: Vector2 = Vector2(760, 680)
const LEFT_PANEL_SIZE: Vector2 = Vector2(380, 640)
const RIGHT_PANEL_SIZE: Vector2 = Vector2(360, 620)
const LAYOUT_MARGIN_X: float = 24.0
const LAYOUT_MARGIN_TOP: float = 20.0
const COLUMN_GAP: float = 16.0
const LEFT_INSET_X: float = 24.0
const LEFT_INSET_Y: float = 24.0
const LEFT_CONTENT_WIDTH: float = 292.0
const STANDARD_ROW_WIDTH: float = 300.0
const ACTION_BUTTON_WIDTH: float = 145.0
const PORTRAIT_TIGHT_HEIGHT: float = 390.0
const WEB_LAYOUT_POLL_INTERVAL: float = 0.25
const PORTRAIT_WEB_SAFE_BOTTOM_RESERVE: float = 92.0
const PORTRAIT_WEB_SAFE_SIDE_RESERVE: float = 16.0

# Hero class splash art paths (800x450 JPGs)
const SPLASH_PATHS: Array[String] = [
	"res://assets/spd/splashes/warrior.jpg",
	"res://assets/spd/splashes/mage.jpg",
	"res://assets/spd/splashes/rogue.jpg",
	"res://assets/spd/splashes/huntress.jpg",
	"res://assets/spd/splashes/duelist.jpg",
]

# Hero spritesheet paths (for button icons — 12x15 at y=90)
const SPRITE_PATHS: Array[String] = [
	"res://assets/spd/sprites/warrior.png",
	"res://assets/spd/sprites/mage.png",
	"res://assets/spd/sprites/rogue.png",
	"res://assets/spd/sprites/huntress.png",
	"res://assets/spd/sprites/duelist.png",
]

const CHROME_PATH: String = "res://assets/spd/interfaces/chrome.png"

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RenderingServer.set_default_clear_color(Color.BLACK)
	_ensure_party_defaults()
	_selected_class = _get_default_selectable_class(_selected_class)
	_build_background()
	_build_ui()
	_apply_layout()
	if NetworkManager and NetworkManager.has_signal("lobby_updated"):
		NetworkManager.lobby_updated.connect(_on_lobby_updated)
	_update_selection()
	if NetworkManager:
		if NetworkManager.has_signal("disconnected"):
			NetworkManager.disconnected.connect(_on_network_disconnected)
		if NetworkManager.has_signal("online_run_start_requested"):
			NetworkManager.online_run_start_requested.connect(_on_online_run_start_requested)
		if NetworkManager.has_method("is_client") and NetworkManager.is_client():
			_apply_network_client_mode()
	get_viewport().size_changed.connect(_apply_layout)

func _process(delta: float) -> void:
	var time_elapsed: float = float(Time.get_ticks_msec()) * 0.001
	if _back_clusters_sprite:
		_back_clusters_sprite.position.x = -fmod(time_elapsed * 2.0, 512.0)
	if _mid_mixed_sprite:
		_mid_mixed_sprite.position.x = -fmod(time_elapsed * 5.0, 2048.0)
	if _archs_sprite:
		_archs_sprite.position.x = -fmod(time_elapsed * 10.0, 1024.0)
	if OS.get_name() == "Web":
		_web_layout_poll_elapsed += delta
		if _web_layout_poll_elapsed >= WEB_LAYOUT_POLL_INTERVAL:
			_web_layout_poll_elapsed = 0.0
			var current_size: Vector2 = _get_layout_viewport_size()
			if not current_size.is_equal_approx(_layout_viewport_size):
				_apply_layout()

func _unhandled_input(event: InputEvent) -> void:
	if _is_left_input(event):
		_selected_class = (_selected_class - 1)
		if _selected_class < 0:
			_selected_class = CLASS_COUNT - 1
		_update_selection()
		get_viewport().set_input_as_handled()
	elif _is_right_input(event):
		_selected_class = (_selected_class + 1) % CLASS_COUNT
		_update_selection()
		get_viewport().set_input_as_handled()
	elif _is_accept_input(event):
		_on_start_pressed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_cycle_party_slot(1)
		get_viewport().set_input_as_handled()
	elif _is_cancel_input(event):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------

func _build_background() -> void:
	_bg_color_rect = ColorRect.new()
	_bg_color_rect.color = Color(0.07, 0.06, 0.1)
	_bg_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_color_rect)

	var clusters_tex: Texture2D = _load_texture(BACK_CLUSTERS_PATH)
	if clusters_tex:
		_back_clusters_sprite = TextureRect.new()
		_back_clusters_sprite.texture = clusters_tex
		_back_clusters_sprite.stretch_mode = TextureRect.STRETCH_TILE
		_back_clusters_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_back_clusters_sprite.modulate = Color(0.25, 0.22, 0.2, 0.5)
		_back_clusters_sprite.position = Vector2.ZERO
		_back_clusters_sprite.size = Vector2(1280 + 512, 720)
		add_child(_back_clusters_sprite)

	var mid_tex: Texture2D = _load_texture(MID_MIXED_PATH)
	if mid_tex:
		_mid_mixed_sprite = TextureRect.new()
		_mid_mixed_sprite.texture = mid_tex
		_mid_mixed_sprite.stretch_mode = TextureRect.STRETCH_TILE
		_mid_mixed_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_mid_mixed_sprite.modulate = Color(0.35, 0.3, 0.28, 0.55)
		_mid_mixed_sprite.position = Vector2(0, 100)
		_mid_mixed_sprite.size = Vector2(1280 + 2048, 620)
		add_child(_mid_mixed_sprite)

	var archs_tex: Texture2D = _load_texture(ARCHS_PATH)
	if archs_tex:
		_archs_sprite = TextureRect.new()
		_archs_sprite.texture = archs_tex
		_archs_sprite.stretch_mode = TextureRect.STRETCH_TILE
		_archs_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_archs_sprite.modulate = Color(0.45, 0.4, 0.35, 0.7)
		_archs_sprite.position = Vector2(0, 720 - 256)
		_archs_sprite.size = Vector2(1280 + 1024, 256)
		add_child(_archs_sprite)

	var top_overlay: ColorRect = ColorRect.new()
	top_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	float fade = smoothstep(0.0, 0.5, UV.y);
	COLOR = vec4(0.0, 0.0, 0.0, 0.55 * (1.0 - fade));
}
"""
	shader_material.shader = shader
	top_overlay.material = shader_material
	add_child(top_overlay)

func _build_ui() -> void:
	_main_panel = Panel.new()
	var main_style: StyleBoxFlat = StyleBoxFlat.new()
	main_style.bg_color = Color(0.08, 0.08, 0.11, 0.9)
	main_style.border_color = Color(0.48, 0.42, 0.3)
	main_style.set_border_width_all(2)
	main_style.set_corner_radius_all(8)
	_main_panel.add_theme_stylebox_override("panel", main_style)
	_main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_main_panel)

	_left_panel = Panel.new()
	_left_panel.custom_minimum_size = LEFT_PANEL_SIZE
	_left_panel.size = LEFT_PANEL_SIZE
	var left_style: StyleBoxFlat = StyleBoxFlat.new()
	left_style.bg_color = Color(0.06, 0.06, 0.08, 0.45)
	left_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	left_style.set_border_width_all(0)
	left_style.set_corner_radius_all(6)
	_left_panel.add_theme_stylebox_override("panel", left_style)
	_left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_panel.add_child(_left_panel)

	_right_panel = Panel.new()
	_right_panel.custom_minimum_size = RIGHT_PANEL_SIZE
	_right_panel.size = RIGHT_PANEL_SIZE
	_right_panel.clip_contents = true
	var right_style: StyleBoxFlat = StyleBoxFlat.new()
	right_style.bg_color = Color(0.05, 0.05, 0.07, 0.2)
	right_style.border_color = Color(0.22, 0.19, 0.14, 0.9)
	right_style.set_border_width_all(1)
	right_style.set_corner_radius_all(6)
	_right_panel.add_theme_stylebox_override("panel", right_style)
	_main_panel.add_child(_right_panel)

	_bg_sprite = TextureRect.new()
	_bg_sprite.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_bg_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_panel.add_child(_bg_sprite)

	_fade_overlay = ColorRect.new()
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_panel.add_child(_fade_overlay)

	# Use a gradient shader for the left-side fade (like original SPD)
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float vignette = smoothstep(0.0, 0.18, edge);
	COLOR = vec4(0.0, 0.0, 0.0, 0.38 * (1.0 - vignette));
}
"""
	shader_material.shader = shader
	_fade_overlay.material = shader_material

	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 12)
	_content_box.position = Vector2(LEFT_INSET_X, LEFT_INSET_Y)
	_content_box.custom_minimum_size = Vector2(LEFT_CONTENT_WIDTH, 592)
	_left_panel.add_child(_content_box)

	# --- Title ---
	_title_label = Label.new()
	_title_label.text = "Choose Your Hero"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	_content_box.add_child(_title_label)

	var class_label: Label = Label.new()
	class_label.text = "Hero Class"
	class_label.add_theme_font_size_override("font_size", 12)
	class_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.85))
	_content_box.add_child(class_label)

	# --- Hero buttons (icon buttons in a row, like original SPD) ---
	_class_button_row = HBoxContainer.new()
	_class_button_row.custom_minimum_size = Vector2(STANDARD_ROW_WIDTH, 48)
	_class_button_row.add_theme_constant_override("separation", 4)
	_content_box.add_child(_class_button_row)

	for i: int in range(CLASS_COUNT):
		var btn: Button = _create_hero_button(i)
		_class_button_row.add_child(btn)
		_hero_buttons.append(btn)

	# --- Hero name ---
	_hero_name_label = Label.new()
	_hero_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_name_label.add_theme_font_size_override("font_size", 16)
	_hero_name_label.add_theme_color_override("font_color", GOLD_COLOR)
	_hero_name_label.custom_minimum_size = Vector2(STANDARD_ROW_WIDTH, 24)
	_content_box.add_child(_hero_name_label)

	# --- Hero description ---
	_hero_desc_label = Label.new()
	_hero_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_desc_label.add_theme_font_size_override("font_size", 12)
	_hero_desc_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.85))
	_hero_desc_label.custom_minimum_size = Vector2(STANDARD_ROW_WIDTH, 120)
	_content_box.add_child(_hero_desc_label)

	# --- Stats ---
	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_stats_label.custom_minimum_size = Vector2(STANDARD_ROW_WIDTH, 40)
	_content_box.add_child(_stats_label)

	# --- Party slots selector ---
	_slots_title_label = Label.new()
	_slots_title_label.text = "Party Loadout"
	_slots_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slots_title_label.add_theme_font_size_override("font_size", 12)
	_slots_title_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.85))
	_slots_title_label.custom_minimum_size = Vector2(STANDARD_ROW_WIDTH, 20)
	_content_box.add_child(_slots_title_label)

	_party_slots_row = HBoxContainer.new()
	_party_slots_row.custom_minimum_size = Vector2(STANDARD_ROW_WIDTH, 42)
	_party_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_party_slots_row.add_theme_constant_override("separation", 6)
	_content_box.add_child(_party_slots_row)

	for slot_index: int in range(GameManager.MAX_PARTY_SIZE):
		var slot_button: Button = _create_party_chip_button("", Vector2(78, 38))
		slot_button.tooltip_text = "Edit party member %d" % (slot_index + 1)
		slot_button.pressed.connect(_on_party_slot_pressed.bind(slot_index))
		_party_slots_row.add_child(slot_button)
		_party_slot_buttons.append(slot_button)

	_party_summary_label = Label.new()
	_party_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_party_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_party_summary_label.add_theme_font_size_override("font_size", 11)
	_party_summary_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	_party_summary_label.custom_minimum_size = Vector2(STANDARD_ROW_WIDTH, 48)
	_content_box.add_child(_party_summary_label)

	_network_notice_label = Label.new()
	_network_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_network_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_network_notice_label.add_theme_font_size_override("font_size", 11)
	_network_notice_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	_network_notice_label.custom_minimum_size = Vector2(STANDARD_ROW_WIDTH, 36)
	_content_box.add_child(_network_notice_label)

	var action_spacer: Control = Control.new()
	action_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_box.add_child(action_spacer)

	# --- Action buttons ---
	_action_row = HBoxContainer.new()
	_action_row.custom_minimum_size = Vector2(STANDARD_ROW_WIDTH, 44)
	_action_row.add_theme_constant_override("separation", 12)
	_content_box.add_child(_action_row)

	_back_button = _create_chrome_button("Back")
	_back_button.custom_minimum_size = Vector2(ACTION_BUTTON_WIDTH, 42)
	_back_button.pressed.connect(_on_back_pressed)
	_action_row.add_child(_back_button)

	_start_button = _create_chrome_button("Start")
	_start_button.custom_minimum_size = Vector2(ACTION_BUTTON_WIDTH, 42)
	_start_button.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	_start_button.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.7))
	_start_button.pressed.connect(_on_start_pressed)
	_action_row.add_child(_start_button)


func _create_hero_button(class_index: int) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(50, 44)
	btn.tooltip_text = HeroClassData.get_class_name_str(class_index)

	# Load the hero icon from spritesheet (12x15 at y=90)
	var icon_tex: Texture2D = _get_hero_icon(class_index)
	if icon_tex:
		btn.icon = icon_tex
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Style: dark with subtle border, brightens on select
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.11, 0.10, 0.85)
	normal.border_color = Color(0.3, 0.28, 0.25)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 4.0
	normal.content_margin_right = 4.0
	normal.content_margin_top = 4.0
	normal.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.16, 0.14, 0.9)
	hover.border_color = Color(0.5, 0.45, 0.35)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.08, 0.07, 0.06)
	btn.add_theme_stylebox_override("pressed", pressed)

	var focus: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focus.border_color = GOLD_COLOR
	focus.set_border_width_all(2)
	btn.add_theme_stylebox_override("focus", focus)

	btn.pressed.connect(_on_hero_button_pressed.bind(class_index))
	return btn


func _get_hero_icon(class_index: int) -> Texture2D:
	if class_index < 0 or class_index >= SPRITE_PATHS.size():
		return null
	var sheet_path: String = SPRITE_PATHS[class_index]
	if not ResourceLoader.exists(sheet_path):
		return null
	var sheet: Texture2D = load(sheet_path) as Texture2D
	if sheet == null:
		return null
	# Extract 12x15 icon from y=90 (the standing/select icon row in SPD)
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0, 90, 12, 15)
	return atlas


func _create_chrome_button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(110, 36)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.65, 0.5))

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.14, 0.12, 0.9)
	normal.border_color = Color(0.4, 0.36, 0.30)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.20, 0.16, 0.95)
	hover.border_color = Color(0.55, 0.50, 0.40)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.10, 0.09, 0.07)
	btn.add_theme_stylebox_override("pressed", pressed)

	var focus: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focus.border_color = GOLD_COLOR
	btn.add_theme_stylebox_override("focus", focus)

	return btn


func _create_party_chip_button(text: String, min_size: Vector2) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.82))

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.11, 0.10, 0.9)
	normal.border_color = Color(0.35, 0.31, 0.26)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.20, 0.18, 0.15, 0.95)
	hover.border_color = Color(0.55, 0.50, 0.40)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.10, 0.09, 0.07)
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn

func _is_accept_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_A
	return false

func _is_cancel_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		return event.keycode == KEY_ESCAPE
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_B
	return false

func _is_left_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		return event.keycode == KEY_LEFT
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_DPAD_LEFT
	return false

func _is_right_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		return event.keycode == KEY_RIGHT
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_DPAD_RIGHT
	return false


# ---------------------------------------------------------------------------
# Selection Logic
# ---------------------------------------------------------------------------

func _update_selection() -> void:
	_ensure_party_defaults()
	var online_party_locked: bool = _is_online_party_locked()
	# Update splash art background
	if _selected_class >= 0 and _selected_class < SPLASH_PATHS.size():
		var splash_path: String = SPLASH_PATHS[_selected_class]
		if _bg_sprite and ResourceLoader.exists(splash_path):
			_bg_sprite.texture = load(splash_path) as Texture2D
			_bg_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			_update_splash_crop()
		elif _bg_sprite:
			_bg_sprite.texture = null

	# Update hero name and description labels
	if _hero_name_label:
		var hero_class_name: String = HeroClassData.get_class_name_str(_selected_class)
		var unlocked: bool = _is_class_unlocked(_selected_class)
		if online_party_locked:
			var display_name: String = _get_party_slot_display_name(_editing_party_slot)
			_hero_name_label.text = "%s: %s" % [display_name, hero_class_name]
		else:
			_hero_name_label.text = hero_class_name if unlocked else "%s (Locked)" % hero_class_name
	if _hero_desc_label:
		var class_desc: String = HeroClassData.get_class_description(_selected_class)
		if not _is_class_unlocked(_selected_class):
			class_desc += "\n\nUnlock: %s" % PlayerProfile.get_hero_unlock_text(_selected_class)
		_hero_desc_label.text = class_desc

	# Update stats label
	if _stats_label:
		var starting: Variant = HeroClassData.get_starting_stats(_selected_class)
		if starting:
			_stats_label.text = "HP: %d  STR: %d" % [starting.hp, starting.str_val]

	for idx: int in range(_party_slot_buttons.size()):
		var slot_button: Button = _party_slot_buttons[idx]
		var slot_active: bool = idx < _party_size
		slot_button.disabled = not slot_active
		if slot_active:
			var hero_class_name: String = HeroClassData.get_class_name_str(_party_classes[idx])
			var player_name: String = _get_party_slot_display_name(idx)
			var compact_player_name: String = player_name.left(7)
			slot_button.text = "%s %s" % [compact_player_name, hero_class_name.left(3)]
			slot_button.tooltip_text = "%s: %s" % [player_name, hero_class_name]
			slot_button.modulate = Color(1, 1, 1, 1)
		else:
			slot_button.text = "Empty"
			slot_button.tooltip_text = "Unused slot"
			slot_button.modulate = Color(0.7, 0.7, 0.7, 0.7)
		_apply_party_button_style(slot_button, slot_active and idx == _editing_party_slot)

	if _slots_title_label:
		_slots_title_label.visible = online_party_locked
	if _party_slots_row:
		_party_slots_row.visible = online_party_locked

	if _party_summary_label:
		_party_summary_label.visible = online_party_locked
		if online_party_locked:
			var party_parts: Array[String] = []
			for idx: int in range(_party_size):
				party_parts.append("%s %s" % [_get_party_slot_display_name(idx), HeroClassData.get_class_name_str(_party_classes[idx])])
			_party_summary_label.text = "Online party locked to %d connected player%s: %s" % [_party_size, "" if _party_size == 1 else "s", ", ".join(party_parts)]
	if _network_notice_label:
		_network_notice_label.visible = online_party_locked
		if NetworkManager and NetworkManager.has_method("is_host") and NetworkManager.is_host():
			var ready_summary: String = NetworkManager.get_ready_summary() if NetworkManager.has_method("get_ready_summary") else ""
			var notice_text: String = "Host controls class loadout for %d connected player%s." % [_party_size, "" if _party_size == 1 else "s"]
			if not ready_summary.is_empty():
				notice_text += " %s." % ready_summary
			_network_notice_label.text = notice_text
		elif NetworkManager and NetworkManager.has_method("is_client") and NetworkManager.is_client():
			var host_name: String = NetworkManager.get_lobby_player_name(0) if NetworkManager.has_method("get_lobby_player_name") else "host"
			_network_notice_label.text = "Waiting for host %s to choose the class loadout and start the run." % host_name
		else:
			_network_notice_label.text = ""
	if _start_button:
		var selected_unlocked: bool = _is_class_unlocked(_selected_class)
		_start_button.disabled = not selected_unlocked
		_start_button.tooltip_text = "" if selected_unlocked else PlayerProfile.get_hero_unlock_text(_selected_class)

	for i: int in range(_hero_buttons.size()):
		var btn: Button = _hero_buttons[i]
		var class_unlocked: bool = _is_class_unlocked(i)
		btn.tooltip_text = HeroClassData.get_class_name_str(i) if class_unlocked else "%s\nUnlock: %s" % [HeroClassData.get_class_name_str(i), PlayerProfile.get_hero_unlock_text(i)]
		_apply_hero_button_style(btn, i == _selected_class, class_unlocked)
		btn.disabled = false


func _on_hero_button_pressed(class_index: int) -> void:
	_selected_class = class_index
	if _editing_party_slot >= 0 and _editing_party_slot < _party_classes.size():
		_party_classes[_editing_party_slot] = class_index
	_update_selection()


func _on_party_slot_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _party_size:
		return
	_editing_party_slot = slot_index
	_selected_class = _party_classes[_editing_party_slot]
	_update_selection()

func _cycle_party_slot(step: int) -> void:
	if _party_size <= 1:
		return
	_editing_party_slot = posmod(_editing_party_slot + step, _party_size)
	_selected_class = _party_classes[_editing_party_slot]
	_update_selection()


func _ensure_party_defaults() -> void:
	if _is_online_party_locked():
		_party_size = _get_online_party_size()
	else:
		_party_size = 1
	if _party_classes.is_empty():
		_party_classes.append(_selected_class)
	while _party_classes.size() < GameManager.MAX_PARTY_SIZE:
		var default_class: int = (_selected_class + _party_classes.size()) % CLASS_COUNT
		_party_classes.append(default_class)
	if _editing_party_slot < 0:
		_editing_party_slot = 0
	if _editing_party_slot >= _party_classes.size():
		_editing_party_slot = _party_classes.size() - 1
	if _editing_party_slot >= _party_size:
		_editing_party_slot = max(_party_size - 1, 0)
	if _editing_party_slot >= 0 and _editing_party_slot < _party_classes.size():
		_party_classes[_editing_party_slot] = _selected_class

func _is_online_party_locked() -> bool:
	return NetworkManager != null and NetworkManager.has_method("is_online_session") and NetworkManager.is_online_session()

func _get_online_party_size() -> int:
	if not _is_online_party_locked() or not NetworkManager.has_method("get_lobby_players"):
		return clampi(_party_size, 1, GameManager.MAX_PARTY_SIZE)
	return clampi(NetworkManager.get_lobby_players().size(), 1, GameManager.MAX_PARTY_SIZE)

func _get_party_slot_display_name(slot_index: int) -> String:
	if _is_online_party_locked() and NetworkManager != null and NetworkManager.has_method("get_lobby_player_name"):
		return NetworkManager.get_lobby_player_name(slot_index)
	return "Player %d" % (slot_index + 1)

func _apply_layout() -> void:
	var viewport_size: Vector2 = _get_layout_viewport_size()
	_layout_viewport_size = viewport_size
	var is_portrait: bool = viewport_size.y > viewport_size.x
	if is_portrait or viewport_size.x < OUTER_PANEL_SIZE.x:
		_apply_portrait_layout(viewport_size)
		return
	var panel_x: float = floor((viewport_size.x - OUTER_PANEL_SIZE.x) * 0.5)
	var panel_y: float = LAYOUT_MARGIN_TOP
	var left_x: float = 20.0
	var left_y: float = 20.0
	var right_x: float = floor(OUTER_PANEL_SIZE.x * 0.5)
	var right_y: float = floor((OUTER_PANEL_SIZE.y - RIGHT_PANEL_SIZE.y) * 0.5)
	if _main_panel != null:
		_main_panel.position = Vector2(panel_x, panel_y)
		_main_panel.size = OUTER_PANEL_SIZE
	if _left_panel != null:
		_left_panel.position = Vector2(left_x, left_y)
	if _right_panel != null:
		_right_panel.visible = true
		_right_panel.position = Vector2(right_x, right_y)
		_right_panel.size = RIGHT_PANEL_SIZE
		_right_panel.custom_minimum_size = RIGHT_PANEL_SIZE
	if _left_panel != null:
		_left_panel.size = LEFT_PANEL_SIZE
		_left_panel.custom_minimum_size = LEFT_PANEL_SIZE
	if _content_box != null:
		_content_box.position = Vector2(LEFT_INSET_X, LEFT_INSET_Y)
		_content_box.custom_minimum_size = Vector2(LEFT_CONTENT_WIDTH, 592)
		_content_box.size = _content_box.custom_minimum_size
		_content_box.add_theme_constant_override("separation", 12)
	_update_mobile_content_width(LEFT_CONTENT_WIDTH, false)
	_update_splash_crop()


func _apply_portrait_layout(viewport_size: Vector2) -> void:
	var margin: float = 12.0
	var panel_size: Vector2 = Vector2(
		maxf(1.0, viewport_size.x - (margin * 2.0)),
		maxf(1.0, viewport_size.y - (margin * 2.0))
	)
	var tight_portrait: bool = panel_size.y < 590.0
	var inset: float = 14.0 if tight_portrait else 18.0
	var content_width: float = maxf(1.0, panel_size.x - (inset * 2.0))
	var splash_min: float = 94.0 if tight_portrait else 130.0
	var splash_max: float = 150.0 if tight_portrait else 190.0
	var splash_height: float = minf(splash_max, maxf(splash_min, panel_size.y * 0.20))
	var gap: float = 8.0 if tight_portrait else 12.0
	var left_top: float = inset + splash_height + gap
	var left_height: float = maxf(1.0, panel_size.y - left_top - inset)
	if _main_panel != null:
		_main_panel.position = Vector2(margin, margin)
		_main_panel.size = panel_size
	if _left_panel != null:
		_left_panel.position = Vector2(0.0, left_top)
		_left_panel.custom_minimum_size = Vector2(panel_size.x, left_height)
		_left_panel.size = _left_panel.custom_minimum_size
	if _right_panel != null:
		_right_panel.visible = true
		_right_panel.position = Vector2(inset, inset)
		_right_panel.custom_minimum_size = Vector2(content_width, splash_height)
		_right_panel.size = _right_panel.custom_minimum_size
	if _content_box != null:
		_content_box.position = Vector2(inset, 0.0)
		_content_box.custom_minimum_size = Vector2(content_width, left_height)
		_content_box.size = _content_box.custom_minimum_size
		_content_box.add_theme_constant_override("separation", 6 if left_height < PORTRAIT_TIGHT_HEIGHT else 10)
	_update_mobile_content_width(content_width, true, left_height)
	_update_splash_crop()


func _update_mobile_content_width(content_width: float, is_portrait: bool, content_height: float = 0.0) -> void:
	var tight_portrait: bool = is_portrait and content_height < PORTRAIT_TIGHT_HEIGHT
	if _title_label:
		_title_label.add_theme_font_size_override("font_size", 20 if tight_portrait else (23 if is_portrait else 26))
		_title_label.custom_minimum_size = Vector2(content_width, 26 if tight_portrait else 32)
	if _class_button_row:
		_class_button_row.custom_minimum_size = Vector2(content_width, 42 if tight_portrait else 48)
		for child: Node in _class_button_row.get_children():
			var hero_button := child as Button
			if hero_button != null:
				hero_button.custom_minimum_size = Vector2(46 if tight_portrait else 50, 38 if tight_portrait else 44)
	if _hero_name_label:
		_hero_name_label.custom_minimum_size = Vector2(content_width, 20 if tight_portrait else 24)
	if _hero_desc_label:
		_hero_desc_label.custom_minimum_size = Vector2(content_width, 88 if tight_portrait else (132 if is_portrait else 120))
	if _stats_label:
		_stats_label.custom_minimum_size = Vector2(content_width, 28 if tight_portrait else 40)
	if _slots_title_label:
		_slots_title_label.custom_minimum_size = Vector2(content_width, 18 if tight_portrait else 20)
	if _party_slots_row:
		_party_slots_row.custom_minimum_size = Vector2(content_width, 36 if tight_portrait else 42)
	if _party_summary_label:
		_party_summary_label.custom_minimum_size = Vector2(content_width, 34 if tight_portrait else 48)
	if _network_notice_label:
		_network_notice_label.custom_minimum_size = Vector2(content_width, 28 if tight_portrait else 36)
	if _action_row:
		_action_row.custom_minimum_size = Vector2(content_width, 40 if tight_portrait else 44)
	var action_gap: float = 8.0 if tight_portrait else 12.0
	if _action_row:
		_action_row.add_theme_constant_override("separation", action_gap)
	var action_width: float = floor((content_width - action_gap) * 0.5)
	if _back_button:
		_back_button.custom_minimum_size = Vector2(action_width, 38 if tight_portrait else 42)
	if _start_button:
		_start_button.custom_minimum_size = Vector2(action_width, 38 if tight_portrait else 42)

func _get_layout_viewport_size() -> Vector2:
	var engine_size: Vector2 = get_viewport_rect().size
	return _apply_mobile_safe_layout_reserve(_choose_layout_viewport_size(engine_size, _get_browser_viewport_size()))

func _choose_layout_viewport_size(engine_size: Vector2, browser_size: Vector2i) -> Vector2:
	if browser_size != Vector2i.ZERO and _should_layout_against_browser_size(browser_size):
		return Vector2(browser_size)
	return engine_size

func _get_browser_viewport_size() -> Vector2i:
	if OS.get_name() != "Web":
		return Vector2i.ZERO
	var js_result: Variant = JavaScriptBridge.eval(
		"(function(){var v=window.visualViewport;var w=v?v.width:window.innerWidth;var h=v?v.height:window.innerHeight;return Math.round(w)+'x'+Math.round(h);})()",
		true
	)
	if js_result is String:
		var parts: PackedStringArray = str(js_result).split("x")
		if parts.size() == 2:
			var width: int = int(parts[0])
			var height: int = int(parts[1])
			if width > 0 and height > 0:
				return Vector2i(width, height)
	return Vector2i.ZERO

func _should_layout_against_browser_size(browser_size: Vector2i) -> bool:
	if browser_size.y > browser_size.x:
		return true
	if mini(browser_size.x, browser_size.y) < int(OUTER_PANEL_SIZE.x):
		return true
	return false

func _apply_mobile_safe_layout_reserve(viewport_size: Vector2) -> Vector2:
	if viewport_size.y <= viewport_size.x:
		return viewport_size
	return Vector2(
		maxf(1.0, viewport_size.x - PORTRAIT_WEB_SAFE_SIDE_RESERVE),
		maxf(1.0, viewport_size.y - PORTRAIT_WEB_SAFE_BOTTOM_RESERVE)
	)

func _portrait_single_player_min_content_height(viewport_size: Vector2) -> float:
	var margin: float = 12.0
	var panel_height: float = maxf(1.0, viewport_size.y - (margin * 2.0))
	var tight_portrait: bool = panel_height < 590.0
	var separation: float = 6.0 if _portrait_left_height(viewport_size) < PORTRAIT_TIGHT_HEIGHT else 10.0
	var row_heights: Array[float] = [
		26.0 if tight_portrait else 32.0,
		14.0,
		42.0 if tight_portrait else 48.0,
		20.0 if tight_portrait else 24.0,
		88.0 if tight_portrait else 132.0,
		28.0 if tight_portrait else 40.0,
		0.0,
		40.0 if tight_portrait else 44.0,
	]
	var total: float = 0.0
	for height: float in row_heights:
		total += height
	total += separation * float(row_heights.size() - 1)
	return total

func _portrait_action_row_bottom(viewport_size: Vector2) -> float:
	var margin: float = 12.0
	var left_top: float = _portrait_left_top(viewport_size)
	var left_height: float = _portrait_left_height(viewport_size)
	var row_height: float = 40.0 if left_height < PORTRAIT_TIGHT_HEIGHT else 44.0
	return margin + left_top + left_height - row_height

func _portrait_left_height(viewport_size: Vector2) -> float:
	var margin: float = 12.0
	var panel_size: Vector2 = Vector2(
		maxf(1.0, viewport_size.x - (margin * 2.0)),
		maxf(1.0, viewport_size.y - (margin * 2.0))
	)
	var left_top: float = _portrait_left_top(viewport_size)
	var tight_portrait: bool = panel_size.y < 590.0
	var inset: float = 14.0 if tight_portrait else 18.0
	return maxf(1.0, panel_size.y - left_top - inset)

func _portrait_left_top(viewport_size: Vector2) -> float:
	var margin: float = 12.0
	var panel_size: Vector2 = Vector2(
		maxf(1.0, viewport_size.x - (margin * 2.0)),
		maxf(1.0, viewport_size.y - (margin * 2.0))
	)
	var tight_portrait: bool = panel_size.y < 590.0
	var inset: float = 14.0 if tight_portrait else 18.0
	var splash_min: float = 94.0 if tight_portrait else 130.0
	var splash_max: float = 150.0 if tight_portrait else 190.0
	var splash_height: float = minf(splash_max, maxf(splash_min, panel_size.y * 0.20))
	var gap: float = 8.0 if tight_portrait else 12.0
	return inset + splash_height + gap

func _update_splash_crop() -> void:
	if _bg_sprite == null or _right_panel == null:
		return
	var texture: Texture2D = _bg_sprite.texture
	if texture == null:
		return
	var pane_size: Vector2 = _right_panel.size
	var tex_size: Vector2 = texture.get_size()
	if pane_size.x <= 0.0 or pane_size.y <= 0.0 or tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scale_factor: float = max(pane_size.x / tex_size.x, pane_size.y / tex_size.y)
	var draw_size: Vector2 = tex_size * scale_factor
	_bg_sprite.size = draw_size
	_bg_sprite.position = Vector2(
		floor((pane_size.x - draw_size.x) * 0.5),
		floor((pane_size.y - draw_size.y) * 0.5)
	)

func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _on_lobby_updated() -> void:
	if not _is_online_party_locked():
		return
	_party_size = _get_online_party_size()
	_ensure_party_defaults()
	_update_selection()


func _is_class_unlocked(class_index: int) -> bool:
	if PlayerProfile == null or not PlayerProfile.has_method("is_hero_class_unlocked"):
		return true
	return PlayerProfile.is_hero_class_unlocked(class_index)


func _get_default_selectable_class(fallback_class: int) -> int:
	if _is_class_unlocked(fallback_class):
		return fallback_class
	return ConstantsData.HeroClass.WARRIOR if _is_class_unlocked(ConstantsData.HeroClass.WARRIOR) else 0


func _apply_hero_button_style(btn: Button, is_selected: bool, is_unlocked: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if not is_unlocked:
		style.bg_color = Color(0.08, 0.08, 0.08, 0.72)
		style.border_color = Color(0.24, 0.24, 0.24)
	elif is_selected:
		style.bg_color = Color(0.18, 0.16, 0.14, 0.9)
		style.border_color = GOLD_COLOR
	else:
		style.bg_color = Color(0.12, 0.11, 0.10, 0.85)
		style.border_color = Color(0.3, 0.28, 0.25)
	style.set_border_width_all(2 if is_selected and is_unlocked else 1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override("normal", style)
	btn.modulate = Color(1, 1, 1, 1) if is_unlocked else Color(0.65, 0.65, 0.65, 0.95)


func _apply_party_button_style(btn: Button, is_selected: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if is_selected:
		style.bg_color = Color(0.18, 0.16, 0.14, 0.9)
		style.border_color = GOLD_COLOR
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.12, 0.11, 0.10, 0.9)
		style.border_color = Color(0.35, 0.31, 0.26)
		style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("normal", style)


# ---------------------------------------------------------------------------
# Action Callbacks
# ---------------------------------------------------------------------------

func _on_start_pressed() -> void:
	if not _is_class_unlocked(_selected_class):
		if MessageLog:
			MessageLog.add_warning(PlayerProfile.get_hero_unlock_text(_selected_class))
		return
	var loading_script: GDScript = load("res://src/scenes/loading_scene.gd") as GDScript
	if loading_script == null:
		return
	var chosen_party: Array[int] = []
	for idx: int in range(_party_size):
		chosen_party.append(_party_classes[idx])
	if NetworkManager and NetworkManager.has_method("is_client") and NetworkManager.is_client():
		if MessageLog:
			MessageLog.add_warning("Only the host can start the online run.")
		return
	if NetworkManager and NetworkManager.has_method("is_host") and NetworkManager.is_host():
		var required_party_size: int = _get_online_party_size()
		if chosen_party.size() != required_party_size:
			if MessageLog:
				MessageLog.add_warning("Party loadout no longer matches the connected players. Please try again.")
			_party_size = required_party_size
			_ensure_party_defaults()
			_update_selection()
			return
		var run_seed: int = randi()
		NetworkManager.start_online_run({
			"chosen_class": chosen_party[0],
			"party_classes": chosen_party,
			"run_seed": run_seed,
		})
		return
	SceneManager.go_to(loading_script, "LoadingScene", {
		"chosen_class": chosen_party[0],
		"party_classes": chosen_party,
		"is_continue": false,
	})


func _on_back_pressed() -> void:
	if NetworkManager and NetworkManager.has_method("is_online_session") and NetworkManager.is_online_session():
		NetworkManager.close_session("Left online setup.")
	var title_script: GDScript = preload("res://src/scenes/title_scene.gd")
	SceneManager.go_to(title_script, "TitleScene")

func _apply_network_client_mode() -> void:
	if _start_button:
		_start_button.disabled = true
		_start_button.text = "Waiting..."
	if _back_button:
		_back_button.text = "Leave"

func _on_online_run_start_requested(config: Dictionary) -> void:
	var loading_script: GDScript = load("res://src/scenes/loading_scene.gd") as GDScript
	if loading_script == null:
		return
	SceneManager.go_to(loading_script, "LoadingScene", config)

func _on_network_disconnected(reason: String) -> void:
	if reason != "Disconnected from host.":
		return
	if MessageLog:
		MessageLog.add_warning("Lost connection to host.")
	var title_script: GDScript = preload("res://src/scenes/title_scene.gd")
	SceneManager.go_to(title_script, "TitleScene")
