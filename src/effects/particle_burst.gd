class_name ParticleBurst
extends Node2D
## Burst of particles emanating from a point. Used for explosions, potion shatters,
## scroll effects, and other impact visuals. Self-destructs when all particles fade.

const DEFAULT_DURATION: float = 0.6
const DEFAULT_SPEED: float = 60.0

# --- Particle data ---
var _particles: Array[Dictionary] = []
var _timer: float = 0.0
var _duration: float = DEFAULT_DURATION
var _is_ring: bool = false
var _ring_radius: float = 0.0
var _ring_max_radius: float = 48.0
var _ring_color: Color = Color.WHITE

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Set up as a burst of particles.
func setup(color: Color, count: int = 8, speed: float = DEFAULT_SPEED, duration: float = DEFAULT_DURATION) -> void:
	_duration = duration
	for i: int in range(count):
		var angle: float = float(i) / float(count) * TAU + randf_range(-0.2, 0.2)
		var spd: float = speed * randf_range(0.6, 1.4)
		_particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"color": color.lerp(color.lightened(0.3), randf()),
			"size": randf_range(1.0, 2.5),
			"life": 1.0,
		})

## Set up as an expanding ring effect (uses Tween for clean animation).
func setup_ring(color: Color, max_radius: float = 48.0, duration: float = 0.5) -> void:
	_is_ring = true
	_ring_color = color
	_ring_max_radius = max_radius
	_duration = duration
	# Use a Tween to drive ring expansion and fade
	var tween: Tween = create_tween()
	tween.tween_method(_set_ring_progress, 0.0, 1.0, duration)
	tween.tween_callback(queue_free)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _set_ring_progress(progress: float) -> void:
	_ring_radius = _ring_max_radius * progress
	_timer = progress * _duration
	queue_redraw()

func _process(delta: float) -> void:
	# Ring effect is driven by a Tween — skip manual update
	if _is_ring:
		return

	_timer += delta
	var progress: float = _timer / _duration

	# Update particles
	var all_dead: bool = true
	for p: Dictionary in _particles:
		if p["life"] <= 0.0:
			continue
		all_dead = false
		p["pos"] += p["vel"] * delta
		p["vel"] *= 0.92  # drag
		p["life"] -= delta / _duration
		if p["life"] < 0.0:
			p["life"] = 0.0

	if all_dead or progress >= 1.0:
		queue_free()
		return

	queue_redraw()

func _draw() -> void:
	if _is_ring:
		var alpha: float = 1.0 - (_timer / _duration)
		var col: Color = _ring_color
		col.a = alpha * 0.8
		draw_arc(Vector2.ZERO, _ring_radius, 0.0, TAU, 32, col, 2.0)
		return

	# Draw particles
	for p: Dictionary in _particles:
		if p["life"] <= 0.0:
			continue
		var col: Color = p["color"]
		col.a = p["life"]
		draw_circle(p["pos"], p["size"] * p["life"], col)
