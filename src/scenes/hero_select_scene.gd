class_name HeroSelectScene
extends Control
## Hero class selection screen using original SPD splash art and assets.
## Shows the selected hero's splash art as background with hero buttons,
## description, and start button — matching the original SPD layout.

# --- State ---
var _selected_class: int = ConstantsData.HeroClass.WARRIOR
var _hero_buttons: Array[Button] = []
var _start_button: Button = null
var _back_button: Button = null
var _hero_name_label: Label = null
var _hero_desc_label: Label = null

# --- Background ---
var _bg_sprite: TextureRect = null
var _fade_overlay: ColorRect = null

# --- Constants ---
const CLASS_COUNT: int = 5
const GOLD_COLOR: Color = Color(1.0, 0.85, 0.3)

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
	_build_ui()
	_update_selection()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				_selected_class = (_selected_class - 1)
				if _selected_class < 0:
					_selected_class = CLASS_COUNT - 1
				_update_selection()
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				_selected_class = (_selected_class + 1) % CLASS_COUNT
				_update_selection()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				_on_start_pressed()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_on_back_pressed()
				get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# --- Background: dark base ---
	var bg_base: ColorRect = ColorRect.new()
	bg_base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_base.color = Color(0.11, 0.12, 0.13)
	add_child(bg_base)

	# --- Splash art background (fills screen, scaled to cover) ---
	_bg_sprite = TextureRect.new()
	_bg_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_sprite)

	# --- Left-side dark fade gradient for readability ---
	_fade_overlay = ColorRect.new()
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)

	# Use a gradient shader for the left-side fade (like original SPD)
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	float fade = smoothstep(0.0, 0.45, UV.x);
	COLOR = vec4(0.0, 0.0, 0.0, 0.75 * (1.0 - fade));
}
"""
	shader_material.shader = shader
	_fade_overlay.material = shader_material

	# --- Left panel container for text and buttons ---
	var left_panel: PanelContainer = PanelContainer.new()
	left_panel.position = Vector2(0, 0)
	left_panel.custom_minimum_size = Vector2(380, 720)
	left_panel.size = Vector2(380, 720)
	var lp_style: StyleBoxFlat = StyleBoxFlat.new()
	lp_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	left_panel.add_theme_stylebox_override("panel", lp_style)
	left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left_panel)

	# --- Title ---
	var title: Label = Label.new()
	title.text = "Choose Your Hero"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GOLD_COLOR)
	title.position = Vector2(40, 40)
	title.custom_minimum_size = Vector2(300, 30)
	add_child(title)

	# --- Hero buttons (icon buttons in a row, like original SPD) ---
	var btn_container: HBoxContainer = HBoxContainer.new()
	btn_container.position = Vector2(40, 85)
	btn_container.custom_minimum_size = Vector2(300, 50)
	btn_container.add_theme_constant_override("separation", 4)
	add_child(btn_container)

	for i: int in range(CLASS_COUNT):
		var btn: Button = _create_hero_button(i)
		btn_container.add_child(btn)
		_hero_buttons.append(btn)

	# --- Hero name ---
	_hero_name_label = Label.new()
	_hero_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_name_label.add_theme_font_size_override("font_size", 16)
	_hero_name_label.add_theme_color_override("font_color", GOLD_COLOR)
	_hero_name_label.position = Vector2(40, 150)
	_hero_name_label.custom_minimum_size = Vector2(300, 24)
	add_child(_hero_name_label)

	# --- Hero description ---
	_hero_desc_label = Label.new()
	_hero_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_desc_label.add_theme_font_size_override("font_size", 12)
	_hero_desc_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.85))
	_hero_desc_label.position = Vector2(30, 180)
	_hero_desc_label.custom_minimum_size = Vector2(320, 120)
	add_child(_hero_desc_label)

	# --- Stats ---
	var stats_label: Label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	stats_label.position = Vector2(40, 310)
	stats_label.custom_minimum_size = Vector2(300, 40)
	add_child(stats_label)

	# --- Action buttons ---
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.position = Vector2(60, 380)
	action_row.custom_minimum_size = Vector2(260, 44)
	action_row.add_theme_constant_override("separation", 20)
	add_child(action_row)

	_start_button = _create_chrome_button("Start")
	_start_button.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	_start_button.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.7))
	_start_button.pressed.connect(_on_start_pressed)
	action_row.add_child(_start_button)

	_back_button = _create_chrome_button("Back")
	_back_button.pressed.connect(_on_back_pressed)
	action_row.add_child(_back_button)


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

# -

