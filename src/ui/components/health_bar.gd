class_name HealthBar
extends Control
## A horizontal bar that displays current/maximum values with smooth tweening.
## Usable for HP, XP, or any numeric progress via the bar_color property.

## Current value displayed.
@export var current: int = 10:
	set(value):
		var old: int = current
		current = value
		if old != value:
			_tween_to_value()

## Maximum value (determines fill ratio).
@export var maximum: int = 10:
	set(value):
		maximum = maxi(value, 1)
		queue_redraw()

## Whether to show "current/max" text overlay.
@export var show_text: bool = true

## Override bar color. If Color(0,0,0,0) (default), uses automatic HP coloring.
@export var bar_color: Color = Color(0, 0, 0, 0)

## Height of the bar in pixels.
@export var bar_height: float = 14.0

const BG_COLOR := Color(0.1, 0.1, 0.12, 0.9)
const BORDER_COLOR := Color(0.3, 0.3, 0.35, 0.8)

var _display_ratio: float = 1.0
var _tween: Tween = null


func _ready() -> void:
	custom_minimum_size = Vector2(80, bar_height)
	_display_ratio = _target_ratio()


func _target_ratio() -> float:
	if maximum <= 0:
		return 0.0
	return clampf(float(current) / float(maximum), 0.0, 1.0)


func _tween_to_value() -> void:
	var target: float = _target_ratio()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_display_ratio", target, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_callback(queue_redraw)
	# Also redraw during tween
	_tween.parallel().tween_callback(queue_redraw).set_delay(0.0)
	queue_redraw()


func _process(_delta: float) -> void:
	# Continuous redraw during tween
	if _tween and _tween.is_running():
		queue_redraw()


func _draw() -> void:
	var rect_size: Vector2 = size
	var bar_rect := Rect2(Vector2.ZERO, rect_size)

	# Background
	draw_rect(bar_rect, BG_COLOR)

	# Fill
	var fill_width: float = rect_size.x * _display_ratio
	if fill_width > 0:
		var fill_rect := Rect2(Vector2.ZERO, Vector2(fill_width, rect_size.y))
		draw_rect(fill_rect, _get_fill_color())

	# Border
	draw_rect(bar_rect, BORDER_COLOR, false, 1.0)

	# Text overlay
	if show_text:
		var text: String = str(current) + "/" + str(maximum)
		var font: Font = ThemeDB.fallback_font
		var font_size: int = int(rect_size.y - 3)
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos: Vector2 = Vector2(
			(rect_size.x - text_size.x) / 2.0,
			(rect_size.y + font_size * 0.65) / 2.0
		)
		# Shadow
		draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.7))
		# Text
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _get_fill_color() -> Color:
	# If a custom bar_color is set (non-transparent), use it
	if bar_color.a > 0.01:
		return bar_color

	# Automatic HP coloring based on percentage
	var pct: float = _display_ratio
	if pct > 0.6:
		return Color(0.2, 0.8, 0.2)  # Green
	elif pct > 0.3:
		return Color(0.9, 0.8, 0.1)  # Yellow
	else:
		return Color(0.9, 0.15, 0.15)  # Red
