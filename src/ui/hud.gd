class_name HUD
extends CanvasLayer
## Main HUD controller matching the original SPD layout:
##   - Status pane (top-left): hero avatar, HP/EXP bars, level, depth, buffs
##   - Floating game log (bottom-left): fades over time, not a permanent panel
##   - Toolbar (bottom): inventory, quickslots, wait, search, settings
##   - Minimap (top-right, togglable)
##   - No sidebars — game world fills the screen

# --- Constants ---
const DESKTOP_TOOLBAR_HEIGHT: int = 40
const MOBILE_TOOLBAR_HEIGHT: int = 72
const MOBILE_BREAKPOINT: float = 720.0
const MOBILE_WEB_MAX_VIEWPORT: float = 960.0
const HUD_MARGIN: float = 6.0
const MOBILE_STATUS_HEIGHT: float = 88.0
const MOBILE_STATUS_LANDSCAPE_HEIGHT: float = 76.0
const MOBILE_SAFE_TOP_INSET: float = 18.0
const MOBILE_SAFE_LANDSCAPE_TOP_INSET: float = 8.0
const WEB_LAYOUT_POLL_INTERVAL: float = 0.25

# --- Child panels ---
var toolbar: MarginContainer = null
var window_layer: Control = null

# --- Sub-components ---
var _status_pane: Variant = null
var _toolbar_bar: Variant = null
var _game_log_display: Variant = null
var _boss_hp_bar: Variant = null
var _minimap: Variant = null
var _party_row: HBoxContainer = null
var _online_state_label: Label = null
var _status_overlay: Control = null
var _status_level_label: Label = null
var _status_hp_bar: ProgressBar = null
var _status_shield_bar: ProgressBar = null
var _status_hp_label: Label = null
var _status_xp_bar: ProgressBar = null
var _status_xp_label: Label = null
var _status_depth_label: Label = null
var _status_str_label: Label = null

# --- Active popup window ---
var _active_window: Control = null
# Track sub-windows so they can be cleaned up properly
var _sub_windows: Array[Variant] = []

# --- Viewport size cache ---
var _vp_size: Vector2 = Vector2(1280, 720)
var _web_layout_poll_elapsed: float = 0.0
var _web_viewport_resize_callback: JavaScriptObject = null

func _get_local_hero() -> Variant:
	if GameManager == null:
		return null
	return GameManager.get_local_hero() if GameManager.has_method("get_local_hero") else GameManager.hero

func _get_input_hero() -> Variant:
	if GameManager == null:
		return null
	return GameManager.get_input_hero() if GameManager.has_method("get_input_hero") else _get_local_hero()

func _get_local_owned_hero() -> Variant:
	if GameManager == null:
		return _get_local_hero()
	return GameManager.get_local_owned_hero() if GameManager.has_method("get_local_owned_hero") else _get_local_hero()

func _can_use_local_action_controls() -> bool:
	if NetworkManager == null or not NetworkManager.has_method("is_online_session") or not NetworkManager.is_online_session():
		return true
	var input_hero: Variant = _get_input_hero()
	var local_owned_hero: Variant = _get_local_owned_hero()
	if input_hero == null or local_owned_hero == null:
		return false
	return input_hero == local_owned_hero and input_hero.get("is_alive") == true

func _get_hero_identity(hero_node: Variant) -> String:
	if hero_node == null:
		return "Hero"
	var slot_index: int = int(ConstantsData.get_prop(hero_node, "hero_slot_index", 0))
	var hero_name: String = str(ConstantsData.get_prop(hero_node, "hero_name", "")).strip_edges()
	if hero_name.is_empty():
		hero_name = HeroClassData.get_class_name_str(int(ConstantsData.get_prop(hero_node, "hero_class", ConstantsData.HeroClass.WARRIOR)))
	return "P%d %s" % [slot_index + 1, hero_name]

func _get_hero_class_short(hero_node: Variant) -> String:
	if hero_node == null:
		return "Hero"
	return HeroClassData.get_class_name_str(int(ConstantsData.get_prop(hero_node, "hero_class", ConstantsData.HeroClass.WARRIOR))).left(3)

func _instantiate_script(path: String) -> Variant:
	var script: GDScript = load(path) as GDScript
	if script == null:
		return null
	return script.new()


func _ready() -> void:
	layer = 10
	_vp_size = _get_viewport_size()
	_sync_canvas_layer_scale()
	_build_layout()
	_connect_signals()
	update_all()
	_apply_responsive_layout()
	# Re-layout when viewport resizes
	get_viewport().size_changed.connect(_on_viewport_resized)
	_connect_web_viewport_resize_events()


func _process(delta: float) -> void:
	if OS.get_name() != "Web":
		return
	_web_layout_poll_elapsed += delta
	if _web_layout_poll_elapsed < WEB_LAYOUT_POLL_INTERVAL:
		return
	_web_layout_poll_elapsed = 0.0
	var current_size: Vector2 = _get_viewport_size()
	if not current_size.is_equal_approx(_vp_size):
		_apply_viewport_size(current_size)


func _build_layout() -> void:
	# Root control fills screen
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Status Pane (top-left, like original SPD) ---
	var status_container: PanelContainer = PanelContainer.new()
	status_container.name = "StatusContainer"
	status_container.position = Vector2(HUD_MARGIN, HUD_MARGIN)
	status_container.custom_minimum_size = Vector2(220, 140)
	status_container.clip_contents = true
	var status_style: StyleBoxFlat = StyleBoxFlat.new()
	status_style.bg_color = Color(0.08, 0.07, 0.06, 0.92)
	status_style.border_color = Color(0.35, 0.30, 0.25)
	status_style.border_width_right = 1
	status_style.border_width_bottom = 1
	status_style.corner_radius_bottom_right = 4
	status_style.content_margin_left = 6.0
	status_style.content_margin_right = 6.0
	status_style.content_margin_top = 4.0
	status_style.content_margin_bottom = 4.0
	status_container.add_theme_stylebox_override("panel", status_style)
	_status_pane = _instantiate_script("res://src/ui/status_pane.gd")
	_status_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status_pane.visible = false
	status_container.add_child(_status_pane)
	root.add_child(status_container)
	_build_status_overlay(root)

	# --- Game Log (bottom-left, floating over game world) ---
	var log_container: MarginContainer = MarginContainer.new()
	log_container.name = "GameLog"
	log_container.position = Vector2(HUD_MARGIN, _vp_size.y - _toolbar_height() - 200)
	log_container.custom_minimum_size = Vector2(300, 195)
	log_container.size = Vector2(300, 195)
	log_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var log_panel: PanelContainer = PanelContainer.new()
	log_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var log_style: StyleBoxFlat = StyleBoxFlat.new()
	log_style.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	log_style.content_margin_left = 4.0
	log_style.content_margin_right = 4.0
	log_style.content_margin_top = 2.0
	log_style.content_margin_bottom = 2.0
	log_panel.add_theme_stylebox_override("panel", log_style)
	_game_log_display = _instantiate_script("res://src/ui/game_log_display.gd")
	_game_log_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_panel.add_child(_game_log_display)
	log_container.add_child(log_panel)
	root.add_child(log_container)

	# --- Toolbar (bottom, full width) ---
	toolbar = MarginContainer.new()
	toolbar.name = "Toolbar"
	toolbar.position = Vector2(0, _vp_size.y - _toolbar_height())
	toolbar.custom_minimum_size = Vector2(_vp_size.x, _toolbar_height())
	toolbar.size = Vector2(_vp_size.x, _toolbar_height())
	var toolbar_panel: PanelContainer = PanelContainer.new()
	toolbar_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var toolbar_style: StyleBoxFlat = StyleBoxFlat.new()
	toolbar_style.bg_color = Color(0.1, 0.09, 0.08, 0.95)
	toolbar_style.border_color = Color(0.4, 0.35, 0.28)
	toolbar_style.border_width_top = 1
	toolbar_style.content_margin_left = 8.0
	toolbar_style.content_margin_right = 8.0
	toolbar_style.content_margin_top = 2.0
	toolbar_style.content_margin_bottom = 2.0
	toolbar_panel.add_theme_stylebox_override("panel", toolbar_style)
	_toolbar_bar = _instantiate_script("res://src/ui/toolbar.gd")
	toolbar_panel.add_child(_toolbar_bar)
	toolbar.add_child(toolbar_panel)
	root.add_child(toolbar)

	# --- Depth / Gold info (top-right, beside minimap) ---
	var info_row: HBoxContainer = HBoxContainer.new()
	info_row.name = "InfoRow"
	info_row.add_theme_constant_override("separation", 16)
	info_row.position = Vector2(_vp_size.x - 260, HUD_MARGIN)
	info_row.custom_minimum_size = Vector2(180, 20)
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var depth_label: Label = Label.new()
	depth_label.name = "DepthLabel"
	depth_label.text = "Depth: 1"
	depth_label.add_theme_font_size_override("font_size", 12)
	depth_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	depth_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	depth_label.add_theme_constant_override("shadow_offset_x", 1)
	depth_label.add_theme_constant_override("shadow_offset_y", 1)
	info_row.add_child(depth_label)

	var gold_label: Label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "Gold: 0"
	gold_label.add_theme_font_size_override("font_size", 12)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	gold_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	gold_label.add_theme_constant_override("shadow_offset_x", 1)
	gold_label.add_theme_constant_override("shadow_offset_y", 1)
	info_row.add_child(gold_label)

	root.add_child(info_row)

	# --- Party Row (top-center, hidden in solo play) ---
	_party_row = HBoxContainer.new()
	_party_row.name = "PartyRow"
	_party_row.add_theme_constant_override("separation", 6)
	_party_row.position = Vector2(250, HUD_MARGIN)
	_party_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_party_row.visible = false
	root.add_child(_party_row)

	# --- Online State Label (top-center, below party row) ---
	_online_state_label = Label.new()
	_online_state_label.name = "OnlineStateLabel"
	_online_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_online_state_label.add_theme_font_size_override("font_size", 12)
	_online_state_label.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	_online_state_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_online_state_label.add_theme_constant_override("shadow_offset_x", 1)
	_online_state_label.add_theme_constant_override("shadow_offset_y", 1)
	_online_state_label.position = Vector2(330, HUD_MARGIN + 38)
	_online_state_label.custom_minimum_size = Vector2(620, 20)
	_online_state_label.visible = false
	root.add_child(_online_state_label)

	# --- Minimap (top-right corner, below info row) ---
	_minimap = _instantiate_script("res://src/ui/minimap.gd")
	_minimap.position = Vector2(_vp_size.x - 74, 28)
	_minimap.custom_minimum_size = Vector2(64, 64)
	_minimap.size = Vector2(64, 64)
	root.add_child(_minimap)

	# --- Window Layer (centered overlay for popups) ---
	window_layer = Control.new()
	window_layer.name = "WindowLayer"
	window_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_layer.visible = false
	root.add_child(window_layer)

	# --- Boss HP Bar (separate CanvasLayer, above HUD) ---
	_boss_hp_bar = _instantiate_script("res://src/ui/boss_hp_bar.gd")
	_boss_hp_bar.name = "BossHPBar"
	add_child(_boss_hp_bar)


func contains_screen_position(screen_pos: Vector2) -> bool:
	var root_node: Control = get_node_or_null("HUDRoot") as Control
	if root_node == null:
		return false
	if window_layer != null and window_layer.visible:
		return true
	if toolbar != null and _control_contains_screen_position(toolbar, screen_pos):
		return true
	var status_container: Control = root_node.get_node_or_null("StatusContainer") as Control
	if status_container != null and _control_contains_screen_position(status_container, screen_pos):
		return true
	var party_row: Control = root_node.get_node_or_null("PartyRow") as Control
	if party_row != null and party_row.visible and _control_contains_screen_position(party_row, screen_pos):
		return true
	return false


func handle_screen_tap(screen_pos: Vector2) -> bool:
	if window_layer != null and window_layer.visible:
		return true
	if toolbar != null and _control_contains_screen_position(toolbar, screen_pos):
		if _toolbar_bar != null and _toolbar_bar.has_method("activate_button_at_screen_position"):
			var toolbar_pos: Vector2 = _screen_position_for_control(toolbar, screen_pos)
			return bool(_toolbar_bar.activate_button_at_screen_position(toolbar_pos))
		return true
	if _party_row != null and _party_row.visible and _control_contains_screen_position(_party_row, screen_pos):
		return _activate_party_button_at_screen_position(screen_pos)
	return false


func _control_contains_screen_position(control: Control, screen_pos: Vector2) -> bool:
	if control == null or not control.visible:
		return false
	var rect: Rect2 = control.get_global_rect()
	return rect.has_point(screen_pos) or rect.has_point(_scaled_screen_position_to_hud_space(screen_pos))


func _screen_position_for_control(control: Control, screen_pos: Vector2) -> Vector2:
	if control == null:
		return screen_pos
	var rect: Rect2 = control.get_global_rect()
	if rect.has_point(screen_pos):
		return screen_pos
	var hud_space_pos: Vector2 = _scaled_screen_position_to_hud_space(screen_pos)
	return hud_space_pos if rect.has_point(hud_space_pos) else screen_pos


func _scaled_screen_position_to_hud_space(screen_pos: Vector2) -> Vector2:
	if is_zero_approx(scale.x) or is_zero_approx(scale.y):
		return screen_pos
	if scale.is_equal_approx(Vector2.ONE):
		return screen_pos
	return Vector2(screen_pos.x / scale.x, screen_pos.y / scale.y)


func _activate_party_button_at_screen_position(screen_pos: Vector2) -> bool:
	if _party_row == null or not _party_row.visible:
		return false
	for child: Node in _party_row.get_children():
		var button: Button = child as Button
		if button == null or button.disabled:
			continue
		if not _control_contains_screen_position(button, screen_pos):
			continue
		var button_pos: Vector2 = _screen_position_for_control(button, screen_pos)
		if not button.get_global_rect().has_point(button_pos):
			continue
		_on_party_focus_pressed(int(button.get_meta("hero_index", -1)))
		return true
	return false


func _connect_signals() -> void:
	var event_bus: Node = EventBus
	if event_bus:
		event_bus.hero_stats_changed.connect(_on_stats_changed)
		event_bus.level_changed.connect(_on_level_changed)
		event_bus.gold_collected.connect(_on_gold_collected)
		event_bus.hero_moved.connect(_on_hero_moved)
		event_bus.show_window.connect(_on_show_window_requested)
		# Boss fight signals (now defined in EventBus)
		event_bus.boss_fight_started.connect(_on_boss_fight_started)
		event_bus.boss_damaged.connect(_on_boss_damaged)
		event_bus.boss_defeated.connect(_on_boss_defeated)

	if _toolbar_bar:
		_toolbar_bar.inventory_pressed.connect(_on_inventory_pressed)
		_toolbar_bar.map_pressed.connect(_on_map_pressed)
		_toolbar_bar.rest_pressed.connect(_on_rest_pressed)
		_toolbar_bar.settings_pressed.connect(_on_settings_pressed)
		_toolbar_bar.quickslot_used.connect(_on_quickslot_used)
	if GameManager and GameManager.has_signal("local_hero_changed"):
		GameManager.local_hero_changed.connect(_on_local_hero_changed)
	if TurnManager and TurnManager.has_signal("input_actor_changed"):
		TurnManager.input_actor_changed.connect(_on_input_actor_changed)


# --- Public API ---

## Show a popup window centered on screen.
func show_window(window_node: Control) -> void:
	close_window()
	_active_window = window_node
	_sub_windows.clear()
	# Listen for sub-window requests ("signal up" pattern — avoids get_parent())
	if window_node.has_signal("open_sub_window"):
		var wnd: Variant = window_node
		if not wnd.open_sub_window.is_connected(_on_sub_window_requested):
			wnd.open_sub_window.connect(_on_sub_window_requested)
		if wnd.has_signal("window_closed"):
			var active_closed: Callable = Callable(self, "_on_active_window_self_closed")
			if not wnd.window_closed.is_connected(active_closed):
				wnd.window_closed.connect(active_closed)
	window_layer.add_child(window_node)
	window_layer.visible = true
	window_layer.mouse_filter = Control.MOUSE_FILTER_STOP


## Handle sub-window open requests from active windows.
func _on_sub_window_requested(wnd: Variant) -> void:
	# Also wire up the sub-window's own sub-window signal
	if wnd.has_signal("open_sub_window") and not wnd.open_sub_window.is_connected(_on_sub_window_requested):
		wnd.open_sub_window.connect(_on_sub_window_requested)
	if wnd.has_signal("window_closed"):
		var sub_closed: Callable = Callable(self, "_on_sub_window_self_closed").bind(wnd)
		if not wnd.window_closed.is_connected(sub_closed):
			wnd.window_closed.connect(sub_closed)
	_sub_windows.append(wnd)
	window_layer.add_child(wnd)


## Called when a child popup closes itself.
func _on_sub_window_self_closed(wnd: Variant) -> void:
	_sub_windows.erase(wnd)
	_release_window_layer_if_empty()


## Called when the active window closes itself (X button, Escape key).
## Cleans up HUD state so input isn't permanently blocked.
func _on_active_window_self_closed() -> void:
	# The window will queue_free itself and its overlay via _finish_close().
	# We just need to reset HUD tracking state.
	for sub_wnd: Variant in _sub_windows:
		if is_instance_valid(sub_wnd):
			_free_window_node(sub_wnd)
	_sub_windows.clear()
	_active_window = null
	_release_window_layer_if_empty()


## Close the active popup window and all sub-windows.
func close_window() -> void:
	# Clean up tracked sub-windows first
	for sub_wnd: Variant in _sub_windows:
		if is_instance_valid(sub_wnd):
			_free_window_node(sub_wnd)
	_sub_windows.clear()
	if _active_window and is_instance_valid(_active_window):
		_free_window_node(_active_window)
		_active_window = null
	_release_window_layer_if_empty()


func _free_window_node(window_node: Variant) -> void:
	if window_node == null or not is_instance_valid(window_node):
		return
	var overlay: Variant = window_node.get("_background_overlay") if window_node is Object else null
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	window_node.queue_free()


func _release_window_layer_if_empty() -> void:
	if _active_window != null and is_instance_valid(_active_window):
		return
	for sub_wnd: Variant in _sub_windows:
		if is_instance_valid(sub_wnd):
			return
	window_layer.visible = false
	window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Force update all HUD elements.
func update_all() -> void:
	_update_info_row()
	_refresh_quickslots()
	_refresh_party_row()
	_refresh_online_state()
	_refresh_action_controls()
	_refresh_status_overlay()
	if _status_pane:
		_status_pane.update_all()
	if _game_log_display:
		_game_log_display.refresh()


# --- Info Row Updates ---

func _update_info_row() -> void:
	var root_node: Node = get_node_or_null("HUDRoot")
	if not root_node:
		return
	var depth_label: Label = root_node.get_node_or_null("InfoRow/DepthLabel") as Label
	var gold_label: Label = root_node.get_node_or_null("InfoRow/GoldLabel") as Label
	if depth_label and GameManager:
		depth_label.text = "Depth: %d" % GameManager.depth
	if gold_label and GameManager:
		gold_label.text = "Gold: %d" % GameManager.gold


func _get_viewport_size() -> Vector2:
	var browser_size: Vector2i = _get_browser_viewport_size()
	if browser_size != Vector2i.ZERO and _should_layout_against_browser_size(browser_size):
		return Vector2(browser_size)
	return _get_canvas_viewport_size()


func _get_canvas_viewport_size() -> Vector2:
	var vp: Viewport = get_viewport()
	if vp:
		return vp.get_visible_rect().size
	return Vector2(1280, 720)


func _sync_canvas_layer_scale() -> void:
	var canvas_size: Vector2 = _get_canvas_viewport_size()
	if canvas_size.x <= 0.0 or canvas_size.y <= 0.0 or _vp_size.x <= 0.0 or _vp_size.y <= 0.0:
		scale = Vector2.ONE
		return
	scale = Vector2(canvas_size.x / _vp_size.x, canvas_size.y / _vp_size.y)


func _get_browser_viewport_size() -> Vector2i:
	if OS.get_name() != "Web":
		return Vector2i.ZERO
	var js_result: Variant = JavaScriptBridge.eval(
		"(function(){var v=window.visualViewport;" +
		"var w=(v&&v.width)?v.width:window.innerWidth;" +
		"var h=(v&&v.height)?v.height:window.innerHeight;" +
		"return Math.round(w)+'x'+Math.round(h);})()",
		true
	)
	return _parse_browser_viewport_size(js_result)


static func _parse_browser_viewport_size(js_result: Variant) -> Vector2i:
	if js_result is String:
		var parts: PackedStringArray = str(js_result).split("x")
		if parts.size() == 2:
			var width: int = int(parts[0])
			var height: int = int(parts[1])
			if width > 0 and height > 0:
				return Vector2i(width, height)
	return Vector2i.ZERO


func _should_layout_against_browser_size(browser_size: Vector2i) -> bool:
	if browser_size.y > browser_size.x:
		return true
	if mini(browser_size.x, browser_size.y) <= MOBILE_BREAKPOINT:
		return true
	if maxi(browser_size.x, browser_size.y) <= MOBILE_WEB_MAX_VIEWPORT:
		return true
	var js_result: Variant = _eval_browser_mobile_expression()
	return bool(js_result) if js_result is bool else false


func _build_status_overlay(root: Control) -> void:
	_status_overlay = HBoxContainer.new()
	_status_overlay.name = "StatusOverlay"
	_status_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_overlay.alignment = BoxContainer.ALIGNMENT_BEGIN
	_status_overlay.add_theme_constant_override("separation", 8)
	root.add_child(_status_overlay)

	_status_level_label = Label.new()
	_status_level_label.text = "Lv. 1"
	_status_level_label.custom_minimum_size = Vector2(58, 0)
	_status_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_level_label.add_theme_font_size_override("font_size", 18)
	_status_level_label.add_theme_color_override("font_color", Color(0.9, 0.84, 0.62))
	_status_overlay.add_child(_status_level_label)

	var bars: VBoxContainer = VBoxContainer.new()
	bars.custom_minimum_size = Vector2(1, 64)
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bars.add_theme_constant_override("separation", 6)
	_status_overlay.add_child(bars)

	var hp_row: HBoxContainer = HBoxContainer.new()
	hp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_theme_constant_override("separation", 6)
	bars.add_child(hp_row)

	var hp_bar_container: Control = Control.new()
	hp_bar_container.custom_minimum_size = Vector2(1, 22)
	hp_bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(hp_bar_container)

	_status_shield_bar = ProgressBar.new()
	_status_shield_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status_shield_bar.show_percentage = false
	var shield_fill: StyleBoxFlat = StyleBoxFlat.new()
	shield_fill.bg_color = Color(0.85, 0.78, 0.35)
	shield_fill.set_corner_radius_all(2)
	_status_shield_bar.add_theme_stylebox_override("fill", shield_fill)
	var shield_bg: StyleBoxFlat = StyleBoxFlat.new()
	shield_bg.bg_color = Color(0.15, 0.05, 0.05)
	shield_bg.border_color = Color(0.4, 0.2, 0.2)
	shield_bg.set_border_width_all(1)
	shield_bg.set_corner_radius_all(2)
	_status_shield_bar.add_theme_stylebox_override("background", shield_bg)
	hp_bar_container.add_child(_status_shield_bar)

	_status_hp_bar = ProgressBar.new()
	_status_hp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status_hp_bar.show_percentage = false
	var hp_fill: StyleBoxFlat = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.78, 0.16, 0.16)
	hp_fill.set_corner_radius_all(2)
	_status_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	var hp_bg: StyleBoxFlat = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	hp_bg.set_corner_radius_all(2)
	_status_hp_bar.add_theme_stylebox_override("background", hp_bg)
	hp_bar_container.add_child(_status_hp_bar)

	_status_hp_label = Label.new()
	_status_hp_label.text = "20/20"
	_status_hp_label.custom_minimum_size = Vector2(72, 0)
	_status_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_hp_label.add_theme_font_size_override("font_size", 16)
	_status_hp_label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.72))
	hp_row.add_child(_status_hp_label)

	var xp_row: HBoxContainer = HBoxContainer.new()
	xp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_row.add_theme_constant_override("separation", 6)
	bars.add_child(xp_row)

	_status_xp_bar = ProgressBar.new()
	_status_xp_bar.custom_minimum_size = Vector2(1, 18)
	_status_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_xp_bar.show_percentage = false
	var xp_fill: StyleBoxFlat = StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.2, 0.55, 0.85)
	xp_fill.set_corner_radius_all(2)
	_status_xp_bar.add_theme_stylebox_override("fill", xp_fill)
	var xp_bg: StyleBoxFlat = StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.05, 0.1, 0.18)
	xp_bg.border_color = Color(0.2, 0.3, 0.45)
	xp_bg.set_border_width_all(1)
	xp_bg.set_corner_radius_all(2)
	_status_xp_bar.add_theme_stylebox_override("background", xp_bg)
	xp_row.add_child(_status_xp_bar)

	_status_xp_label = Label.new()
	_status_xp_label.text = "0/10"
	_status_xp_label.custom_minimum_size = Vector2(72, 0)
	_status_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_xp_label.add_theme_font_size_override("font_size", 14)
	_status_xp_label.add_theme_color_override("font_color", Color(0.74, 0.84, 0.96))
	xp_row.add_child(_status_xp_label)

	_status_depth_label = Label.new()
	_status_depth_label.text = "D1"
	_status_depth_label.custom_minimum_size = Vector2(54, 0)
	_status_depth_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_depth_label.add_theme_font_size_override("font_size", 15)
	_status_depth_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.86))
	_status_overlay.add_child(_status_depth_label)

	_status_str_label = Label.new()
	_status_str_label.text = "STR 10"
	_status_str_label.custom_minimum_size = Vector2(70, 0)
	_status_str_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_str_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_str_label.add_theme_font_size_override("font_size", 15)
	_status_str_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	_status_overlay.add_child(_status_str_label)


func _on_viewport_resized() -> void:
	_apply_viewport_size(_get_viewport_size())


func _connect_web_viewport_resize_events() -> void:
	if OS.get_name() != "Web":
		return
	_web_viewport_resize_callback = JavaScriptBridge.create_callback(_on_web_viewport_resized)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if window == null:
		return
	if window.visualViewport:
		window.visualViewport.addEventListener("resize", _web_viewport_resize_callback)
	window.addEventListener("orientationchange", _web_viewport_resize_callback)


func _on_web_viewport_resized(_args: Array) -> void:
	_on_viewport_resized.call_deferred()


func _apply_viewport_size(size: Vector2) -> void:
	_vp_size = size
	_sync_canvas_layer_scale()
	var root_node: Node = get_node_or_null("HUDRoot")
	if not root_node:
		return
	# Reposition toolbar at bottom
	if toolbar:
		_layout_toolbar()
	_apply_responsive_layout()


# --- EventBus Signal Handlers ---

func _on_stats_changed() -> void:
	_refresh_quickslots()
	_refresh_status_overlay()
	if _status_pane:
		_status_pane.update_all()


func _on_level_changed(_new_depth: int) -> void:
	_update_info_row()
	_refresh_status_overlay()
	if _status_pane:
		_status_pane.update_all()


func _on_gold_collected(_amount: int, _total: int) -> void:
	_update_info_row()


func _on_hero_moved(_new_pos: int) -> void:
	# Minimap handles hero_moved via its own EventBus connection
	pass


func _on_boss_fight_started(boss_name: String, boss_hp: int) -> void:
	if _boss_hp_bar:
		_boss_hp_bar.show_boss(boss_name, boss_hp, boss_hp)


func _on_boss_damaged(current_hp: int, _max_hp: int) -> void:
	if _boss_hp_bar:
		_boss_hp_bar.update_hp(current_hp)


func _on_boss_defeated() -> void:
	if _boss_hp_bar:
		_boss_hp_bar.hide_boss()

func _on_show_window_requested(window: Variant) -> void:
	if window is Control:
		show_window(window as Control)

func _on_local_hero_changed(_hero_node: Node, _hero_index: int) -> void:
	update_all()

func _on_input_actor_changed(_hero_node: Variant) -> void:
	update_all()

func _refresh_online_state() -> void:
	if _online_state_label == null:
		return
	if NetworkManager == null or not NetworkManager.has_method("is_online_session") or not NetworkManager.is_online_session():
		_online_state_label.visible = false
		return
	var local_hero: Variant = _get_local_hero()
	var local_owned_hero: Variant = _get_local_owned_hero()
	var input_hero: Variant = _get_input_hero()
	var state_text: String = ""
	var state_color: Color = Color(0.82, 0.9, 1.0)
	if GameManager != null and GameManager.has_method("is_local_player_spectating") and GameManager.is_local_player_spectating():
		state_text = "Spectating %s" % _get_hero_identity(local_hero)
		state_color = Color(0.9, 0.82, 0.62)
	elif local_hero == null:
		state_text = "Waiting for party state..."
	elif input_hero != null and input_hero == local_hero:
		state_text = "Your turn: %s" % _get_hero_identity(local_hero)
		state_color = Color(0.72, 1.0, 0.72)
	else:
		var waiting_name: String = ""
		if input_hero != null:
			waiting_name = _get_hero_identity(input_hero)
		state_text = "Waiting for %s" % (waiting_name if not waiting_name.is_empty() else "another player")
		if local_owned_hero != null and local_owned_hero != local_hero and local_hero != null:
			state_text += "  |  Focus: %s" % _get_hero_identity(local_hero)
		state_color = Color(0.82, 0.9, 1.0)
	_online_state_label.text = state_text
	_online_state_label.add_theme_color_override("font_color", state_color)
	_online_state_label.visible = not state_text.is_empty()

func _refresh_party_row() -> void:
	if _party_row == null or GameManager == null:
		return
	for child: Node in _party_row.get_children():
		child.queue_free()
	var heroes: Array[Node] = GameManager.get_active_heroes() if GameManager.has_method("get_active_heroes") else []
	if heroes.size() <= 1:
		_party_row.visible = false
		return
	_party_row.visible = true
	_party_row.add_theme_constant_override("separation", 4 if _is_mobile_layout() else 6)
	var button_width: float = 86.0 if _is_mobile_layout() else 104.0
	var focused_hero: Variant = _get_local_hero()
	var local_owned_hero: Variant = _get_local_owned_hero()
	var input_hero: Variant = _get_input_hero()
	for idx: int in range(heroes.size()):
		var hero_ref: Node = heroes[idx]
		if hero_ref == null:
			continue
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(button_width, 34)
		btn.clip_text = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var is_alive: bool = hero_ref.get("is_alive") == true
		var marker: String = ">" if hero_ref == input_hero else " "
		var owner_suffix: String = " YOU" if hero_ref == local_owned_hero else ""
		var focus_prefix: String = "*" if hero_ref == focused_hero else " "
		var status_suffix: String = " DEAD" if not is_alive else ""
		btn.text = "%s%s %s %d/%d%s%s" % [focus_prefix, marker, _get_hero_class_short(hero_ref), int(hero_ref.hp), int(hero_ref.hp_max), status_suffix, owner_suffix]
		btn.tooltip_text = ("%s " % ("Spectate" if not is_alive else "Focus")) + _get_hero_identity(hero_ref)
		btn.disabled = not is_alive
		if hero_ref == focused_hero:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		elif hero_ref == local_owned_hero:
			btn.modulate = Color(1.0, 0.92, 0.72, 0.96) if is_alive else Color(0.66, 0.56, 0.46, 0.82)
		else:
			btn.modulate = Color(0.82, 0.82, 0.88, 0.92) if is_alive else Color(0.58, 0.58, 0.62, 0.82)
		if is_alive:
			btn.set_meta("hero_index", idx)
			btn.pressed.connect(_on_party_focus_pressed.bind(idx))
		_party_row.add_child(btn)

func _refresh_action_controls() -> void:
	if _toolbar_bar == null or not _toolbar_bar.has_method("set_action_controls_enabled"):
		return
	_toolbar_bar.set_action_controls_enabled(_can_use_local_action_controls())

func _on_party_focus_pressed(hero_index: int) -> void:
	if GameManager and GameManager.has_method("set_local_hero_index"):
		GameManager.set_local_hero_index(hero_index)


# --- Toolbar Signal Handlers ---

func _on_inventory_pressed() -> void:
	if not _can_use_local_action_controls():
		if MessageLog:
			MessageLog.add_warning("Wait for your hero's turn to manage actions.")
		return
	var wnd: Variant = _instantiate_script("res://src/ui/windows/wnd_inventory.gd")
	show_window(wnd)


func _on_map_pressed() -> void:
	if has_active_window() and _active_window != null and _active_window.get_script() != null and str(_active_window.get_script().resource_path).ends_with("wnd_map.gd"):
		close_window()
		return
	var wnd: Variant = _instantiate_script("res://src/ui/windows/wnd_map.gd")
	show_window(wnd)


func _on_rest_pressed() -> void:
	if not _can_use_local_action_controls():
		if MessageLog:
			MessageLog.add_warning("Wait for your hero's turn.")
		return
	var hero_ref: Variant = _get_local_hero()
	if GameManager == null or hero_ref == null or TurnManager == null:
		return
	if not TurnManager.waiting_for_input or TurnManager.processing_mobs:
		return
	if _visible_enemy_present():
		if MessageLog:
			MessageLog.add_warning("You can't rest while enemies are in view.")
		return
	if hero_ref.has_method("rest"):
		hero_ref.rest(true)


func _visible_enemy_present() -> bool:
	var level_ref: Variant = GameManager.current_level if GameManager else null
	if level_ref == null or level_ref.get("mobs") == null or level_ref.get("visible") == null:
		return false
	for mob: Variant in level_ref.mobs:
		if not is_instance_valid(mob):
			continue
		if mob.get("is_alive") != true:
			continue
		var mob_pos: int = mob.get("pos") as int
		if mob_pos >= 0 and mob_pos < level_ref.visible.size() and level_ref.visible[mob_pos]:
			return true
	return false


func _on_settings_pressed() -> void:
	var wnd: Variant = _instantiate_script("res://src/ui/windows/wnd_settings.gd")
	show_window(wnd)


func _on_quickslot_used(_slot_index: int, item: RefCounted) -> void:
	if not _can_use_local_action_controls():
		if MessageLog:
			MessageLog.add_warning("Wait for your hero's turn to use quickslots.")
		return
	var hero_ref: Variant = _get_local_hero()
	if GameManager == null or hero_ref == null or item == null:
		return
	if item.has_method("zap") or (item is Object and ConstantsData.get_prop(item, "zap_range") != null):
		var wand: Variant = item
		if ConstantsData.get_prop(wand, "charges", 0) <= 0:
			if MessageLog:
				MessageLog.add_warning("The %s has no charges left!" % ConstantsData.get_prop(wand, "item_name", "wand"))
			return
		var zap_callback: Callable = func(cell: int) -> void:
			if EventBus and EventBus.has_signal("request_hero_action"):
				EventBus.request_hero_action.emit({"type": "zap_wand", "item": wand, "target_pos": cell})
		if EventBus:
			var max_range: int = ConstantsData.get_prop(wand, "zap_range", 8) if ConstantsData.get_prop(wand, "zap_range") else 8
			EventBus.enter_targeting.emit(wand, max_range, zap_callback)
		return
	if EventBus and EventBus.has_signal("request_hero_action"):
		EventBus.request_hero_action.emit({"type": "use_item", "item": item})

func has_active_window() -> bool:
	return _active_window != null and is_instance_valid(_active_window)

func toggle_inventory() -> void:
	if not _can_use_local_action_controls():
		if MessageLog:
			MessageLog.add_warning("Wait for your hero's turn to open inventory.")
		return
	if has_active_window() and _active_window != null and _active_window.get_script() != null and str(_active_window.get_script().resource_path).ends_with("wnd_inventory.gd"):
		close_window()
		return
	_on_inventory_pressed()

func toggle_map() -> void:
	_on_map_pressed()

func open_settings() -> void:
	if has_active_window() and _active_window != null and _active_window.get_script() != null and str(_active_window.get_script().resource_path).ends_with("wnd_settings.gd"):
		close_window()
		return
	_on_settings_pressed()

func use_quickslot(slot_index: int) -> void:
	if not _can_use_local_action_controls():
		if MessageLog:
			MessageLog.add_warning("Wait for your hero's turn to use quickslots.")
		return
	if slot_index < 0 or slot_index >= 6:
		return
	var hero_ref: Variant = _get_local_hero()
	var belongings: Variant = hero_ref.get("belongings") if hero_ref != null else null
	if belongings == null or not belongings.has_method("get_quickslot"):
		return
	var item: RefCounted = belongings.get_quickslot(slot_index)
	_on_quickslot_used(slot_index, item)

func _refresh_quickslots() -> void:
	var hero_ref: Variant = _get_local_hero()
	if _toolbar_bar == null or GameManager == null or hero_ref == null:
		return
	var belongings: Variant = hero_ref.get("belongings")
	if belongings == null or not belongings.has_method("get_quickslot"):
		return
	for i: int in range(6):
		_toolbar_bar.set_quickslot_item(i, belongings.get_quickslot(i))


func _apply_responsive_layout() -> void:
	var root_node: Control = get_node_or_null("HUDRoot") as Control
	if root_node == null:
		return

	var is_mobile_layout: bool = _is_mobile_layout()
	var status_container: Control = root_node.get_node_or_null("StatusContainer") as Control
	var log_container: Control = root_node.get_node_or_null("GameLog") as Control
	var info_row: Control = root_node.get_node_or_null("InfoRow") as Control
	var party_row: Control = root_node.get_node_or_null("PartyRow") as Control

	if status_container:
		var safe_left: float = _safe_area_inset("left")
		var safe_right: float = _safe_area_inset("right")
		var available_width: float = maxf(
			1.0,
			_vp_size.x - safe_left - safe_right - (HUD_MARGIN * 2.0)
		)
		var mobile_status_height: float = MOBILE_STATUS_HEIGHT if _is_mobile_portrait_layout() else MOBILE_STATUS_LANDSCAPE_HEIGHT
		status_container.position = Vector2(safe_left + HUD_MARGIN, _hud_top_margin())
		status_container.custom_minimum_size = (
			Vector2(available_width, mobile_status_height)
			if is_mobile_layout
			else Vector2(180 if is_mobile_layout else 220, 140)
		)
		status_container.size = status_container.custom_minimum_size
		if _status_pane and _status_pane.has_method("set_compact_mode"):
			_status_pane.set_compact_mode(is_mobile_layout)
			_status_pane.custom_minimum_size = Vector2(
				maxf(1.0, status_container.size.x - 12.0),
				maxf(1.0, status_container.size.y - 8.0)
			)
			_status_pane.size = _status_pane.custom_minimum_size
		_layout_status_overlay(status_container)

	if log_container:
		_layout_game_log(log_container, status_container, party_row)

	if info_row:
		var info_width: float = 180.0
		info_row.position = Vector2(maxf(HUD_MARGIN, _vp_size.x - info_width - HUD_MARGIN), _hud_top_margin())
		info_row.visible = not is_mobile_layout

	if party_row:
		var party_safe_left: float = _safe_area_inset("left") if is_mobile_layout else 0.0
		var party_safe_right: float = _safe_area_inset("right") if is_mobile_layout else 0.0
		var party_available_width: float = maxf(
			1.0,
			_vp_size.x - party_safe_left - party_safe_right - (HUD_MARGIN * 2.0)
		)
		var party_width: float = minf(
			520.0,
			party_available_width
			if is_mobile_layout
			else maxf(1.0, _vp_size.x - 420.0)
		)
		var party_y: float = _hud_top_margin()
		if is_mobile_layout and status_container != null:
			party_y = status_container.position.y + status_container.size.y + HUD_MARGIN
		party_row.position = Vector2(
			party_safe_left + HUD_MARGIN
			if is_mobile_layout
			else maxf(HUD_MARGIN + 190.0, (_vp_size.x - party_width) * 0.5),
			party_y
		)
		party_row.custom_minimum_size = Vector2(party_width, 0.0)
		party_row.size = Vector2(party_width, party_row.size.y)

	if _online_state_label:
		var online_safe_left: float = _safe_area_inset("left") if is_mobile_layout else 0.0
		var online_safe_right: float = _safe_area_inset("right") if is_mobile_layout else 0.0
		var online_width: float = (
			maxf(1.0, _vp_size.x - online_safe_left - online_safe_right - (HUD_MARGIN * 2.0))
			if is_mobile_layout
			else _online_state_label.custom_minimum_size.x
		)
		_online_state_label.custom_minimum_size = Vector2(online_width, 20.0)
		_online_state_label.size = _online_state_label.custom_minimum_size
		_online_state_label.position = Vector2(
			online_safe_left + HUD_MARGIN
			if is_mobile_layout
			else maxf(HUD_MARGIN + 200.0, (_vp_size.x - online_width) * 0.5),
			(party_row.position.y + 38.0) if is_mobile_layout and party_row != null else (_hud_top_margin() + 38.0)
		)

	if log_container:
		_layout_game_log(log_container, status_container, party_row)

	if _minimap:
		_minimap.visible = not is_mobile_layout
		if _minimap.visible:
			_minimap.position = Vector2(_vp_size.x - _minimap.size.x - 10.0, 28.0)

	if _toolbar_bar:
		_toolbar_bar.set_compact_mode(is_mobile_layout)
		if _toolbar_bar.has_method("set_available_width"):
			_toolbar_bar.set_available_width(toolbar.size.x if toolbar != null else _vp_size.x)

	_layout_toolbar()
	_refresh_status_overlay()


func _layout_game_log(log_container: Control, status_container: Control, party_row: Control) -> void:
	var is_mobile_layout: bool = _is_mobile_layout()
	var safe_left: float = _safe_area_inset("left") if is_mobile_layout else 0.0
	var safe_right: float = _safe_area_inset("right") if is_mobile_layout else 0.0
	var log_width: float = minf(
		300.0,
		_vp_size.x - safe_left - safe_right - (HUD_MARGIN * 2.0)
	)
	var desired_log_height: float = 74.0 if _is_mobile_portrait_layout() else (96.0 if is_mobile_layout else 195.0)
	var log_height: float = desired_log_height
	var log_y: float = _toolbar_top_y() - log_height - HUD_MARGIN
	if is_mobile_layout:
		var top_controls_bottom: float = 0.0
		if status_container != null:
			top_controls_bottom = maxf(top_controls_bottom, status_container.position.y + status_container.size.y)
		if party_row != null:
			top_controls_bottom = maxf(top_controls_bottom, party_row.position.y + maxf(34.0, party_row.size.y))
		if _online_state_label != null:
			top_controls_bottom = maxf(top_controls_bottom, _online_state_label.position.y + _online_state_label.size.y)
		var available_height: float = _toolbar_top_y() - top_controls_bottom - (HUD_MARGIN * 2.0)
		if available_height > 0.0:
			log_height = minf(desired_log_height, available_height)
		log_y = maxf(top_controls_bottom + HUD_MARGIN, _toolbar_top_y() - log_height - HUD_MARGIN)
	log_container.custom_minimum_size = Vector2(log_width, log_height)
	log_container.size = Vector2(log_width, log_height)
	log_container.position = Vector2(safe_left + HUD_MARGIN, log_y)


func _layout_status_overlay(status_container: Control) -> void:
	if _status_overlay == null or status_container == null:
		return
	var inset: Vector2 = Vector2(10.0, 8.0)
	_status_overlay.visible = true
	_status_overlay.position = status_container.position + inset
	_status_overlay.custom_minimum_size = Vector2(
		maxf(1.0, status_container.size.x - (inset.x * 2.0)),
		maxf(1.0, status_container.size.y - (inset.y * 2.0))
	)
	_status_overlay.size = _status_overlay.custom_minimum_size
	var is_mobile_layout: bool = _is_mobile_layout()
	var is_portrait_mobile: bool = _is_mobile_portrait_layout()
	if _status_level_label:
		_status_level_label.custom_minimum_size = Vector2(50.0 if is_mobile_layout else 62.0, 0.0)
		_status_level_label.add_theme_font_size_override("font_size", 17 if is_mobile_layout else 17)
	if _status_hp_label:
		_status_hp_label.custom_minimum_size = Vector2(60.0 if is_mobile_layout else 68.0, 0.0)
		_status_hp_label.add_theme_font_size_override("font_size", 14 if is_mobile_layout else 13)
	if _status_xp_label:
		_status_xp_label.custom_minimum_size = Vector2(60.0 if is_mobile_layout else 68.0, 0.0)
		_status_xp_label.add_theme_font_size_override("font_size", 13 if is_mobile_layout else 12)
	if _status_depth_label:
		_status_depth_label.custom_minimum_size = Vector2(46.0 if is_mobile_layout else 54.0, 0.0)
		_status_depth_label.add_theme_font_size_override("font_size", 14 if is_mobile_layout else 13)
	if _status_str_label:
		_status_str_label.visible = not is_portrait_mobile
		_status_str_label.custom_minimum_size = Vector2(58.0 if is_mobile_layout else 70.0, 0.0)
		_status_str_label.add_theme_font_size_override("font_size", 13 if is_mobile_layout else 13)


func _layout_toolbar() -> void:
	if toolbar == null:
		return
	var safe_left: float = _safe_area_inset("left")
	var safe_right: float = _safe_area_inset("right")
	var height: float = float(_toolbar_height())
	var width: float = maxf(1.0, _vp_size.x - safe_left - safe_right)
	toolbar.position = Vector2(safe_left, _toolbar_top_y())
	toolbar.custom_minimum_size = Vector2(width, height)
	toolbar.size = Vector2(width, height)
	if _toolbar_bar != null and _toolbar_bar.has_method("set_available_width"):
		_toolbar_bar.set_available_width(width)


func _toolbar_top_y() -> float:
	return _vp_size.y - float(_toolbar_height()) - _safe_area_inset("bottom")


func _refresh_status_overlay() -> void:
	var hero_ref: Variant = _get_local_hero()
	if hero_ref == null:
		return
	var hp: int = int(ConstantsData.get_prop(hero_ref, "hp", 0))
	var hp_max: int = max(1, int(ConstantsData.get_prop(hero_ref, "hp_max", 1)))
	var shield: int = int(ConstantsData.get_prop(hero_ref, "shielding", 0))
	if hero_ref.has_method("total_shielding"):
		shield = int(hero_ref.total_shielding())
	var xp: int = int(ConstantsData.get_prop(hero_ref, "xp", 0))
	var xp_max: int = max(1, int(ConstantsData.get_prop(hero_ref, "xp_to_next", 1)))
	var hero_level: int = int(ConstantsData.get_prop(hero_ref, "hero_level", 1))
	var str_val: int = int(ConstantsData.get_prop(hero_ref, "str_val", 10))
	if _status_level_label:
		_status_level_label.text = "Lv.%d" % hero_level
	if _status_hp_bar:
		_status_hp_bar.max_value = hp_max
		_status_hp_bar.value = clampi(hp, 0, hp_max)
	if _status_shield_bar:
		_status_shield_bar.max_value = hp_max
		_status_shield_bar.value = clampi(hp + shield, 0, hp_max)
	if _status_hp_label:
		_status_hp_label.text = "%d/%d" % [hp, hp_max]
	if _status_xp_bar:
		_status_xp_bar.max_value = xp_max
		_status_xp_bar.value = clampi(xp, 0, xp_max)
	if _status_xp_label:
		_status_xp_label.text = "%d/%d" % [xp, xp_max]
	if _status_depth_label:
		var depth_val: int = int(GameManager.depth) if GameManager != null else 1
		_status_depth_label.text = "D%d" % depth_val
	if _status_str_label:
		_status_str_label.text = "STR %d" % str_val


func _is_mobile_layout() -> bool:
	return _is_mobile_web_context() \
			or minf(_vp_size.x, _vp_size.y) <= MOBILE_BREAKPOINT \
					and maxf(_vp_size.x, _vp_size.y) <= MOBILE_WEB_MAX_VIEWPORT \
			or _vp_size.y > _vp_size.x


func _is_mobile_portrait_layout() -> bool:
	return _is_mobile_layout() and _vp_size.y > _vp_size.x


func _toolbar_height() -> int:
	return MOBILE_TOOLBAR_HEIGHT if _is_mobile_layout() else DESKTOP_TOOLBAR_HEIGHT


func _hud_top_margin() -> float:
	if not _is_mobile_layout():
		return HUD_MARGIN
	var fallback_top: float = (
		MOBILE_SAFE_TOP_INSET
		if _is_mobile_portrait_layout()
		else MOBILE_SAFE_LANDSCAPE_TOP_INSET
	)
	return HUD_MARGIN + maxf(fallback_top, _safe_area_inset("top"))


func _is_mobile_web_context() -> bool:
	if OS.get_name() != "Web":
		return false
	if DisplayServer.is_touchscreen_available():
		return true
	if _vp_size.y > _vp_size.x or minf(_vp_size.x, _vp_size.y) <= MOBILE_BREAKPOINT:
		return true
	if maxf(_vp_size.x, _vp_size.y) <= MOBILE_WEB_MAX_VIEWPORT:
		return true
	var js_result: Variant = _eval_browser_mobile_expression()
	return bool(js_result) if js_result is bool else false


func _eval_browser_mobile_expression() -> Variant:
	if OS.get_name() != "Web":
		return false
	return JavaScriptBridge.eval(
		"(function(){return !!(navigator.maxTouchPoints > 0 || " +
		"matchMedia('(pointer: coarse)').matches || " +
		"/Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent));})()",
		true
	)


func _safe_area_inset(edge: String) -> float:
	if OS.get_name() != "Web":
		return 0.0
	var script: String = "(function(edge){" \
			+ "var id='godot-safe-area-probe';" \
			+ "var el=document.getElementById(id);" \
			+ "if(!el){el=document.createElement('div');el.id=id;" \
			+ "el.style.position='fixed';el.style.visibility='hidden';" \
			+ "el.style.pointerEvents='none';document.body.appendChild(el);}" \
			+ "el.style.paddingTop=edge==='top'?'env(safe-area-inset-top)':'0px';" \
			+ "el.style.paddingRight=edge==='right'?'env(safe-area-inset-right)':'0px';" \
			+ "el.style.paddingBottom=edge==='bottom'?'env(safe-area-inset-bottom)':'0px';" \
			+ "el.style.paddingLeft=edge==='left'?'env(safe-area-inset-left)':'0px';" \
			+ "var s=getComputedStyle(el);" \
			+ "var key='padding-'+edge;" \
			+ "return parseFloat(s.getPropertyValue(key))||0;" \
			+ "})('%s')" % edge
	var result: Variant = JavaScriptBridge.eval(script, true)
	return maxf(0.0, float(result)) if result != null else 0.0
