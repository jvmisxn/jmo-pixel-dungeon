extends RefCounted

class FakeHud:
	extends Node

	var active_window: bool = false

	func contains_screen_position(_screen_pos: Vector2) -> bool:
		return true

	func has_active_window() -> bool:
		return active_window

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
