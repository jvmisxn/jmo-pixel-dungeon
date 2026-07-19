class_name BuffIcon
extends Control
## A small 20x20 icon representing an active buff or debuff.
## Shows a colored circle with the first letter of the buff name.
## Flashes when the buff is about to expire (duration < 3 turns).

## Reference to the buff object (expects buff_name, icon_color, duration/time_left).
var buff_ref: Node = null:
	set(value):
		buff_ref = value
		_update_tooltip()
		queue_redraw()

var _flash_visible: bool = true
var _tooltip_visible: bool = false
var _flash_tween: Tween = null
var _is_flashing: bool = false

const ICON_SIZE: float = 20.0
const FLASH_THRESHOLD: float = 3.0
## Flash cycle: 0.15s visible, 0.10s hidden = 0.25s total cycle (~FLASH_SPEED=4 equivalent)
const FLASH_ON_TIME: float = 0.15
const FLASH_OFF_TIME: float = 0.10


func _ready() -> void:
	custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	size = Vector2(ICON_SIZE, ICON_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = ""


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_tooltip_visible = true
			_update_tooltip()
		NOTIFICATION_MOUSE_EXIT:
			_tooltip_visible = false


## Called externally (e.g. by status_pane) when buff state may have changed.
func update_flash_state() -> void:
	if buff_ref == null:
		_stop_flashing()
		return
	var time_left: float = _get_time_left()
	if time_left > 0.0 and time_left < FLASH_THRESHOLD:
		_start_flashing()
	else:
		_stop_flashing()


func _start_flashing() -> void:
	if _is_flashing:
		return
	_is_flashing = true
	_flash_tween = create_tween()
	_flash_tween.set_loops()
	_flash_tween.tween_callback(_set_flash.bind(true))
	_flash_tween.tween_interval(FLASH_ON_TIME)
	_flash_tween.tween_callback(_set_flash.bind(false))
	_flash_tween.tween_interval(FLASH_OFF_TIME)


func _stop_flashing() -> void:
	if not _is_flashing:
		return
	_is_flashing = false
	if _flash_tween != null:
		_flash_tween.kill()
		_flash_tween = null
	if not _flash_visible:
		_flash_visible = true
		queue_redraw()


func _set_flash(vis: bool) -> void:
	if vis != _flash_visible:
		_flash_visible = vis
		queue_redraw()


func _draw() -> void:
	if buff_ref == null:
		return

	if not _flash_visible:
		return

	var center: Vector2 = size / 2.0
	var color: Color = _get_color()

	# Background circle
	draw_circle(center, ICON_SIZE / 2.0 - 1.0, color * Color(1, 1, 1, 0.85))

	# Border
	draw_arc(center, ICON_SIZE / 2.0 - 1.0, 0.0, TAU, 16, color, 1.5)

	# First letter of buff name
	var letter: String = _get_buff_name().left(1).to_upper()
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 11
	var text_size: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = Vector2(
		center.x - text_size.x / 2.0,
		center.y + font_size * 0.35
	)
	# Shadow
	draw_string(font, text_pos + Vector2(1, 1), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.6))
	# Letter
	draw_string(font, text_pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _update_tooltip() -> void:
	if buff_ref == null:
		tooltip_text = ""
		return
	var name: String = _get_buff_name()
	var time_left: float = _get_time_left()
	if time_left > 0.0:
		tooltip_text = name + " (" + str(int(ceil(time_left))) + " turns)"
	else:
		tooltip_text = name + " (permanent)"


# --- Safe property accessors ---

func _get_buff_name() -> String:
	if buff_ref and "buff_name" in buff_ref:
		return buff_ref.buff_name
	return "?"


func _get_color() -> Color:
	if buff_ref and "icon_color" in buff_ref:
		return buff_ref.icon_color
	return Color.WHITE


func _get_time_left() -> float:
	if buff_ref and "time_left" in buff_ref:
		var tl: float = buff_ref.time_left
		if tl < 0.0:
			return -1.0  # permanent
		return tl
	if buff_ref and "duration" in buff_ref:
		var d: float = buff_ref.duration
		if d < 0.0:
			return -1.0
		return d
	return -1.0
