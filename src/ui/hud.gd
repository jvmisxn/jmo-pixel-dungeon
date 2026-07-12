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
var _status_pane: Variant = null
var _toolbar_bar: Variant = null
var _game_log_display: Variant = null
var _boss_hp_bar: Variant = null
var _minimap: Variant = null
var _party_row: HBoxContainer = null
var _online_state_label: Label = null

# --- Active popup window ---
var _active_window: Control = null
# Track sub-windows so they can be cleaned up properly
var _sub_windows: Array[Variant] = []

# --- Viewport size cache ---
var _vp_size: Vector2 = Vector2(1280, 720)

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
	_status_pane = _instantiate_script("res://src/ui/status_pane.gd")
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
	_game_log_display = _instantiate_script("res://src/ui/game_log_display.gd")
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
		wnd.open_sub_window.connect(_on_sub_window_requested)
		if wnd.has_signal("window_closed"):
			wnd.window_closed.connect(_on_active_window_self_closed)
	window_layer.add_child(window_node)
	window_layer.visible = true
	window_layer.mouse_filter = Control.MOUSE_FILTER_STOP


## Handle sub-window open requests from active windows.
func _on_sub_window_requested(wnd: Variant) -> void:
	# Also wire up the sub-window's own sub-window signal
	wnd.open_sub_window.connect(_on_sub_window_requested)
	_sub_windows.append(wnd)
	window_layer.add_child(wnd)


## Called when the active window closes itself (X button, Escape key).
## Cleans up HUD state so input isn't permanently blocked.
func _on_active_window_self_closed() -> void:
	# The window will queue_free itself and its overlay via _finish_close().
	# We just need to reset HUD tracking state.
	for sub_wnd: Variant in _sub_windows:
		if is_instance_valid(sub_wnd):
			sub_wnd.queue_free()
	_sub_windows.clear()
	_active_window = null
	window_layer.visible = false
	window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Close the active popup window and all sub-windows.
func close_window() -> void:
	# Clean up tracked sub-windows first
	for sub_wnd: Variant in _sub_windows:
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
	_refresh_party_row()
	_refresh_online_state()
	_refresh_action_controls()
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
		var visible_cells: Array[bool] = lvl.visible if lvl.get("visible") != null else []
		var hero_ref: Variant = _get_local_hero()
		var hero_pos: int = hero_ref.pos if hero_ref != null else -1
		var mob_positions: Array[int] = []
		var party_positions: Array[int] = []
		if GameManager.has_method("get_active_heroes"):
			for party_hero: Node in GameManager.get_active_heroes():
				if party_hero != null:
					party_positions.append(int(party_hero.pos))
		_minimap.update_map(level_map, visited, visible_cells, hero_pos, mob_positions, party_positions)


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
	var focused_hero: Variant = _get_local_hero()
	var local_owned_hero: Variant = _get_local_owned_hero()
	var input_hero: Variant = _get_input_hero()
	for idx: int in range(heroes.size()):
		var hero_ref: Node = heroes[idx]
		if hero_ref == null:
			continue
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(104, 34)
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

	var is_mobile_layout: bool = _vp_size.x <= MOBILE_BREAKPOINT or _vp_size.y > _vp_size.x
	var status_container: Control = root_node.get_node_or_null("StatusContainer") as Control
	var log_container: Control = root_node.get_node_or_null("GameLog") as Control
	var info_row: Control = root_node.get_node_or_null("InfoRow") as Control
	var party_row: Control = root_node.get_node_or_null("PartyRow") as Control

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

	if party_row:
		var party_width: float = minf(520.0, _vp_size.x - 420.0)
		party_row.position = Vector2(
			maxf(HUD_MARGIN + 190.0, (_vp_size.x - party_width) * 0.5),
			HUD_MARGIN if not is_mobile_layout else HUD_MARGIN + 146.0
		)

	if _online_state_label:
		_online_state_label.position = Vector2(
			maxf(HUD_MARGIN + 200.0, (_vp_size.x - _online_state_label.custom_minimum_size.x) * 0.5),
			(HUD_MARGIN + 38.0) if not is_mobile_layout else (HUD_MARGIN + 182.0)
		)

	if _minimap:
		_minimap.visible = not is_mobile_layout
		if _minimap.visible:
			_minimap.position = Vector2(_vp_size.x - _minimap.size.x - 10.0, 28.0)

	if _toolbar_bar:
		_toolbar_bar.set_compact_mode(is_mobile_layout)
