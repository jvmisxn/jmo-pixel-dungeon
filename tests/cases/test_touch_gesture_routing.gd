extends RefCounted

class FakeHud:
	extends Node

	var active_window: bool = false

	func contains_screen_position(_screen_pos: Vector2) -> bool:
		return true

	func has_active_window() -> bool:
		return active_window

class FakeCamera:
	extends RefCounted

	var pan_deltas: Array[Vector2] = []
	var reset_count: int = 0

	func get_cell_under_mouse() -> int:
		return 42

	func get_cell_at_screen_position(_screen_pos: Vector2) -> int:
		return 42

	func pan_by_screen_delta(screen_delta: Vector2) -> void:
		pan_deltas.append(screen_delta)

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

	hud.free()
	scene.free()

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
