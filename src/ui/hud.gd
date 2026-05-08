class_name HUD
extends CanvasLayer
## Main HUD controller matching the original SPD layout:
##   - Status pane (top-left): hero avatar, HP/EXP bars, level, depth, buffs
##   - Floating game log (bottom-left): fades over time, not a permanent panel
##   - Toolbar (bottom): inventory, quickslots, wait, search, settings
##   - Minimap (top-right, togglable)
##   - No sidebars — game world fills the screen

# --- Constants ---
const TOOLBAR_HEIGHT: int = 40

# --- Child panels ---
var toolbar: MarginContainer = null
var window_layer: Control = null

# --- Sub-components ---
var _status_pane: StatusPane = null
var _toolbar_bar: Toolbar = null
var _game_log_display: GameLogDisplay = null
var _boss_hp_bar: BossHPBar = null
var _minimap: Minimap = null

# --- Active popup window ---
var _active_window: Control = null
# Track sub-windows so they can be cleaned up properly
var _sub_windows: Array[WndBase] = []

# --- Viewport size cache ---
var _vp_size: Vector2 = Vector2(1280, 720)


func _ready() -> void:
	layer = 10
	_vp_size = _get_viewport_size()
	_build_layout()
	_connect_signals()
	update_all()
	# Re-layout when viewport resizes
	get_viewport().size_changed.connect(_on_viewport_resized)


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
	status_container.position = Vector2(0, 0)
	status_container.custom_minimum_size = Vector2(220, 140)
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
	_status_pane = StatusPane.new()
	status_container.add_child(_status_pane)
	root.add_child(status_container)

	# --- Game Log (bottom-left, floating over game world) ---
	var log_container: MarginContainer = MarginContainer.new()
	log_container.name = "GameLog"
	log_container.position = Vector2(4, _vp_size.y - TOOLBAR_HEIGHT - 200)
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
	_game_log_display = GameLogDisplay.new()
	_game_log_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_panel.add_child(_game_log_display)
	log_container.add_child(log_panel)
	root.add_child(log_container)

	# --- Toolbar (bottom, full width) ---
	toolbar = MarginContainer.new()
	toolbar.name = "Toolbar"
	toolbar.position = Vector2(0, _vp_size.y - TOOLBAR_HEIGHT)
	toolbar.custom_minimum_size = Vector2(_vp_size.x, TOOLBAR_HEIGHT)
	toolbar.size = Vector2(_vp_size.x, TOOLBAR_HEIGHT)
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
	_toolbar_bar = Toolbar.new()
	toolbar_panel.add_child(_toolbar_bar)
	toolbar.add_child(toolbar_panel)
	root.add_child(toolbar)

	# --- Depth / Gold info (top-right, beside minimap) ---
	var info_row: HBoxContainer = HBoxContainer.new()
	info_row.name = "InfoRow"
	info_row.add_theme_constant_override("separation", 16)
	info_row.position = Vector2(_vp_size.x - 260, 6)
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

	# --- Minimap (top-right corner, below info row) ---
	_minimap = Minimap.new()
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
	_boss_hp_bar = BossHPBar.new()
	_boss_hp_bar.name = "BossHPBar"
	add_child(_boss_hp_bar)


func _connect_signals() -> void:
	var event_bus: Node = UIUtils.get_event_bus()
	if event_bus:
		event_bus.hero_stats_changed.connect(_on_stats_changed)
		event_bus.level_changed.connect(_on_level_changed)
		event_bus.gold_collected.connect(_on_gold_collected)
		event_bus.hero_moved.connect(_on_hero_moved)
		# Boss fight signals (now defined in EventBus)
		event_bus.boss_fight_started.connect(_on_boss_fight_started)
		event_bus.boss_damaged.connect(_on_boss_damaged)
		event_bus.boss_defeated.connect(_on_boss_defeated)

	if _toolbar_bar:
		_toolbar_bar.inventory_pressed.connect(_on_inventory_pressed)
		_toolbar_bar.map_pressed.connect(_on_map_pressed)
		_toolbar_bar.wait_pressed.connect(_on_wait_pressed)
		_toolbar_bar.rest_pressed.connect(_on_rest_pressed)
		_toolbar_bar.search_pressed.connect(_on_search_pressed)
		_toolbar_bar.settings_pressed.connect(_on_settings_pressed)
		_toolbar_bar.quickslot_used.connect(_on_quickslot_used)


# --- Public API ---

## Show a popup window centered on screen.
func show_window(window_node: Control) -> void:
	close_window()
	_active_window = window_node
	_sub_windows.clear()
	# Listen for sub-window requests ("signal up" pattern — avoids get_parent())
	if window_node is WndBase:
		(window_node as WndBase).open_sub_window.connect(_on_sub_window_requested)
	window_layer.add_child(window_node)
	window_node.set_anchors_preset(Control.PRESET_CENTER)
	window_layer.visible = true
	window_layer.mouse_filter = Control.MOUSE_FILTER_STOP


## Handle sub-window open requests from active windows.
func _on_sub_window_requested(wnd: WndBase) -> void:
	# Also wire up the sub-window's own sub-window signal
	wnd.open_sub_window.connect(_on_sub_window_requested)
	_sub_windows.append(wnd)
	window_layer.add_child(wnd)
	wnd.set_anchors_preset(Control.PRESET_CENTER)


## Close the active popup window and all sub-windows.
func close_window() -> void:
	# Clean up tracked sub-windows first
	for sub_wnd: WndBase in _sub_windows:
		if is_instance_valid(sub_wnd):
			sub_wnd.queue_free()
	_sub_windows.clear()
	if _active_window and is_instance_valid(_active_window):
		_active_window.queue_free()
		_active_window = null
	window_layer.visible = false
	window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Force update all HUD elements.
func update_all() -> void:
	_update_info_row()
	if _status_pane:
		_status_pane.update_all()
	if _game_log_display:
		_game_log_display.refresh()


# --- Info Row Updates ---

func _update_info_row() -> void:
	pass
	
