class_name TrapSprite
extends Node2D
## Procedural sprite for revealed traps so they read as hazards instead of
## plain floor. Colors and glyph shapes mirror upstream TrapSprite.java
## (levels/traps/*.java `color`/`shape` assignments); the port draws the
## shapes procedurally instead of using the upstream traps tilesheet.

const CELL_SIZE: float = TileMapManager.TILE_SIZE

enum Shape { DOTS, WAVES, GRILL, STARS, DIAMOND, CROSSHAIR, LARGE_DOT }

## Upstream TrapSprite tint palette (RED/ORANGE/YELLOW/GREEN/TEAL/VIOLET/
## WHITE/GREY/BLACK), approximated as RGB.
const COLOR_RED: Color = Color(0.85, 0.2, 0.16)
const COLOR_ORANGE: Color = Color(0.92, 0.56, 0.16)
const COLOR_YELLOW: Color = Color(0.92, 0.86, 0.22)
const COLOR_GREEN: Color = Color(0.28, 0.72, 0.26)
const COLOR_TEAL: Color = Color(0.2, 0.76, 0.76)
const COLOR_VIOLET: Color = Color(0.62, 0.32, 0.86)
const COLOR_WHITE: Color = Color(0.95, 0.95, 0.95)
const COLOR_GREY: Color = Color(0.62, 0.62, 0.62)

## Per-trap color/shape keyed by `trap_name`, matching current upstream
## assignments (2026-07-27 source check). Port-only or classic-adapted traps
## (`explosive trap`, `paralytic gas trap`) use adapted picks that stay
## distinct from their nearest upstream neighbors.
const TRAP_STYLES: Dictionary = {
	"alarm trap": [COLOR_RED, Shape.DOTS],
	"blazing trap": [COLOR_ORANGE, Shape.STARS],
	"chilling trap": [COLOR_WHITE, Shape.DOTS],
	"confusion gas trap": [COLOR_TEAL, Shape.GRILL],
	"corrosion trap": [COLOR_GREY, Shape.GRILL],
	"cursing trap": [COLOR_VIOLET, Shape.WAVES],
	"disarming trap": [COLOR_RED, Shape.LARGE_DOT],
	"disintegration trap": [COLOR_VIOLET, Shape.CROSSHAIR],
	"distortion trap": [COLOR_TEAL, Shape.LARGE_DOT],
	"explosive trap": [COLOR_ORANGE, Shape.DIAMOND],
	"fire trap": [COLOR_ORANGE, Shape.DOTS],
	"flashing trap": [COLOR_GREY, Shape.STARS],
	"flock trap": [COLOR_WHITE, Shape.WAVES],
	"frost trap": [COLOR_WHITE, Shape.STARS],
	"gateway trap": [COLOR_TEAL, Shape.CROSSHAIR],
	"geyser trap": [COLOR_TEAL, Shape.DIAMOND],
	"grim trap": [COLOR_GREY, Shape.LARGE_DOT],
	"gripping trap": [COLOR_GREY, Shape.DOTS],
	"guardian trap": [COLOR_RED, Shape.STARS],
	"ooze trap": [COLOR_GREEN, Shape.DOTS],
	"paralytic gas trap": [COLOR_YELLOW, Shape.GRILL],
	"pitfall trap": [COLOR_RED, Shape.DIAMOND],
	"poison dart trap": [COLOR_GREEN, Shape.CROSSHAIR],
	"rockfall trap": [COLOR_GREY, Shape.DIAMOND],
	"shocking trap": [COLOR_YELLOW, Shape.DOTS],
	"storm trap": [COLOR_YELLOW, Shape.STARS],
	"summoning trap": [COLOR_TEAL, Shape.WAVES],
	"teleportation trap": [COLOR_TEAL, Shape.DOTS],
	"toxic gas trap": [COLOR_GREEN, Shape.GRILL],
	"warping trap": [COLOR_TEAL, Shape.STARS],
	"weakening trap": [COLOR_GREEN, Shape.WAVES],
	"worn dart trap": [COLOR_GREY, Shape.CROSSHAIR],
}

var cell_pos: int = -1
var trap_key: String = ""
var trap_active: bool = true

var _color: Color = COLOR_RED
var _shape: int = Shape.DOTS


func setup_for_trap(trap_name: String, active: bool = true) -> void:
	trap_key = trap_name.to_lower()
	trap_active = active
	var style: Variant = TRAP_STYLES.get(trap_key)
	if style is Array and (style as Array).size() == 2:
		_color = style[0]
		_shape = int(style[1])
	else:
		_color = COLOR_RED
		_shape = Shape.DOTS
	queue_redraw()


func set_trap_state(active: bool) -> void:
	if trap_active == active:
		return
	trap_active = active
	queue_redraw()


func place_at(pos: int) -> void:
	cell_pos = pos
	var x: int = pos % ConstantsData.WIDTH
	@warning_ignore("integer_division")
	var y: int = pos / ConstantsData.WIDTH
	global_position = Vector2(x * CELL_SIZE + CELL_SIZE * 0.5, y * CELL_SIZE + CELL_SIZE * 0.5)


func set_visible_state(is_visible_now: bool) -> void:
	visible = is_visible_now


func _draw() -> void:
	# Triggered one-shot traps stay drawn but grey out (upstream inactive tile).
	var col: Color = _color if trap_active else COLOR_GREY
	if not trap_active:
		col.a = 0.45
	var plate: Color = Color(0.1, 0.1, 0.1, 0.35)
	draw_rect(Rect2(Vector2(-6, -6), Vector2(12, 12)), plate)
	match _shape:
		Shape.DOTS:
			for offset: Vector2 in [Vector2(-3, -3), Vector2(3, -3), Vector2(0, 0), Vector2(-3, 3), Vector2(3, 3)]:
				draw_circle(offset, 1.3, col)
		Shape.WAVES:
			for row: int in [-3, 0, 3]:
				var y: float = float(row)
				draw_line(Vector2(-5, y), Vector2(-2, y - 1.5), col, 1.2)
				draw_line(Vector2(-2, y - 1.5), Vector2(2, y + 1.5), col, 1.2)
				draw_line(Vector2(2, y + 1.5), Vector2(5, y), col, 1.2)
		Shape.GRILL:
			for offset: int in [-4, -1, 2, 5]:
				var x: float = float(offset)
				draw_line(Vector2(x, -5), Vector2(x, 5), col, 1.3)
		Shape.STARS:
			for offset: Vector2 in [Vector2(-3, -3), Vector2(3, -2), Vector2(0, 3)]:
				draw_line(offset + Vector2(-2, 0), offset + Vector2(2, 0), col, 1.1)
				draw_line(offset + Vector2(0, -2), offset + Vector2(0, 2), col, 1.1)
		Shape.DIAMOND:
			var points: PackedVector2Array = PackedVector2Array([
				Vector2(0, -5), Vector2(5, 0), Vector2(0, 5), Vector2(-5, 0)])
			draw_colored_polygon(points, col)
		Shape.CROSSHAIR:
			draw_arc(Vector2.ZERO, 4.0, 0.0, TAU, 20, col, 1.2)
			draw_line(Vector2(0, -5.5), Vector2(0, 5.5), col, 1.2)
			draw_line(Vector2(-5.5, 0), Vector2(5.5, 0), col, 1.2)
		Shape.LARGE_DOT:
			draw_circle(Vector2.ZERO, 3.6, col)
