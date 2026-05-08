class_name Toast
extends CanvasLayer
## A popup notification system that slides toasts in from the top, displays
## a message, then fades out. Manages a queue so multiple toasts stack.
##
## Usage: Toast.show_toast("Item picked up!", Color.GREEN, 2.0)
## Requires this to be added as an autoload or instantiated in the scene tree.

const MAX_VISIBLE: int = 5
const TOAST_MARGIN: float = 8.0
const SLIDE_DURATION: float = 0.25
const DEFAULT_DURATION: float = 2.5

## Internal container for active toasts.
var _container: VBoxContainer = null
## Queue of pending toast data.
var _queue: Array[Dictionary] = []
## Currently visible toast count.
var _active_count: int = 0

## Singleton reference for static-style access.
static var instance: Toast = null


func _ready() -> void:
	instance = self
	layer = 100

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_left", 200)
	margin.add_theme_constant_override("margin_right", 200)
	add_child(margin)

	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", int(TOAST_MARGIN))
	_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(_container)


## Show a toast notification. Can be called statically via Toast.instance.show_toast_message().
static func show_toast(text: String, color: Color = Color.WHITE, duration: float = DEFAULT_DURATION) -> void:
	if instance:
		instance.show_toast_message(text, color, duration)


## Instance method to display or queue a toast.
func show_toast_message(text: String, color: Color = Color.WHITE, duration: float = DEFAULT_DURATION) -> void:
	if _active_count >= MAX_VISIBLE:
		_queue.append({"text": text, "color": color, "duration": duration})
		return
	_spawn_toast(text, color, duration)


func _spawn_toast(text: String, color: Color, duration: float) -> void:
	_active_count += 1

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.92)
	style.border_color = color * Color(1, 1, 1, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 13)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)

	_container.add_child(panel)

	# Slide in animation
	panel.modulate = Color(1, 1, 1, 0)
	panel.position.y = -20

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 1), SLIDE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "position:y", 0.0, SLIDE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Wait, then fade out
	var fade_tween: Tween = create_tween()
	fade_tween.tween_interval(duration)
	fade_tween.tween_property(panel, "modulate", Color(1, 1, 1, 0), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	fade_tween.tween_callback(_on_toast_finished.bind(panel))


func _on_toast_finished(panel: PanelContainer) -> void:
	_active_count -= 1
	panel.queue_free()

	# Process queue
	if _queue.size() > 0:
		var next: Dictionary = _queue.pop_front()
		_spawn_toast(next["text"], next["color"], next["duration"])
