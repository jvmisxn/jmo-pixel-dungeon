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
var _close_touch_index: int = -1

# --- Animation ---
const ANIM_DURATION: float = 0.2
const VIEWPORT_MARGIN: Vector2 = Vector2(24, 24)
const MIN_WINDOW_SIZE: Vector2 = Vector2(260, 180)


func _ready() -> void:
	_setup_overlay()
	_setup_window()
	call_deferred("_fit_and_center_window")
	var vp: Viewport = get_viewport()
	if vp and not vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.connect(_on_viewport_resized)
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
	set_anchors_preset(Control.PRESET_TOP_LEFT)
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
	_close_button.gui_input.connect(_on_close_button_gui_input)
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
	call_deferred("_fit_and_center_window")


## Override in subclass to provide window content.
func _build_content() -> Control:
	return null


## Rebuild the subclass-owned content area without recreating the window shell.
func refresh_content() -> void:
	if _content_container == null:
		return
	while _content_container.get_child_count() > 2:
		var child: Node = _content_container.get_child(2)
		_content_container.remove_child(child)
		child.queue_free()
	var content: Control = _build_content()
	if content:
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content_container.add_child(content)


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

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.14, 0.12, 0.9)
	normal_style.border_color = Color(0.4, 0.36, 0.30)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(2)
	normal_style.content_margin_left = 12.0
	normal_style.content_margin_right = 12.0
	normal_style.content_margin_top = 6.0
	normal_style.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.22, 0.20, 0.16, 0.95)
	hover_style.border_color = Color(0.55, 0.50, 0.40)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.10, 0.09, 0.07)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn


# --- Close / Escape / Drag ---

func _on_close_pressed() -> void:
	close_window()


func _on_close_button_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_close_touch_index = touch.index
			_close_button.button_pressed = true
			_close_button.accept_event()
		elif _close_touch_index == touch.index:
			_close_touch_index = -1
			_close_button.button_pressed = false
			_close_button.accept_event()
			if Rect2(Vector2.ZERO, _close_button.size).has_point(touch.position):
				close_window()


## Close this window with animation. Removes overlay and frees self.
func close_window() -> void:
	if _is_closing:
		return
	_is_closing = true
	_on_close()
	window_closed.emit()
	_play_close_animation()


func _play_open_animation() -> void:
	modulate = Color(1, 1, 1, 0)
	scale = Vector2(0.8, 0.8)
	pivot_offset = size * 0.5
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "modulate", Color(1, 1, 1, 1), ANIM_DURATION)
	tw.tween_property(self, "scale", Vector2.ONE, ANIM_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if _background_overlay:
		_background_overlay.modulate = Color(1, 1, 1, 0)
		tw.tween_property(_background_overlay, "modulate", Color.WHITE, ANIM_DURATION)


func _play_close_animation() -> void:
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), ANIM_DURATION)
	tw.tween_property(self, "scale", Vector2(0.8, 0.8), ANIM_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	if _background_overlay:
		tw.tween_property(_background_overlay, "modulate", Color(1, 1, 1, 0), ANIM_DURATION)
	tw.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	if _background_overlay and is_instance_valid(_background_overlay):
		_background_overlay.queue_free()
		_background_overlay = null
	var vp: Viewport = get_viewport()
	if vp and vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.disconnect(_on_viewport_resized)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if close_on_escape and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			close_window()
			get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not allow_drag:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_offset = event.position
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		position += event.position - _drag_offset


func _on_viewport_resized() -> void:
	_fit_and_center_window()


func _fit_and_center_window() -> void:
	var parent_control: Control = get_parent() as Control
	if parent_control == null:
		return
	var available_size: Vector2 = parent_control.size - (VIEWPORT_MARGIN * 2.0)
	available_size.x = max(available_size.x, MIN_WINDOW_SIZE.x)
	available_size.y = max(available_size.y, MIN_WINDOW_SIZE.y)

	var target_size: Vector2 = custom_minimum_size
	if target_size.x <= 0.0:
		target_size.x = size.x
	if target_size.y <= 0.0:
		target_size.y = size.y
	target_size.x = clampf(target_size.x, MIN_WINDOW_SIZE.x, available_size.x)
	target_size.y = clampf(target_size.y, MIN_WINDOW_SIZE.y, available_size.y)
	size = target_size
	custom_minimum_size = target_size
	var centered_pos: Vector2 = (parent_control.size - size) * 0.5
	position = Vector2(maxf(0.0, centered_pos.x), maxf(0.0, centered_pos.y))
	pivot_offset = size * 0.5
