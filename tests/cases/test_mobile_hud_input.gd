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

class LayoutHud:
	extends HUD

	var fake_safe_bottom: float = 0.0

	class StubComponent:
		extends Control

		func update_all() -> void:
			pass

		func refresh() -> void:
			pass

		func set_compact_mode(_is_compact: bool) -> void:
			pass

		func set_available_width(_available_width: float) -> void:
			pass

		func set_action_controls_enabled(_is_enabled: bool) -> void:
			pass

	func _instantiate_script(_path: String) -> Variant:
		return StubComponent.new()

	func _safe_area_inset(edge: String) -> float:
		if edge == "bottom":
			return fake_safe_bottom
		return 0.0

func _visible_toolbar_min_width(toolbar: Toolbar) -> float:
	var width: float = 0.0
	var visible_controls: int = 0
	for child: Node in toolbar.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		width += control.custom_minimum_size.x
		visible_controls += 1
	if visible_controls > 1:
		width += float(visible_controls - 1) * float(toolbar.get_theme_constant("separation"))
	return width

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

	var toolbar := Toolbar.new()
	toolbar._ready()
	toolbar.set_compact_mode(true)
	toolbar.set_available_width(375.0)
	t.check(
		_visible_toolbar_min_width(toolbar) <= 343.0,
		"narrow mobile toolbar fits a 375px portrait viewport after HUD panel margins"
	)
	t.check(
		toolbar._quickslots[0].visible and toolbar._quickslots[1].visible,
		"narrow mobile toolbar keeps the first two quickslots visible"
	)
	t.check(
		not toolbar._quickslot_sep.visible and not toolbar._settings_sep.visible,
		"narrow mobile toolbar hides nonessential separators"
	)
	toolbar.free()

	var layout_hud := LayoutHud.new()
	layout_hud._vp_size = Vector2(393, 852)
	layout_hud.fake_safe_bottom = 24.0
	layout_hud._build_layout()
	layout_hud._apply_responsive_layout()
	var layout_root: Control = layout_hud.get_node_or_null("HUDRoot") as Control
	var status_container: Control = layout_root.get_node_or_null("StatusContainer") as Control
	t.check(
		layout_hud.toolbar != null and is_equal_approx(layout_hud.toolbar.position.y, 756.0),
		"mobile toolbar stays above the bottom safe area"
	)
	t.check(
		layout_hud.toolbar != null and is_equal_approx(layout_hud.toolbar.size.x, 393.0),
		"mobile toolbar keeps the full viewport width when no horizontal safe area is present"
	)
	t.check(
		status_container != null and is_equal_approx(status_container.size.x, 381.0),
		"mobile status panel leaves HUD margins while staying visible"
	)
	t.check(
		layout_hud._status_overlay != null and layout_hud._status_overlay.visible,
		"mobile status overlay remains visible in portrait layout"
	)
	layout_hud.free()
