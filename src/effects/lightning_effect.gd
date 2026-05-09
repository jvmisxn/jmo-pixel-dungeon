class_name LightningEffect
extends Node2D
## Jagged lightning bolt between two points. Generates randomized segments
## and flashes briefly before self-destructing.

const SEGMENT_LENGTH: float = 8.0
const JITTER: float = 6.0
const DURATION: float = 0.3
const FLASH_COUNT: int = 2

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _color: Color = Color(0.7, 0.8, 1.0)
var _segments: Array[Vector2] = []
var _progress: float = 0.0
var _visible_state: bool = true

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(from: Vector2, to: Vector2, color: Color = Color(0.7, 0.8, 1.0)) -> void:
	_from = from
	_to = to
	_color = color
	# Position at midpoint for drawing
	position = (from + to) * 0.5
	_generate_segments()

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	z_index = 60
	_start_animation()


func _start_animation() -> void:
	# Main progress tween drives alpha fade via _progress
	var tween: Tween = create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, DURATION)
	tween.tween_callback(queue_free)

	# Flash timer toggles visibility at regular intervals
	var flash_interval: float = DURATION / float(FLASH_COUNT * 2)
	var flash_tween: Tween = create_tween()
	flash_tween.set_loops(FLASH_COUNT * 2)
	flash_tween.tween_callback(_toggle_flash).set_delay(flash_interval)


func _set_progress(p: float) -> void:
	_progress = p
	queue_redraw()


func _toggle_flash() -> void:
	_visible_state = not _visible_state
	if _visible_state:
		_generate_segments()
	queue_redraw()

func _draw() -> void:
	if not _visible_state:
		return

	var alpha: float = 1.0 - _progress
	var col: Color = _color
	col.a = alpha

	# Draw main bolt
	for i: int in range(_segments.size() - 1):
		var a: Vector2 = _segments[i] - position
		var b: Vector2 = _segments[i + 1] - position
		draw_line(a, b, col, 2.0)
		# Glow (wider, more transparent)
		var glow_col: Color = col
		glow_col.a = alpha * 0.3
		draw_line(a, b, glow_col, 4.0)

	# Branch bolts (smaller)
	if _segments.size() > 4:
		@warning_ignore("integer_division")
		var branch_start: int = _segments.size() / 3
		var branch_dir: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var branch_a: Vector2 = _segments[branch_start] - position
		var branch_b: Vector2 = branch_a + branch_dir * SEGMENT_LENGTH * 2.0
		var branch_col: Color = col
		branch_col.a = alpha * 0.5
		draw_line(branch_a, branch_b, branch_col, 1.0)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _generate_segments() -> void:
	_segments.clear()
	_segments.append(_from)

	var dist: float = _from.distance_to(_to)
	var dir: Vector2 = (_to - _from).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var seg_count: int = maxi(int(dist / SEGMENT_LENGTH), 2)

	for i: int in range(1, seg_count):
		var t: float = float(i) / float(seg_count)
		var base_pos: Vector2 = _from.lerp(_to, t)
		var jitter_amount: float = randf_range(-JITTER, JITTER)
		# Less jitter near endpoints
		var edge_factor: float = 1.0 - absf(t - 0.5) * 2.0
		base_pos += perp * jitter_amount * edge_factor
		_segments.append(base_pos)

	_segments.append(_to)
