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
const MOBILE_BREAKPOINT: float = 720.0
const HUD_MARGIN: float = 6.0

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
	_apply_responsive_layout()
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
	status_container.position = Vector2(HUD_MARGIN, HUD_MARGIN)
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
	log_container.position = Vector2(HUD_MARGIN, _vp_size.y - TOOLBAR_HEIGHT - 200)
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


# --- Public API ---

## Show a popup window centered on screen.
func show_window(window_node: Control) -> void:
	close_window()
	_active_window = window_node
	_sub_windows.clear()
	# Listen for sub-window requests ("signal up" pattern — avoids get_parent())
	if window_node is WndBase:
		var wnd: WndBase = window_node as WndBase
		wnd.open_sub_window.connect(_on_sub_window_requested)
		# Listen for the window closing itself (X button, Escape) so HUD can clean up
		wnd.window_closed.connect(_on_active_window_self_closed)
	window_layer.add_child(window_node)
	window_layer.visible = true
	window_layer.mouse_filter = Control.MOUSE_FILTER_STOP


## Handle sub-window open requests from active windows.
func _on_sub_window_requested(wnd: WndBase) -> void:
	# Also wire up the sub-window's own sub-window signal
	wnd.open_sub_window.connect(_on_sub_window_requested)
	_sub_windows.append(wnd)
	window_layer.add_child(wnd)


## Called when the active window closes itself (X button, Escape key).
## Cleans up HUD state so input isn't permanently blocked.
func _on_active_window_self_closed() -> void:
	# The window will queue_free itself and its overlay via _finish_close().
	# We just need to reset HUD tracking state.
	for sub_wnd: WndBase in _sub_windows:
		if is_instance_valid(sub_wnd):
			sub_wnd.queue_free()
	_sub_windows.clear()
	_active_window = null
	window_layer.visible = false
	window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	_refresh_quickslots()
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
	var vp: Viewport = get_viewport()
	if vp:
		return vp.get_visible_rect().size
	return Vector2(1280, 720)


func _on_viewport_resized() -> void:
	_vp_size = _get_viewport_size()
	var root_node: Node = get_node_or_null("HUDRoot")
	if not root_node:
		return
	# Reposition toolbar at bottom
	if toolbar:
		toolbar.position = Vector2(0, _vp_size.y - TOOLBAR_HEIGHT)
		toolbar.custom_minimum_size = Vector2(_vp_size.x, TOOLBAR_HEIGHT)
		toolbar.size = Vector2(_vp_size.x, TOOLBAR_HEIGHT)
	_apply_responsive_layout()


# --- EventBus Signal Handlers ---

func _on_stats_changed() -> void:
	_refresh_quickslots()
	if _status_pane:
		_status_pane.update_all()


func _on_level_changed(_new_depth: int) -> void:
	_update_info_row()
	if _status_pane:
		_status_pane.update_all()
	if _minimap and GameManager and GameManager.current_level:
		var lvl: Variant = GameManager.current_level
		var level_map: Array[int] = lvl.map if lvl.get("map") != null else []
		var visited: Array[bool] = lvl.visited if lvl.get("visited") != null else []
		var visible: Array[bool] = lvl.visible if lvl.get("visible") != null else []
		var hero_pos: int = GameManager.hero.pos if GameManager.get("hero") != null else -1
		_minimap.update_map(level_map, visited, visible, hero_pos)


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


# --- Toolbar Signal Handlers ---

func _on_inventory_pressed() -> void:
	var wnd: WndBase = WndInventory.new()
	show_window(wnd)


func _on_map_pressed() -> void:
	# Toggle minimap visibility
	if _minimap:
		_minimap.visible = not _minimap.visible


func _on_wait_pressed() -> void:
	# Gameplay wait input is owned by GameScene so it only fires while hero input is active.
	pass


func _on_rest_pressed() -> void:
	if GameManager == null or GameManager.hero == null or TurnManager == null:
		return
	if not TurnManager.waiting_for_input or TurnManager.processing_mobs:
		return
	if _visible_enemy_present():
		if MessageLog:
			MessageLog.add_warning("You can't rest while enemies are in view.")
		return
	if GameManager.hero.has_method("rest"):
		GameManager.hero.rest(true)


func _on_search_pressed() -> void:
	# Gameplay search input is owned by GameScene so it only fires while hero input is active.
	pass

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
	var wnd: WndBase = WndSettings.new()
	show_window(wnd)


func _on_quickslot_used(slot_index: int, item: RefCounted) -> void:
	if GameManager == null or GameManager.hero == null or item == null:
		return
	if item is Wand:
		var wand: Wand = item as Wand
		if ConstantsData.get_prop(wand, "charges", 0) <= 0:
			if MessageLog:
				MessageLog.add_warning("The %s has no charges left!" % ConstantsData.get_prop(wand, "item_name", "wand"))
			return
		var hero_ref: Hero = GameManager.hero as Hero
		var zap_callback: Callable = func(cell: int) -> void:
			if hero_ref != null and hero_ref.has_method("submit_action"):
				hero_ref.submit_action({"type": "zap_wand", "item": wand, "target_pos": cell})
		if EventBus:
			var max_range: int = ConstantsData.get_prop(wand, "zap_range", 8) if ConstantsData.get_prop(wand, "zap_range") else 8
			EventBus.enter_targeting.emit(wand, max_range, zap_callback)
		return
	if item.has_method("execute"):
		item.execute(GameManager.hero)

func _refresh_quickslots() -> void:
	if _toolbar_bar == null or GameManager == null or GameManager.hero == null:
		return
	var belongings: Variant = GameManager.hero.get("belongings")
	if belongings == null or not belongings.has_method("get_quickslot"):
		return
	for i: int in range(Belongings.QUICKSLOT_COUNT):
		_toolbar_bar.set_quickslot_item(i, belongings.get_quickslot(i))


func _apply_responsive_layout() -> void:
	var root_node: Control = get_node_or_null("HUDRoot") as Control
	if root_node == null:
		return

	var is_mobile_layout: bool = _vp_size.x <= MOBILE_BREAKPOINT or _vp_size.y > _vp_size.x
	var status_container: Control = root_node.get_node_or_null("StatusContainer") as Control
	var log_container: Control = root_node.get_node_or_null("GameLog") as Control
	var info_row: Control = root_node.get_node_or_null("InfoRow") as Control

	if status_container:
		status_container.position = Vector2(HUD_MARGIN, HUD_MARGIN)
		status_container.custom_minimum_size = Vector2(180 if is_mobile_layout else 220, 140)

	if log_container:
		var log_width: float = minf(300.0, _vp_size.x - (HUD_MARGIN * 2.0))
		var log_height: float = 132.0 if is_mobile_layout else 195.0
		log_container.custom_minimum_size = Vector2(log_width, log_height)
		log_container.size = Vector2(log_width, log_height)
		log_container.position = Vector2(HUD_MARGIN, _vp_size.y - TOOLBAR_HEIGHT - log_height - HUD_MARGIN)

	if info_row:
		var info_width: float = 180.0
		info_row.position = Vector2(maxf(HUD_MARGIN, _vp_size.x - info_width - HUD_MARGIN), HUD_MARGIN)

	if _minimap:
		_minimap.visible = not is_mobile_layout
		if _minimap.visible:
			_minimap.position = Vector2(_vp_size.x - _minimap.size.x - 10.0, 28.0)

	if _toolbar_bar:
		_toolbar_bar.set_compact_mode(is_mobile_layout)
