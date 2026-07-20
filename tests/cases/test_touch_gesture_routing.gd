extends RefCounted

class FakeHud:
	extends Node

	var active_window: bool = false
	var tapped_positions: Array[Vector2] = []

	func contains_screen_position(_screen_pos: Vector2) -> bool:
		return true

	func has_active_window() -> bool:
		return active_window

	func handle_screen_tap(screen_pos: Vector2) -> bool:
		tapped_positions.append(screen_pos)
		return false

class FakeCamera:
	extends RefCounted

	var pan_deltas: Array[Vector2] = []
	var touch_events: Array[Dictionary] = []
	var touch_drags: Array[Dictionary] = []
	var active_touch_points: Dictionary = {}
	var reset_count: int = 0

	func get_cell_under_mouse() -> int:
		return 42

	func get_cell_at_screen_position(_screen_pos: Vector2) -> int:
		return 42

	func pan_by_screen_delta(screen_delta: Vector2) -> void:
		pan_deltas.append(screen_delta)

	func handle_touch_event(touch_index: int, screen_pos: Vector2, pressed: bool) -> void:
		touch_events.append({"index": touch_index, "pos": screen_pos, "pressed": pressed})
		if pressed:
			active_touch_points[touch_index] = screen_pos
		else:
			active_touch_points.erase(touch_index)

	func handle_touch_drag(touch_index: int, screen_pos: Vector2) -> bool:
		if not active_touch_points.has(touch_index):
			return false
		active_touch_points[touch_index] = screen_pos
		if active_touch_points.size() != 2:
			return false
		touch_drags.append({"index": touch_index, "pos": screen_pos})
		return true

	func reset_look_offset() -> void:
		reset_count += 1

class ClickSpyScene:
	extends GameScene

	var clicked_cells: Array[int] = []

	func _handle_cell_click(cell: int) -> void:
		clicked_cells.append(cell)

func run(t: Object) -> void:
	var scene := GameScene.new()
	var hud := FakeHud.new()
	scene._hud = hud

	t.check(
		scene._should_route_touch_to_hud(Vector2(12, 12)),
		"first touch over HUD routes to HUD controls"
	)
	scene._active_touch_points[0] = Vector2(160, 360)
	t.check(
		not scene._should_route_touch_to_hud(Vector2(12, 12)),
		"second touch keeps an active gameplay gesture available for camera pinch"
	)
	hud.active_window = true
	t.check(
		scene._should_defer_touch_to_modal_window(),
		"mobile touches defer to modal window controls instead of being swallowed by gameplay"
	)
	scene._suppress_touch_mouse_until_msec = 0
	var modal_touch := InputEventScreenTouch.new()
	modal_touch.pressed = true
	modal_touch.position = Vector2(12, 12)
	scene._input(modal_touch)
	t.check(
		scene._suppress_touch_mouse_until_msec == 0,
		"modal window touches do not arm mouse suppression that starves close/action buttons"
	)

	hud.free()
	scene.free()

	var drift_scene := GameScene.new()
	var drift_hud := FakeHud.new()
	drift_scene._hud = drift_hud
	var hud_down := InputEventScreenTouch.new()
	hud_down.index = 0
	hud_down.pressed = true
	hud_down.position = Vector2(24, 760)
	drift_scene._input(hud_down)
	var hud_drag := InputEventScreenDrag.new()
	hud_drag.index = 0
	hud_drag.position = Vector2(24, 690)
	hud_drag.relative = Vector2(0, -70)
	drift_scene._input(hud_drag)
	var hud_up := InputEventScreenTouch.new()
	hud_up.index = 0
	hud_up.pressed = false
	hud_up.position = Vector2(24, 690)
	drift_scene._input(hud_up)
	t.check(
		drift_hud.tapped_positions == [Vector2(24, 690), Vector2(24, 760)],
		"HUD touch release falls back to the press position when a finger drifts off the control"
	)
	drift_hud.free()
	drift_scene.free()

	var click_scene := ClickSpyScene.new()
	click_scene._awaiting_hero_input = true
	click_scene.game_camera = FakeCamera.new()
	click_scene._suppress_synthesized_touch_mouse()

	var synthetic_click := InputEventMouseButton.new()
	synthetic_click.button_index = MOUSE_BUTTON_LEFT
	synthetic_click.pressed = true
	synthetic_click.position = Vector2(120, 220)
	click_scene._unhandled_input(synthetic_click)
	t.check(
		click_scene.clicked_cells.is_empty(),
		"touch-generated mouse clicks are suppressed in unhandled input"
	)

	click_scene._suppress_touch_mouse_until_msec = 0
	click_scene._unhandled_input(synthetic_click)
	t.check(
		click_scene.clicked_cells == [42],
		"normal mouse clicks still route to the dungeon cell"
	)
	click_scene.free()

	var drag_scene := ClickSpyScene.new()
	var drag_camera := FakeCamera.new()
	drag_scene._awaiting_hero_input = true
	drag_scene.game_camera = drag_camera

	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.pressed = true
	touch_down.position = Vector2(120, 220)
	drag_scene._input(touch_down)

	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 0
	touch_drag.position = Vector2(160, 220)
	touch_drag.relative = Vector2(40, 0)
	drag_scene._input(touch_drag)
	t.check(
		drag_camera.active_touch_points.get(0) == Vector2(160, 220),
		"single-finger look drag keeps camera touch tracking current for a later pinch"
	)

	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 0
	touch_up.pressed = false
	touch_up.position = Vector2(160, 220)
	drag_scene._input(touch_up)
	t.check(
		drag_camera.pan_deltas == [Vector2(40, 0)],
		"single-finger touch drag pans the camera for look-around"
	)
	t.check(
		drag_scene.clicked_cells.is_empty(),
		"single-finger look-around drag does not submit movement on release"
	)

	var tap_down := InputEventScreenTouch.new()
	tap_down.index = 1
	tap_down.pressed = true
	tap_down.position = Vector2(120, 220)
	drag_scene._input(tap_down)
	var tap_up := InputEventScreenTouch.new()
	tap_up.index = 1
	tap_up.pressed = false
	tap_up.position = Vector2(120, 220)
	drag_scene._input(tap_up)
	t.check(
		drag_camera.reset_count == 1,
		"next gameplay tap recenters camera look offset"
	)
	t.check(
		drag_scene.clicked_cells == [42],
		"ordinary touch tap still submits a dungeon cell action"
	)
	drag_scene.free()

	var pinch_scene := ClickSpyScene.new()
	var pinch_camera := FakeCamera.new()
	pinch_scene._awaiting_hero_input = true
	pinch_scene.game_camera = pinch_camera

	var pinch_down_a := InputEventScreenTouch.new()
	pinch_down_a.index = 0
	pinch_down_a.pressed = true
	pinch_down_a.position = Vector2(100, 100)
	pinch_scene._input(pinch_down_a)
	var pinch_down_b := InputEventScreenTouch.new()
	pinch_down_b.index = 1
	pinch_down_b.pressed = true
	pinch_down_b.position = Vector2(200, 100)
	pinch_scene._input(pinch_down_b)

	var pinch_drag := InputEventScreenDrag.new()
	pinch_drag.index = 1
	pinch_drag.position = Vector2(240, 100)
	pinch_drag.relative = Vector2(40, 0)
	pinch_scene._input(pinch_drag)

	var pinch_up_a := InputEventScreenTouch.new()
	pinch_up_a.index = 0
	pinch_up_a.pressed = false
	pinch_up_a.position = Vector2(100, 100)
	pinch_scene._input(pinch_up_a)
	var pinch_up_b := InputEventScreenTouch.new()
	pinch_up_b.index = 1
	pinch_up_b.pressed = false
	pinch_up_b.position = Vector2(240, 100)
	pinch_scene._input(pinch_up_b)
	t.check(
		pinch_camera.touch_events.size() == 4,
		"game scene forwards gameplay touch presses/releases to camera pinch tracking"
	)
	t.check(
		pinch_camera.touch_drags == [{"index": 1, "pos": Vector2(240, 100)}],
		"game scene forwards two-finger drags to camera zoom tracking"
	)
	t.check(
		pinch_camera.pan_deltas.is_empty(),
		"two-finger pinch does not fall through to one-finger look pan"
	)
	t.check(
		pinch_scene.clicked_cells.is_empty(),
		"two-finger pinch does not submit movement on release"
	)
	pinch_scene.free()

	var pinch_lock_scene := ClickSpyScene.new()
	var pinch_lock_camera := FakeCamera.new()
	pinch_lock_scene._awaiting_hero_input = true
	pinch_lock_scene.game_camera = pinch_lock_camera

	var lock_down_a := InputEventScreenTouch.new()
	lock_down_a.index = 0
	lock_down_a.pressed = true
	lock_down_a.position = Vector2(100, 100)
	pinch_lock_scene._input(lock_down_a)
	var lock_down_b := InputEventScreenTouch.new()
	lock_down_b.index = 1
	lock_down_b.pressed = true
	lock_down_b.position = Vector2(200, 100)
	pinch_lock_scene._input(lock_down_b)

	var lock_up_b := InputEventScreenTouch.new()
	lock_up_b.index = 1
	lock_up_b.pressed = false
	lock_up_b.position = Vector2(200, 100)
	pinch_lock_scene._input(lock_up_b)

	var leftover_drag := InputEventScreenDrag.new()
	leftover_drag.index = 0
	leftover_drag.position = Vector2(150, 100)
	leftover_drag.relative = Vector2(50, 0)
	pinch_lock_scene._input(leftover_drag)

	var lock_up_a := InputEventScreenTouch.new()
	lock_up_a.index = 0
	lock_up_a.pressed = false
	lock_up_a.position = Vector2(150, 100)
	pinch_lock_scene._input(lock_up_a)

	t.check(
		pinch_lock_camera.pan_deltas.is_empty(),
		"pinch mode stays locked until all fingers lift instead of becoming look-around"
	)
	t.check(
		pinch_lock_scene.clicked_cells.is_empty(),
		"pinch mode does not become a movement tap after one finger remains"
	)
	pinch_lock_scene.free()
