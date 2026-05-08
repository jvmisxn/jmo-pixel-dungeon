class_name ProjectileEffect
extends Node2D
## A simple projectile that travels from point A to point B and self-destructs.
## Used for wand bolts, thrown weapons, ranged attacks.

const TRAIL_LENGTH: int = 3

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _color: Color = Color.WHITE
var _speed: float = 300.0
var _progress: float = 0.0
var _distance: float = 0.0
var _direction: Vector2 = Vector2.ZERO
var _trail: Array[Vector2] = []
var _finished: bool = false

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(from: Vector2, to: Vector2, color: Color = Color.WHITE, speed: float = 300.0) -> void:
	_from = from
	_to = to
	_color = color
	_speed = speed
	_distance = from.distance_to(to)
	_direction = (to - from).normalized()
	position = from

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _finished:
		return

	_progress += _speed * delta
	var t: float = _progress / _distance if _distance > 0.0 else 1.0

	# Store trail positions
	_trail.append(position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.pop_front()

	# Move
	position = _from.lerp(_to, minf(t, 1.0))

	# Arrived
	if t >= 1.0:
		_finished = true
		# Brief flash at impact point
		var tween: Tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.1)
		tween.tween_callback(queue_free)

	queue_redraw()

func _draw() -> void:
	# Draw projectile dot
	draw_circle(Vector2.ZERO, 2.0, _color)
	# Draw trail
	for i: int in range(_trail.size()):
		var trail_pos: Vector2 = _trail[i] - position
		var alpha: float = float(i) / float(TRAIL_LENGTH)
		var trail_color: Color = _color
		trail_color.a = alpha * 0.5
		draw_circle(trail_pos, 1.5 * alpha, trail_color)
