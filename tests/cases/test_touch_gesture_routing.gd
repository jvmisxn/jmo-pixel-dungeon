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

	func get_cell_under_mouse() -> int:
		return 42

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
