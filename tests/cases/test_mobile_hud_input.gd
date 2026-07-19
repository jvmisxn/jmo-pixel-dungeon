extends RefCounted

class FakeHud:
	extends Node

	func contains_screen_position(_screen_pos: Vector2) -> bool:
		return true

class FakeHero:
	extends Node

	var is_alive: bool = true
	var hp: int = 20
	var hp_max: int = 20
	var hero_class: int = ConstantsData.HeroClass.WARRIOR
	var hero_name: String = ""
	var hero_slot_index: int = 0

class TestHud:
	extends HUD

	var focused_hero_index: int = -1

	func _on_party_focus_pressed(hero_index: int) -> void:
		focused_hero_index = hero_index

class LayoutHud:
	extends HUD

	var fake_safe_bottom: float = 0.0
	var fake_safe_left: float = 0.0
	var fake_safe_right: float = 0.0
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
		if edge == "left":
			return fake_safe_left
		if edge == "right":
			return fake_safe_right
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

func _row_min_width(row: HBoxContainer) -> float:
	var width: float = 0.0
	var visible_controls: int = 0
	for child: Node in row.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		width += control.custom_minimum_size.x
		visible_controls += 1
	if visible_controls > 1:
		width += float(visible_controls - 1) * float(row.get_theme_constant("separation"))
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
	t.check(
		toolbar._btn_quickslot_page != null and toolbar._btn_quickslot_page.visible,
		"narrow mobile toolbar exposes quickslot paging"
	)
	t.check(
		toolbar._quickslots[2].visible == false and toolbar._quickslots[3].visible == false,
		"narrow mobile toolbar starts on quickslots 1-2"
	)
	toolbar._on_quickslot_page()
	t.check(
		toolbar._quickslots[2].visible and toolbar._quickslots[3].visible,
		"narrow mobile toolbar pager exposes quickslots 3-4"
	)
	t.check(
		not toolbar._quickslots[0].visible and not toolbar._quickslots[1].visible,
		"narrow mobile toolbar pager hides the previous pair"
	)
	toolbar._on_quickslot_page()
	t.check(
		toolbar._quickslots[4].visible and toolbar._quickslots[5].visible,
		"narrow mobile toolbar pager exposes quickslots 5-6"
	)
	toolbar._on_quickslot_page()
	t.check(
		toolbar._quickslots[0].visible and toolbar._quickslots[1].visible,
		"narrow mobile toolbar pager wraps back to quickslots 1-2"
	)
	toolbar.set_available_width(320.0)
	t.check(
		_visible_toolbar_min_width(toolbar) <= 320.0,
		"very narrow mobile toolbar fits a 320px visible width"
	)
	t.check(
		toolbar._btn_inventory.visible and toolbar._btn_settings.visible,
		"very narrow mobile toolbar keeps Bag and Menu visible"
	)
	toolbar.set_available_width(375.0)
	toolbar._on_quickslot_page()
	t.check(
		toolbar._quickslots[2].visible and toolbar._quickslots[3].visible,
		"mobile toolbar can return to quickslots 3-4 before an ultra-narrow resize"
	)
	toolbar.set_available_width(280.0)
	t.check(
		_visible_toolbar_min_width(toolbar) <= 280.0,
		"foldable-width mobile toolbar fits a 280px visible width"
	)
	t.check(
		toolbar._btn_inventory.custom_minimum_size.x > 0.0
				and toolbar._btn_settings.custom_minimum_size.x > 0.0
				and toolbar._btn_quickslot_page.custom_minimum_size.x > 0.0,
		"foldable-width mobile toolbar preserves tappable core controls"
	)
	t.check(
		toolbar._quickslots[2].visible and not toolbar._quickslots[3].visible,
		"ultra-narrow mobile toolbar preserves the active quickslot group while showing one slot per page"
	)
	t.check(
		not toolbar._btn_search.visible,
		"ultra-narrow mobile toolbar hides search before shrinking core controls too far"
	)
	toolbar._btn_inventory.position = Vector2.ZERO
	toolbar._btn_inventory.size = Vector2.ZERO
	t.check(
		toolbar.activate_button_at_screen_position(Vector2(12, 12)),
		"mobile toolbar fallback hit-testing uses visible minimum button sizes after relayout"
	)
	toolbar.free()

	t.check(
		HUD._parse_browser_viewport_size("393x752") == Vector2i(393, 752),
		"mobile HUD accepts the browser visual viewport probe size"
	)
	t.check(
		GameManager._parse_mobile_web_viewport_size("393x752") == Vector2i(393, 752),
		"mobile content scale accepts the same visual viewport probe size as HUD layout"
	)
	t.check(
		HUD._parse_browser_viewport_size("0x752") == Vector2i.ZERO,
		"mobile HUD rejects zero-width browser viewport probe results"
	)
	t.check(
		GameManager._parse_mobile_web_viewport_size("393x0") == Vector2i.ZERO,
		"mobile content scale rejects zero-height browser viewport probe results"
	)
	t.check(
		HUD._parse_browser_viewport_size("393") == Vector2i.ZERO,
		"mobile HUD rejects malformed browser viewport probe results"
	)
	t.check(
		GameManager._parse_mobile_web_viewport_size("393") == Vector2i.ZERO,
		"mobile content scale rejects malformed browser viewport probe results"
	)

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
	var portrait_party_row: Control = layout_root.get_node_or_null("PartyRow") as Control
	t.check(
		portrait_party_row != null
				and is_equal_approx(portrait_party_row.position.x, HUD.HUD_MARGIN)
				and is_equal_approx(portrait_party_row.position.y, status_container.position.y + status_container.size.y + HUD.HUD_MARGIN)
				and is_equal_approx(portrait_party_row.size.x, 381.0),
		"mobile portrait party row stays below the status panel and inside the visible viewport width"
	)
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_hero: Node = GameManager.hero
	var original_local_hero_index: int = GameManager.local_hero_index
	var party_heroes: Array[Node] = []
	for hero_index: int in range(4):
		var hero := FakeHero.new()
		hero.hero_name = "Hero%d" % (hero_index + 1)
		hero.hero_slot_index = hero_index
		party_heroes.append(hero)
	GameManager.heroes = party_heroes
	GameManager.hero = party_heroes[0]
	GameManager.local_hero_index = 0
	layout_hud._refresh_party_row()
	t.check(
		portrait_party_row != null
				and portrait_party_row.get_child_count() == 4
				and is_equal_approx(float(portrait_party_row.get_theme_constant("separation")), 4.0)
				and is_equal_approx((portrait_party_row.get_child(0) as Control).custom_minimum_size.x, 86.0)
				and _row_min_width(portrait_party_row as HBoxContainer) <= portrait_party_row.size.x,
		"mobile portrait party row fits four focus buttons within the visible row width"
	)
	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.local_hero_index = original_local_hero_index
	for hero_node: Node in party_heroes:
		hero_node.free()
	var portrait_online_label: Control = layout_root.get_node_or_null("OnlineStateLabel") as Control
	t.check(
		portrait_online_label != null
				and is_equal_approx(portrait_online_label.position.x, HUD.HUD_MARGIN)
				and is_equal_approx(portrait_online_label.position.y, portrait_party_row.position.y + 38.0)
				and is_equal_approx(portrait_online_label.size.x, 381.0),
		"mobile portrait online state label stays below party controls and inside the visible viewport width"
	)
	var log_container: Control = layout_root.get_node_or_null("GameLog") as Control
	t.check(
		log_container != null
				and log_container.position.y + log_container.size.y <= layout_hud.toolbar.position.y - HUD.HUD_MARGIN,
		"mobile game log stays clear of the safe-area-adjusted toolbar"
	)
	t.check(
		layout_hud._status_overlay != null and layout_hud._status_overlay.visible,
		"mobile status overlay remains visible in portrait layout"
	)
	var stale_party_x: float = portrait_party_row.position.x
	portrait_party_row.position = Vector2(250.0, 6.0)
	log_container.position = Vector2(6.0, 100.0)
	layout_hud.toolbar.position = Vector2.ZERO
	original_heroes = GameManager.heroes.duplicate()
	original_hero = GameManager.hero
	original_local_hero_index = GameManager.local_hero_index
	party_heroes = []
	for hero_index: int in range(4):
		var relayout_hero := FakeHero.new()
		relayout_hero.hero_name = "Relayout%d" % (hero_index + 1)
		relayout_hero.hero_slot_index = hero_index
		party_heroes.append(relayout_hero)
	GameManager.heroes = party_heroes
	GameManager.hero = party_heroes[0]
	GameManager.local_hero_index = 0
	layout_hud.update_all()
	t.check(
		portrait_party_row.visible
				and is_equal_approx(portrait_party_row.position.x, stale_party_x)
				and is_equal_approx(portrait_party_row.size.x, 381.0),
		"mobile HUD update_all relayouts newly visible party controls"
	)
	t.check(
		log_container.position.y + log_container.size.y <= layout_hud.toolbar.position.y - HUD.HUD_MARGIN,
		"mobile HUD update_all relayouts the log after state refresh"
	)
	t.check(
		is_equal_approx(layout_hud.toolbar.position.y, 756.0),
		"mobile HUD update_all restores the safe-area toolbar position"
	)
	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.local_hero_index = original_local_hero_index
	for hero_node: Node in party_heroes:
		hero_node.free()
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

	var landscape_hud := LayoutHud.new()
	landscape_hud._vp_size = Vector2(852, 393)
	landscape_hud.fake_safe_bottom = 21.0
	landscape_hud.fake_safe_left = 44.0
	landscape_hud.fake_safe_right = 44.0
	landscape_hud._build_layout()
	landscape_hud._apply_responsive_layout()
	var landscape_root: Control = landscape_hud.get_node_or_null("HUDRoot") as Control
	var landscape_status: Control = landscape_root.get_node_or_null("StatusContainer") as Control
	var landscape_party_row: Control = landscape_root.get_node_or_null("PartyRow") as Control
	var landscape_online_label: Control = landscape_root.get_node_or_null("OnlineStateLabel") as Control
	var landscape_log: Control = landscape_root.get_node_or_null("GameLog") as Control
	t.check(
		landscape_hud.toolbar != null and is_equal_approx(landscape_hud.toolbar.position.y, 300.0),
		"mobile landscape toolbar stays above the bottom safe area"
	)
	t.check(
		landscape_party_row != null
				and is_equal_approx(landscape_party_row.position.x, 50.0)
				and is_equal_approx(landscape_party_row.position.y, landscape_status.position.y + landscape_status.size.y + HUD.HUD_MARGIN)
				and is_equal_approx(landscape_party_row.size.x, 520.0),
		"mobile landscape party row sits below status and avoids the horizontal safe area"
	)
	t.check(
		landscape_online_label != null
				and is_equal_approx(landscape_online_label.position.x, 50.0)
				and is_equal_approx(landscape_online_label.position.y, landscape_party_row.position.y + 38.0)
				and is_equal_approx(landscape_online_label.size.x, 752.0),
		"mobile landscape online state label sits below party controls and avoids the horizontal safe area"
	)
	t.check(
		landscape_online_label != null
				and landscape_log != null
				and landscape_online_label.position.y + landscape_online_label.size.y <= landscape_log.position.y - HUD.HUD_MARGIN,
		"mobile landscape online state label stays clear of the game log"
	)
	t.check(
		landscape_log != null
				and landscape_log.position.y + landscape_log.size.y <= landscape_hud.toolbar.position.y - HUD.HUD_MARGIN,
		"mobile landscape game log stays clear of the toolbar"
	)
	t.check(
		landscape_log != null
				and is_equal_approx(landscape_log.position.x, 50.0)
				and landscape_log.position.x >= landscape_hud.fake_safe_left + HUD.HUD_MARGIN,
		"mobile landscape game log avoids the horizontal safe area"
	)
	landscape_hud.free()

	var short_landscape_hud := LayoutHud.new()
	short_landscape_hud._vp_size = Vector2(852, 320)
	short_landscape_hud.fake_safe_bottom = 21.0
	short_landscape_hud.fake_safe_left = 44.0
	short_landscape_hud.fake_safe_right = 44.0
	short_landscape_hud._build_layout()
	short_landscape_hud._apply_responsive_layout()
	var short_root: Control = short_landscape_hud.get_node_or_null("HUDRoot") as Control
	var short_online_label: Control = short_root.get_node_or_null("OnlineStateLabel") as Control
	var short_log: Control = short_root.get_node_or_null("GameLog") as Control
	t.check(
		short_online_label != null
				and short_log != null
				and short_online_label.position.y + short_online_label.size.y <= short_log.position.y - HUD.HUD_MARGIN,
		"short mobile landscape keeps the game log below party turn labels"
	)
	t.check(
		short_log != null
				and short_landscape_hud.toolbar != null
				and short_log.position.y + short_log.size.y <= short_landscape_hud.toolbar.position.y - HUD.HUD_MARGIN,
		"short mobile landscape shrinks the game log before it hits the toolbar"
	)
	t.check(
		short_log != null and short_log.size.y < 96.0 and short_log.size.y >= 48.0,
		"short mobile landscape preserves a usable but reduced game log"
	)
	t.check(
		short_log != null
				and is_equal_approx(short_log.position.x, 50.0)
				and short_log.position.x >= short_landscape_hud.fake_safe_left + HUD.HUD_MARGIN,
		"short mobile landscape game log avoids the horizontal safe area"
	)
	short_landscape_hud.free()

	var ultra_short_landscape_hud := LayoutHud.new()
	ultra_short_landscape_hud._vp_size = Vector2(640, 240)
	ultra_short_landscape_hud.fake_safe_bottom = 21.0
	ultra_short_landscape_hud.fake_safe_left = 44.0
	ultra_short_landscape_hud.fake_safe_right = 44.0
	ultra_short_landscape_hud._build_layout()
	ultra_short_landscape_hud._apply_responsive_layout()
	var ultra_short_root: Control = ultra_short_landscape_hud.get_node_or_null("HUDRoot") as Control
	var ultra_short_log: Control = ultra_short_root.get_node_or_null("GameLog") as Control
	t.check(
		ultra_short_log != null
				and ultra_short_landscape_hud.toolbar != null
				and ultra_short_log.position.y + ultra_short_log.size.y <= ultra_short_landscape_hud.toolbar.position.y - HUD.HUD_MARGIN,
		"ultra-short mobile landscape never lets the game log overlap the toolbar"
	)
	t.check(
		ultra_short_log != null
				and not ultra_short_log.visible
				and is_zero_approx(ultra_short_log.size.y),
		"ultra-short mobile landscape hides the log when no usable vertical gap remains"
	)
	ultra_short_landscape_hud.free()

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
