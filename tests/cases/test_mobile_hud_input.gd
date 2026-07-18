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
	var fake_canvas_size: Vector2 = Vector2.ZERO
	var inventory_taps: int = 0
	var toolbar_action_taps: int = 0

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
		if _path == "res://src/ui/toolbar.gd":
			var toolbar := Toolbar.new()
			toolbar._ready()
			return toolbar
		return StubComponent.new()

	func _safe_area_inset(edge: String) -> float:
		if edge == "bottom":
			return fake_safe_bottom
		return 0.0

	func _get_canvas_viewport_size() -> Vector2:
		if fake_canvas_size != Vector2.ZERO:
			return fake_canvas_size
		return _vp_size

	func _on_inventory_pressed() -> void:
		inventory_taps += 1
		toolbar_action_taps += 1

	func _on_toolbar_action_pressed() -> void:
		toolbar_action_taps += 1

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
	layout_hud._connect_signals()
	layout_hud._toolbar_bar.wait_pressed.connect(layout_hud._on_toolbar_action_pressed)
	layout_hud._toolbar_bar.search_pressed.connect(layout_hud._on_toolbar_action_pressed)
	layout_hud._toolbar_bar.quickslot_used.connect(func(_slot_index: int, _item: RefCounted) -> void:
		layout_hud._on_toolbar_action_pressed()
	)
	t.check(
		layout_hud.handle_screen_tap(Vector2(26, 790)),
		"mobile HUD touch release activates a toolbar control"
	)
	t.check(
		layout_hud.toolbar_action_taps == 1,
		"mobile toolbar tap emits the matching toolbar action"
	)
	layout_hud.free()

	var scaled_hud := LayoutHud.new()
	scaled_hud.fake_canvas_size = Vector2(1179, 1704)
	scaled_hud._vp_size = Vector2(393, 852)
	scaled_hud._build_layout()
	scaled_hud._apply_viewport_size(Vector2(393, 852))
	t.check(
		is_equal_approx(scaled_hud.scale.x, 3.0) and is_equal_approx(scaled_hud.scale.y, 2.0),
		"mobile HUD scales CSS-viewport layout up to the backing canvas"
	)
	t.check(
		scaled_hud.toolbar != null
				and is_equal_approx(scaled_hud.toolbar.size.x * scaled_hud.scale.x, 1179.0),
		"scaled mobile toolbar remains full-width on a larger backing canvas"
	)
	t.check(
		scaled_hud._control_contains_screen_position(scaled_hud.toolbar, Vector2(590, 1632)),
		"scaled mobile HUD hit-testing accepts backing-canvas touch coordinates"
	)
	t.check(
		scaled_hud._screen_position_for_control(
			scaled_hud.toolbar,
			Vector2(590, 1632)
		).is_equal_approx(Vector2(196.66667, 816.0)),
		"scaled mobile HUD converts backing-canvas touches before activating toolbar controls"
	)
	scaled_hud.free()

	var scaled_party_hud := TestHud.new()
	scaled_party_hud.scale = Vector2(3.0, 2.0)
	var scaled_party_row := HBoxContainer.new()
	scaled_party_row.visible = true
	scaled_party_row.position = Vector2(100, 200)
	scaled_party_row.size = Vector2(120, 40)
	var scaled_party_button := Button.new()
	scaled_party_button.visible = true
	scaled_party_button.position = Vector2.ZERO
	scaled_party_button.size = Vector2(80, 30)
	scaled_party_button.set_meta("hero_index", 2)
	scaled_party_row.add_child(scaled_party_button)
	scaled_party_hud._party_row = scaled_party_row
	scaled_party_hud.add_child(scaled_party_row)
	t.check(
		scaled_party_hud.handle_screen_tap(Vector2(330, 430)),
		"scaled mobile HUD touch release activates party buttons from backing-canvas coordinates"
	)
	t.check(
		scaled_party_hud.focused_hero_index == 2,
		"scaled party touch focuses the tapped hero index"
	)
	scaled_party_hud.free()
