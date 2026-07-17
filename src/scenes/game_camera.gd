class_name GameCamera
extends Camera2D
## Smooth-following camera for the dungeon view.
## Follows the hero with configurable smoothing, supports zoom and screen shake.
## Designed for 1280x720 landscape at 16px tile size.

# --- Config ---
## How fast the camera catches up to the target (lower = smoother, higher = snappier).
@export var follow_speed: float = 25.0
## Default zoom level. At 16px tiles, zoom 3.0 shows ~26x15 tiles (good overview).
@export var default_zoom_level: float = 3.0
## Minimum zoom (zoomed out).
@export var min_zoom: float = 1.5
## Maximum zoom (zoomed in).
@export var max_zoom: float = 5.0
## Zoom step per scroll wheel tick.
@export var zoom_step: float = 0.5

# --- State ---
var _target_position: Vector2 = Vector2.ZERO
var _shake_intensity: float = 0.0
var _shake_tween: Tween = null
var _target_zoom: float = 3.0
var _touch_points: Dictionary = {}
var _pinch_start_distance: float = 0.0
var _pinch_start_zoom: float = 3.0
const MOBILE_DEFAULT_ZOOM: float = 4.5
const MOBILE_MAX_ZOOM: float = 10.0
const MOBILE_ZOOM_STEP: float = 0.75

# --- Bounds ---
var _map_bounds: Rect2 = Rect2()
var _has_bounds: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_apply_platform_zoom_limits()
	_target_zoom = default_zoom_level
	zoom = Vector2(_target_zoom, _target_zoom)
	position_smoothing_enabled = false  # We handle smoothing manually

func _process(delta: float) -> void:
	# Smooth follow — lock tightly to hero
	var current: Vector2 = global_position
	var desired: Vector2 = _target_position
	if _has_bounds:
		desired = _clamp_to_bounds(desired)
	# Use min() to cap the lerp factor at 1.0 so we never overshoot
	global_position = current.lerp(desired, minf(follow_speed * delta, 1.0))

	# Smooth zoom
	var current_zoom: float = zoom.x
	if not is_equal_approx(current_zoom, _target_zoom):
		var new_zoom: float = lerpf(current_zoom, _target_zoom, 8.0 * delta)
		zoom = Vector2(new_zoom, new_zoom)

	# Screen shake offset is applied by the shake tween (see shake())
	if _shake_intensity > 0.0:
		offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)

func _unhandled_input(event: InputEvent) -> void:
	# Mouse wheel zoom
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_touch_points[touch.index] = touch.position
		else:
			_touch_points.erase(touch.index)
			_pinch_start_distance = 0.0
		if _touch_points.size() == 2:
			_begin_pinch()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if _touch_points.has(drag.index):
			_touch_points[drag.index] = drag.position
			if _touch_points.size() == 2:
				_update_pinch_zoom()
				get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Set the target the camera should follow (usually hero world position).
## If snap_close is true, immediately move most of the way to reduce visible lag.
func set_target(world_pos: Vector2, snap_close: bool = false) -> void:
	_target_position = world_pos
	if snap_close:
		# Jump 80% of the way immediately for responsive feel
		var desired: Vector2 = world_pos
		if _has_bounds:
			desired = _clamp_to_bounds(desired)
		global_position = global_position.lerp(desired, 0.8)

## Snap immediately to target (no smoothing, used on level load).
func snap_to_target() -> void:
	if _has_bounds:
		global_position = _clamp_to_bounds(_target_position)
	else:
		global_position = _target_position

## Set the map bounds to prevent camera from showing beyond the level.
func set_map_bounds(map_size: Vector2) -> void:
	_map_bounds = Rect2(Vector2.ZERO, map_size)
	_has_bounds = true

## Clear map bounds.
func clear_bounds() -> void:
	_has_bounds = false

## Trigger screen shake.
func shake(intensity: float = 4.0, duration: float = 0.3) -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_intensity = intensity
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "_shake_intensity", 0.0, duration)\
		.set_ease(Tween.EASE_IN)
	_shake_tween.tween_callback(_on_shake_done)

## Zoom in one step.
func zoom_in() -> void:
	_target_zoom = clampf(_target_zoom + zoom_step, min_zoom, max_zoom)

## Zoom out one step.
func zoom_out() -> void:
	_target_zoom = clampf(_target_zoom - zoom_step, min_zoom, max_zoom)

## Set zoom to a specific level.
func set_zoom_level(level: float) -> void:
	_target_zoom = clampf(level, min_zoom, max_zoom)

## Reset zoom to default.
func reset_zoom() -> void:
	_target_zoom = default_zoom_level

## Get the current cell position under the mouse cursor.
## Uses floori() instead of int()/ to correctly handle negative coordinates
## (mouse positions left of or above the map origin).
func get_cell_under_mouse() -> int:
	return get_cell_at_screen_position(get_viewport().get_mouse_position())

## Get the dungeon cell under a viewport/screen position. Touch input uses this
## instead of relying on Godot's synthesized mouse position.
func get_cell_at_screen_position(screen_pos: Vector2) -> int:
	var world_pos: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
	var cell_x: int = floori(world_pos.x / 16.0)
	var cell_y: int = floori(world_pos.y / 16.0)
	if cell_x < 0 or cell_x >= ConstantsData.WIDTH or cell_y < 0 or cell_y >= ConstantsData.HEIGHT:
		return -1
	return ConstantsData.xy_to_pos(cell_x, cell_y)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_shake_done() -> void:
	_shake_intensity = 0.0
	offset = Vector2.ZERO


func _clamp_to_bounds(pos: Vector2) -> Vector2:
	# Always center on the hero — no clamping. The fog of war fills any
	# exposed area beyond the map with black, so there's no visual issue.
	return pos


func _begin_pinch() -> void:
	var positions: Array[Vector2] = _touch_positions()
	if positions.size() != 2:
		return
	_pinch_start_distance = positions[0].distance_to(positions[1])
	_pinch_start_zoom = _target_zoom


func _update_pinch_zoom() -> void:
	if _pinch_start_distance <= 0.0:
		_begin_pinch()
		return
	var positions: Array[Vector2] = _touch_positions()
	if positions.size() != 2:
		return
	var current_distance: float = positions[0].distance_to(positions[1])
	if current_distance <= 0.0:
		return
	var ratio: float = current_distance / _pinch_start_distance
	set_zoom_level(_pinch_start_zoom * ratio)


func _touch_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for value: Variant in _touch_points.values():
		if value is Vector2:
			positions.append(value)
	return positions


func _apply_platform_zoom_limits() -> void:
	if OS.get_name() != "Web" or not DisplayServer.is_touchscreen_available():
		return
	default_zoom_level = maxf(default_zoom_level, MOBILE_DEFAULT_ZOOM)
	max_zoom = maxf(max_zoom, MOBILE_MAX_ZOOM)
	zoom_step = maxf(zoom_step, MOBILE_ZOOM_STEP)
