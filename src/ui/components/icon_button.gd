class_name IconButton
extends Control
## A clickable button that draws a 32x32 procedural icon.
## Supports hover highlight, press animation, and different icon shapes.

@warning_ignore("unused_signal")
signal pressed

## The type of icon to draw. Supported: "inventory", "map", "wait", "search",
## "settings", "close", "back", "info".
@export var icon_type: String = "inventory":
	set(value):
		icon_type = value
		queue_redraw()

## Tint color for the icon graphic.
@export var icon_color: Color = Color.WHITE:
	set(value):
		icon_color = value
		queue_redraw()

## When true, the button cannot be interacted with and renders dimmed.
@export var disabled: bool = false:
	set(value):
		disabled = value
		queue_redraw()

var _hovered: bool = false
var _pressed_visual: bool = false
var _scale_tween: Tween = null
var _draw_scale: float = 1.0

func _ready() -> void:
	custom_minimum_size = Vector2(32, 32)
	size = Vector2(32, 32)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			if not disabled:
				_hovered = true
				queue_redraw()
		NOTIFICATION_MOUSE_EXIT:
			_hovered = false
			_pressed_visual = false
			queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressed_visual = true
				_animate_press(0.85)
				queue_redraw()
			else:
				if _pressed_visual:
					_pressed_visual = false
					_animate_press(1.0)
					queue_redraw()
					pressed.emit()
			accept_event()


func _animate_press(target_scale: float) -> void:
	if _scale_tween:
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "_draw_scale", target_scale, 0.08)
	_scale_tween.tween_callback(queue_redraw)


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var draw_color: Color = icon_color if not disabled else icon_color * Color(0.5, 0.5, 0.5, 0.4)

	# Hover highlight
	if _hovered and not disabled:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.15))

	# Apply scale from center
	draw_set_transform(center, 0.0, Vector2(_draw_scale, _draw_scale))
	var offset: Vector2 = -center  # Draw relative to center

	match icon_type:
		"inventory":
			_draw_inventory(offset, draw_color)
		"map":
			_draw_map(offset, draw_color)
		"wait":
			_draw_wait(offset, draw_color)
		"search":
			_draw_search(offset, draw_color)
		"settings":
			_draw_settings(offset, draw_color)
		"close":
			_draw_close(offset, draw_color)
		"back":
			_draw_back(offset, draw_color)
		"info":
			_draw_info(offset, draw_color)
		_:
			# Fallback: filled circle
			draw_circle(offset + center, 10.0, draw_color)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_inventory(offset: Vector2, color: Color) -> void:
	# Backpack shape: rectangle with flap
	var rect := Rect2(offset + Vector2(6, 10), Vector2(20, 16))
	draw_rect(rect, color, false, 2.0)
	# Flap
	draw_line(offset + Vector2(10, 10), offset + Vector2(10, 6), color, 2.0)
	draw_line(offset + Vector2(22, 10), offset + Vector2(22, 6), color, 2.0)
	draw_line(offset + Vector2(10, 6), offset + Vector2(22, 6), color, 2.0)


func _draw_map(offset: Vector2, color: Color) -> void:
	# Folded map icon
	var points: PackedVector2Array = PackedVector2Array([
		offset + Vector2(6, 6),
		offset + Vector2(13, 9),
		offset + Vector2(19, 6),
		offset + Vector2(26, 9),
		offset + Vector2(26, 26),
		offset + Vector2(19, 23),
		offset + Vector2(13, 26),
		offset + Vector2(6, 23),
	])
	draw_polyline(points, color, 2.0)
	draw_line(points[7], points[0], color, 2.0)
	# Fold lines
	draw_line(offset + Vector2(13, 9), offset + Vector2(13, 26), color, 1.0)
	draw_line(offset + Vector2(19, 6), offset + Vector2(19, 23), color, 1.0)


func _draw_wait(offset: Vector2, color: Color) -> void:
	# Hourglass
	draw_line(offset + Vector2(10, 6), offset + Vector2(22, 6), color, 2.0)
	draw_line(offset + Vector2(10, 26), offset + Vector2(22, 26), color, 2.0)
	# Top triangle
	draw_line(offset + Vector2(10, 6), offset + Vector2(16, 16), color, 2.0)
	draw_line(offset + Vector2(22, 6), offset + Vector2(16, 16), color, 2.0)
	# Bottom triangle
	draw_line(offset + Vector2(10, 26), offset + Vector2(16, 16), color, 2.0)
	draw_line(offset + Vector2(22, 26), offset + Vector2(16, 16), color, 2.0)


func _draw_search(offset: Vector2, color: Color) -> void:
	# Magnifying glass
	var lens_center: Vector2 = offset + Vector2(14, 14)
	draw_arc(lens_center, 7.0, 0.0, TAU, 24, color, 2.0)
	# Handle
	draw_line(offset + Vector2(19, 19), offset + Vector2(26, 26), color, 2.0)


func _draw_settings(offset: Vector2, color: Color) -> void:
	# Gear: circle with notches
	var gear_center: Vector2 = offset + Vector2(16, 16)
	draw_arc(gear_center, 5.0, 0.0, TAU, 24, color, 2.0)
	for i in range(8):
		var angle: float = i * TAU / 8.0
		var inner: Vector2 = gear_center + Vector2(cos(angle), sin(angle)) * 7.0
		var outer: Vector2 = gear_center + Vector2(cos(angle), sin(angle)) * 10.0
		draw_line(inner, outer, color, 2.0)


func _draw_close(offset: Vector2, color: Color) -> void:
	# X shape
	draw_line(offset + Vector2(9, 9), offset + Vector2(23, 23), color, 2.5)
	draw_line(offset + Vector2(23, 9), offset + Vector2(9, 23), color, 2.5)


func _draw_back(offset: Vector2, color: Color) -> void:
	# Left arrow
	draw_line(offset + Vector2(20, 8), offset + Vector2(10, 16), color, 2.0)
	draw_line(offset + Vector2(10, 16), offset + Vector2(20, 24), color, 2.0)
	draw_line(offset + Vector2(10, 16), offset + Vector2(26, 16), color, 2.0)


func _draw_info(offset: Vector2, color: Color) -> void:
	# Circle with "i"
	draw_arc(offset + Vector2(16, 16), 10.0, 0.0, TAU, 24, color, 2.0)
	# Dot
	draw_circle(offset + Vector2(16, 11), 1.5, color)
	# Line
	draw_line(offset + Vector2(16, 14), offset + Vector2(16, 23), color, 2.0)
