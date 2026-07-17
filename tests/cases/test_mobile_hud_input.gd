extends RefCounted

class FakeHud:
	extends Node

	func contains_screen_position(_screen_pos: Vector2) -> bool:
		return true

class TestHud:
	extends HUD

	var focused_hero_index: int = -1

	func _on_party_focus_pressed(hero_index: int) -> void:
		focused_hero_index = hero_index

func run(t: Object) -> void:
	var scene := GameScene.new()
	var hud := FakeHud.new()
	scene._hud = hud
	scene._suppress_synthesized_touch_mouse()
	t.check(
		scene._is_screen_position_over_hud(Vector2(12, 12)),
		"fake HUD covers test position"
	)
	t.check(
		scene._should_suppress_synthesized_touch_mouse_event(Vector2(12, 12)),
		"synthetic mouse events are suppressed even over HUD controls"
	)
	hud.free()
	scene.free()

	var test_hud := TestHud.new()
	var party_row := HBoxContainer.new()
	party_row.visible = true
	party_row.position = Vector2(10, 20)
	party_row.size = Vector2(120, 40)
	var party_button := Button.new()
	party_button.visible = true
	party_button.position = Vector2.ZERO
	party_button.size = Vector2(80, 30)
	party_button.set_meta("hero_index", 1)
	party_row.add_child(party_button)
	test_hud._party_row = party_row
	test_hud.add_child(party_row)

	t.check(
		test_hud.handle_screen_tap(Vector2(20, 30)),
		"HUD touch release activates party row buttons"
	)
	t.check(
		test_hud.focused_hero_index == 1,
		"party row touch focuses the tapped hero index"
	)
	test_hud.free()
