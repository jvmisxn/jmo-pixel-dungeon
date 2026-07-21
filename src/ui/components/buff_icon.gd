class_name BuffIcon
extends Control
## A small 20x20 icon representing an active buff or debuff.
## Uses SPD's large_buffs.png atlas when a source icon is known.
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
const BUFFS_PATH: String = "res://assets/spd/interfaces/large_buffs.png"
const ATLAS_ICON_SIZE: int = 16
const ATLAS_COLUMNS: int = 16
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

	var atlas_icon: AtlasTexture = _get_atlas_icon()
	if atlas_icon != null and atlas_icon.atlas != null:
		var dest := Rect2(Vector2.ZERO, size)
		draw_texture_rect_region(atlas_icon.atlas, dest, atlas_icon.region)
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


func _get_atlas_icon() -> AtlasTexture:
	var region: Rect2 = icon_region_for_buff_id(_get_buff_id())
	if region.size == Vector2.ZERO:
		return null
	return UIUtils.atlas_texture(BUFFS_PATH, region)


func _get_buff_id() -> String:
	if buff_ref and "buff_id" in buff_ref:
		return buff_ref.buff_id
	return _get_buff_name().replace(" ", "")


static func icon_region_for_buff_id(buff_id: String) -> Rect2:
	match buff_id:
		"MindVision":
			return _grid_region(0)
		"Levitation":
			return _grid_region(1)
		"Burning", "FireImbue":
			return _grid_region(2)
		"Poison":
			return _grid_region(3)
		"Paralysis":
			return _grid_region(4)
		"Hunger":
			return _grid_region(5)
		"Slow":
			return _grid_region(7)
		"Ooze", "Corrosion":
			return _grid_region(8)
		"Amok":
			return _grid_region(9)
		"Terror", "Dread":
			return _grid_region(10)
		"Rooted":
			return _grid_region(11)
		"Invisibility":
			return _grid_region(12)
		"Weakness":
			return _grid_region(14)
		"Frozen", "Chill", "FrostImbue":
			return _grid_region(15)
		"Blindness":
			return _grid_region(16)
		"Combo":
			return _grid_region(17)
		"Fury":
			return _grid_region(18)
		"SungrassHeal":
			return _grid_region(19)
		"ArcaneArmor", "Barrier":
			return _grid_region(20)
		"Light":
			return _grid_region(22)
		"Cripple":
			return _grid_region(23)
		"Barkskin":
			return _grid_region(24)
		"Bleeding":
			return _grid_region(26)
		"Drowsy":
			return _grid_region(29)
		"Vertigo":
			return _grid_region(33)
		"Recharging":
			return _grid_region(34)
		"Bless":
			return _grid_region(37)
		"Adrenaline", "Haste":
			return _grid_region(41)
		"WellFed":
			return _grid_region(43)
		"Vulnerable":
			return _grid_region(46)
		"Hex":
			return _grid_region(47)
		_:
			return Rect2()


static func _grid_region(index: int) -> Rect2:
	@warning_ignore("integer_division")
	var row: int = index / ATLAS_COLUMNS
	var column: int = index % ATLAS_COLUMNS
	return Rect2(column * ATLAS_ICON_SIZE, row * ATLAS_ICON_SIZE, ATLAS_ICON_SIZE, ATLAS_ICON_SIZE)
