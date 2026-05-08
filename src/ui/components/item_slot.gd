class_name ItemSlot
extends Control
## Represents a single inventory slot (40x40) that can hold an item reference.
## Draws item icons procedurally based on category, with indicators for quantity,
## level, cursed status, and selection state.

@warning_ignore("unused_signal")
signal slot_clicked(item: RefCounted)
@warning_ignore("unused_signal")
signal slot_right_clicked(item: RefCounted)

## The item currently held in this slot (null = empty).
var item: RefCounted = null:
	set(value):
		item = value
		queue_redraw()

## Whether this slot is currently selected.
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _hovered: bool = false

const SLOT_SIZE: float = 40.0
const ICON_SIZE: float = 24.0
const BG_COLOR := Color(0.12, 0.12, 0.15, 0.9)
const EMPTY_BORDER_COLOR := Color(0.3, 0.3, 0.35, 0.5)
const SELECTED_BORDER_COLOR := Color(1.0, 0.84, 0.0, 1.0)
const CURSED_BORDER_COLOR := Color(0.9, 0.1, 0.1, 1.0)
const HOVER_OVERLAY := Color(1, 1, 1, 0.1)


func _ready() -> void:
	custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	size = Vector2(SLOT_SIZE, SLOT_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_hovered = true
			queue_redraw()
		NOTIFICATION_MOUSE_EXIT:
			_hovered = false
			queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				slot_clicked.emit(item)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				slot_right_clicked.emit(item)
				accept_event()


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, Vector2(SLOT_SIZE, SLOT_SIZE)), BG_COLOR)

	# Border
	var border_color: Color
	if selected:
		border_color = SELECTED_BORDER_COLOR
	elif item and _is_cursed():
		border_color = CURSED_BORDER_COLOR
	else:
		border_color = EMPTY_BORDER_COLOR

	var border_width: float = 2.0 if (selected or (item and _is_cursed())) else 1.0
	draw_rect(Rect2(Vector2.ONE, Vector2(SLOT_SIZE - 2, SLOT_SIZE - 2)), border_color, false, border_width)

	# Hover overlay
	if _hovered:
		draw_rect(Rect2(Vector2.ZERO, Vector2(SLOT_SIZE, SLOT_SIZE)), HOVER_OVERLAY)

	if item == null:
		return

	# Draw item icon
	var icon_offset: Vector2 = Vector2((SLOT_SIZE - ICON_SIZE) / 2.0, (SLOT_SIZE - ICON_SIZE) / 2.0)
	var color: Color = _get_item_color()
	_draw_item_icon(icon_offset, color)

	# Quantity badge (top-right)
	if _is_stackable() and _get_quantity() > 1:
		var qty_text: String = str(_get_quantity())
		draw_string(ThemeDB.fallback_font, Vector2(SLOT_SIZE - 6 * qty_text.length(), 12),
			qty_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 9, Color.WHITE)

	# Level indicator (bottom-left)
	var lvl: int = _get_level()
	if lvl > 0:
		var lvl_text: String = "+" + str(lvl)
		draw_string(ThemeDB.fallback_font, Vector2(3, SLOT_SIZE - 4),
			lvl_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 1.0, 0.4))


func _draw_item_icon(offset: Vector2, color: Color) -> void:
	var center: Vector2 = offset + Vector2(ICON_SIZE / 2.0, ICON_SIZE / 2.0)
	var category: int = _get_category()

	match category:
		ConstantsData.ItemCategory.WEAPON:
			# Sword shape
			draw_line(center + Vector2(-6, 6), center + Vector2(6, -6), color, 2.5)
			draw_line(center + Vector2(-3, -1), center + Vector2(3, 1), color, 2.0)
		ConstantsData.ItemCategory.ARMOR:
			# Shield shape
			var points: PackedVector2Array = PackedVector2Array([
				center + Vector2(0, -8),
				center + Vector2(8, -4),
				center + Vector2(8, 2),
				center + Vector2(0, 9),
				center + Vector2(-8, 2),
				center + Vector2(-8, -4),
			])
			draw_colored_polygon(points, color * Color(1, 1, 1, 0.7))
			draw_polyline(points + PackedVector2Array([points[0]]), color, 1.5)
		ConstantsData.ItemCategory.WAND:
			# Diagonal stick with star tip
			draw_line(center + Vector2(-6, 6), center + Vector2(4, -4), color, 2.0)
			draw_circle(center + Vector2(5, -5), 3.0, color)
		ConstantsData.ItemCategory.RING:
			# Circle
			draw_arc(center, 6.0, 0.0, TAU, 20, color, 2.0)
			draw_circle(center + Vector2(0, -6), 2.5, color)
		ConstantsData.ItemCategory.ARTIFACT:
			# Diamond
			var diamond: PackedVector2Array = PackedVector2Array([
				center + Vector2(0, -9),
				center + Vector2(8, 0),
				center + Vector2(0, 9),
				center + Vector2(-8, 0),
			])
			draw_colored_polygon(diamond, color * Color(1, 1, 1, 0.6))
			draw_polyline(diamond + PackedVector2Array([diamond[0]]), color, 1.5)
		ConstantsData.ItemCategory.POTION:
			# Round bottle
			draw_arc(center + Vector2(0, 2), 6.0, 0.0, TAU, 16, color, 2.0)
			draw_rect(Rect2(center + Vector2(-2, -8), Vector2(4, 6)), color, false, 1.5)
		ConstantsData.ItemCategory.SCROLL:
			# Rolled scroll
			draw_rect(Rect2(center + Vector2(-6, -5), Vector2(12, 10)), color, false, 1.5)
			draw_line(center + Vector2(-6, -5), center + Vector2(-6, 5), color, 2.5)
			draw_line(center + Vector2(6, -5), center + Vector2(6, 5), color, 2.5)
		ConstantsData.ItemCategory.FOOD:
			# Drumstick shape
			draw_circle(center + Vector2(3, -2), 5.0, color)
			draw_line(center + Vector2(-1, 2), center + Vector2(-7, 8), color, 2.5)
		ConstantsData.ItemCategory.GOLD:
			# Coin
			draw_circle(center, 7.0, color)
			draw_circle(center, 4.0, color * Color(0.7, 0.7, 0.7, 1.0))
		_:
			# Generic: filled square
			draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), color, true)


# --- Item property accessors (safe access via duck-typing) ---

func _get_item_color() -> Color:
	if item and "icon_color" in item:
		return item.icon_color
	return Color.WHITE


func _get_category() -> int:
	if item and "category" in item:
		return item.category
	return ConstantsData.ItemCategory.MISC


func _is_stackable() -> bool:
	if item and "stackable" in item:
		return item.stackable
	return false


func _get_quantity() -> int:
	if item and "quantity" in item:
		return item.quantity
	return 1


func _get_level() -> int:
	if item and "level" in item:
		return item.level
	return 0


func _is_cursed() -> bool:
	if item and "cursed" in item:
		return item.cursed
	return false
