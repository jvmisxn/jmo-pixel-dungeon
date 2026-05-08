class_name WndBase
extends PanelContainer
## Base window class for all popup windows in the game.
## Provides: dark background overlay, title bar with close button, dragging,
## modal input blocking, Escape to close, open/close animations.

@warning_ignore("unused_signal")
signal window_closed
## Emitted when this window wants to open a sub-window.
## Parent (HUD) listens for this and calls show_window() — avoids get_parent().
@warning_ignore("unused_signal")
signal open_sub_window(wnd: WndBase)

# --- Configuration ---
@export var window_title: String = ""
@export var allow_drag: bool = true
@export var close_on_escape: bool = true

# --- Internal ---
var _title_label: Label = null
var _close_button: Button = null
var _title_bar: HBoxContainer = null
var _content_container: VBoxContainer = null
var _background_overlay: ColorRect = null
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _is_closing: bool = false

# --- Animation ---
const ANIM_DURATION: float = 0.2


func _ready() -> void:
	_setup_overlay()
	_setup_window()
	_play_open_animation()


func _setup_overlay() -> void:
	# Create a full-screen dark overlay behind the window.
	# Must be added BEFORE the window in the parent's child list so it renders
	# below the window and doesn't block input to the window panel.
	_background_overlay = ColorRect.new()
	_background_overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	_background_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Defer: add overlay then move it before this window in the draw order
	call_deferred("_insert_overlay_behind")


func _insert_overlay_behind() -> void:
	var parent_node: Node = get_parent()
	if parent_node and _background_overlay:
		var my_idx: int = get_index()
		parent_node.add_child(_background_overlay)
		parent_node.move_child(_background_overlay, my_idx)

func _setup_window() -> void:
	# SPD chrome-style panel: dark stone background with warm border
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(300, 200)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.09, 0.08, 0.97)
	panel_style.border_color = Color(0.5, 0.45, 0.35)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(3)
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", panel_style)

	# Main vertical layout
	_content_container = VBoxContainer.new()
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_theme_constant_override("separation", 8)
	add_child(_content_container)

	# Title bar
	_title_bar = HBoxContainer.new()
	_title_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.add_child(_title_bar)

	_title_label = Label.new()
	_title_label.text = window_title
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_title_bar.add_child(_title_label)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(28, 28)
	_close_button.add_theme_font_size_override("font_size", 14)
	_close_button.add_theme_color_override("font_color", Color(0.9, 0.6, 0.5))
	_close_button.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.3))
	# SPD close button style
	var close_normal := StyleBoxFlat.new()
	close_normal.bg_color = Color(0.15, 0.12, 0.1)
	close_normal.border_color = Color(0.5, 0.35, 0.3)
	close_normal.set_border_width_all(1)
	close_normal.set_corner_radius_all(2)
	_close_button.add_theme_stylebox_override("normal", close_normal)
	var close_hover := StyleBoxFlat.new()
	close_hover.bg_color = Color(0.25, 0.15, 0.12)
	close_hover.border_color = Color(0.7, 0.4, 0.3)
	close_hover.set_border_width_all(1)
	close_hover.set_corner_radius_all(2)
	_close_button.add_theme_stylebox_override("hover", close_hover)
	_close_button.pressed.connect(_on_close_pressed)
	_title_bar.add_child(_close_button)

	# Separator with warm stone color
	var sep: HSeparator = HSeparator.new()
	sep.modulate = Color(0.6, 0.5, 0.4)
	_content_container.add_child(sep)

	# Build subclass content
	var content: Control = _build_content()
	if content:
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content_container.add_child(content)


## Override in subclass to provide window content.
func _build_content() -> Control:
	return null


## Override in subclass for close cleanup.
func _on_close() -> void:
	pass


## Create an SPD-styled button for use in window content.
## Matches the stone/chrome aesthetic used throughout the game.
static func create_spd_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 36)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.65, 0.5))
	return btn
