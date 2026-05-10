class_name LobbyScene
extends Control
## Minimal synchronized pre-game lobby for online co-op.
## Shows connected players, ready state, and host-owned start control.

# --- Shared title background layers ---
var _bg_color_rect: ColorRect = null
var _back_clusters_sprite: TextureRect = null
var _mid_mixed_sprite: TextureRect = null
var _archs_sprite: TextureRect = null

var _status_label: Label = null
var _players_label: RichTextLabel = null
var _ready_button: Button = null
var _start_button: Button = null
var _join_code_label: Label = null
var _settings_panel: PanelContainer = null
var _settings_name_edit: LineEdit = null
var _settings_port_edit: LineEdit = null
var _settings_players_edit: LineEdit = null
var _main_panel: PanelContainer = null

const BACK_CLUSTERS_PATH: String = "res://assets/spd/splashes/title/back_clusters.png"
const MID_MIXED_PATH: String = "res://assets/spd/splashes/title/mid_mixed.png"
const ARCHS_PATH: String = "res://assets/spd/splashes/title/archs.png"
const PANEL_SIZE: Vector2 = Vector2(760, 500)
const SETTINGS_PANEL_SIZE: Vector2 = Vector2(460, 260)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RenderingServer.set_default_clear_color(Color.BLACK)
	_build_background()
	_build_ui()
	_apply_layout()
	_refresh()
	if NetworkManager:
		if NetworkManager.has_signal("lobby_updated"):
			NetworkManager.lobby_updated.connect(_refresh)
		if NetworkManager.has_signal("session_state_changed"):
			NetworkManager.session_state_changed.connect(_refresh)
		if NetworkManager.has_signal("disconnected"):
			NetworkManager.disconnected.connect(_on_network_disconnected)
		if NetworkManager.has_signal("lobby_start_requested"):
			NetworkManager.lobby_start_requested.connect(_on_lobby_start_requested)
		if NetworkManager.has_signal("online_run_start_requested"):
			NetworkManager.online_run_start_requested.connect(_on_online_run_start_requested)
	get_viewport().size_changed.connect(_apply_layout)

func _process(_delta: float) -> void:
	var time_elapsed: float = float(Time.get_ticks_msec()) * 0.001
	if _back_clusters_sprite:
		_back_clusters_sprite.position.x = -fmod(time_elapsed * 2.0, 512.0)
	if _mid_mixed_sprite:
		_mid_mixed_sprite.position.x = -fmod(time_elapsed * 5.0, 2048.0)
	if _archs_sprite:
		_archs_sprite.position.x = -fmod(time_elapsed * 10.0, 1024.0)

func _build_background() -> void:
	_bg_color_rect = ColorRect.new()
	_bg_color_rect.color = Color(0.07, 0.06, 0.1)
	_bg_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_color_rect)

	var clusters_tex: Texture2D = _load_texture(BACK_CLUSTERS_PATH)
	if clusters_tex:
		_back_clusters_sprite = TextureRect.new()
		_back_clusters_sprite.texture = clusters_tex
		_back_clusters_sprite.stretch_mode = TextureRect.STRETCH_TILE
		_back_clusters_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_back_clusters_sprite.modulate = Color(0.25, 0.22, 0.2, 0.5)
		_back_clusters_sprite.position = Vector2(0, 0)
		_back_clusters_sprite.size = Vector2(1280 + 512, 720)
		add_child(_back_clusters_sprite)

	var mid_tex: Texture2D = _load_texture(MID_MIXED_PATH)
	if mid_tex:
		_mid_mixed_sprite = TextureRect.new()
		_mid_mixed_sprite.texture = mid_tex
		_mid_mixed_sprite.stretch_mode = TextureRect.STRETCH_TILE
		_mid_mixed_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_mid_mixed_sprite.modulate = Color(0.35, 0.3, 0.28, 0.55)
		_mid_mixed_sprite.position = Vector2(0, 100)
		_mid_mixed_sprite.size = Vector2(1280 + 2048, 620)
		add_child(_mid_mixed_sprite)

	var archs_tex: Texture2D = _load_texture(ARCHS_PATH)
	if archs_tex:
		_archs_sprite = TextureRect.new()
		_archs_sprite.texture = archs_tex
		_archs_sprite.stretch_mode = TextureRect.STRETCH_TILE
		_archs_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_archs_sprite.modulate = Color(0.45, 0.4, 0.35, 0.7)
		_archs_sprite.position = Vector2(0, 720 - 256)
		_archs_sprite.size = Vector2(1280 + 1024, 256)
		add_child(_archs_sprite)

	var top_overlay: ColorRect = ColorRect.new()
	top_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_mat: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	float fade = smoothstep(0.0, 0.5, UV.y);
	COLOR = vec4(0.0, 0.0, 0.0, 0.55 * (1.0 - fade));
}
"""
	shader_mat.shader = shader
	top_overlay.material = shader_mat
	add_child(top_overlay)

func _build_ui() -> void:
	var panel: PanelContainer = PanelContainer.new()
	_main_panel = panel
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.11, 0.9)
	style.border_color = Color(0.48, 0.42, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Co-op Lobby"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	vbox.add_child(title)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	vbox.add_child(_status_label)

	_join_code_label = Label.new()
	_join_code_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_join_code_label.add_theme_font_size_override("font_size", 13)
	_join_code_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(_join_code_label)

	_players_label = RichTextLabel.new()
	_players_label.bbcode_enabled = true
	_players_label.fit_content = true
	_players_label.custom_minimum_size = Vector2(0, 220)
	_players_label.add_theme_color_override("default_color", Color(0.82, 0.84, 0.9))
	vbox.add_child(_players_label)

	var button_row: GridContainer = GridContainer.new()
	button_row.columns = 3
	button_row.add_theme_constant_override("h_separation", 10)
	button_row.add_theme_constant_override("v_separation", 10)
	vbox.add_child(button_row)

	_ready_button = Button.new()
	_ready_button.text = "Ready"
	_ready_button.custom_minimum_size = Vector2(180, 42)
	_ready_button.pressed.connect(_on_ready_pressed)
	button_row.add_child(_ready_button)

	_start_button = Button.new()
	_start_button.text = "Start Run"
	_start_button.custom_minimum_size = Vector2(180, 42)
	_start_button.pressed.connect(_on_start_pressed)
	button_row.add_child(_start_button)

	var leave_button: Button = Button.new()
	leave_button.text = "Leave Lobby"
	leave_button.custom_minimum_size = Vector2(180, 42)
	leave_button.pressed.connect(_on_leave_pressed)
	button_row.add_child(leave_button)

	var settings_button: Button = Button.new()
	settings_button.text = "Settings"
	settings_button.custom_minimum_size = Vector2(180, 42)
	settings_button.pressed.connect(_on_settings_pressed)
	button_row.add_child(settings_button)

	var copy_code_button: Button = Button.new()
	copy_code_button.text = "Copy Join Code"
	copy_code_button.custom_minimum_size = Vector2(180, 42)
	copy_code_button.pressed.connect(_on_copy_join_code_pressed)
	button_row.add_child(copy_code_button)

	var note: Label = Label.new()
	note.text = "Host creates the session and starts the run. Clients join, ready up, and wait for the host to proceed."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.65, 0.7, 0.76))
	vbox.add_child(note)

	_settings_panel = PanelContainer.new()
	_settings_panel.visible = false
	_settings_panel.custom_minimum_size = SETTINGS_PANEL_SIZE
	_settings_panel.size = SETTINGS_PANEL_SIZE
	var settings_style: StyleBoxFlat = StyleBoxFlat.new()
	settings_style.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	settings_style.border_color = Color(0.45, 0.5, 0.6)
	settings_style.set_border_width_all(2)
	settings_style.set_corner_radius_all(8)
	settings_style.set_content_margin_all(16)
	_settings_panel.add_theme_stylebox_override("panel", settings_style)
	panel.add_child(_settings_panel)

	var settings_vbox: VBoxContainer = VBoxContainer.new()
	settings_vbox.add_theme_constant_override("separation", 10)
	_settings_panel.add_child(settings_vbox)

	var settings_title: Label = Label.new()
	settings_title.text = "Lobby Settings"
	settings_title.add_theme_font_size_override("font_size", 20)
	settings_vbox.add_child(settings_title)

	var settings_name_label: Label = Label.new()
	settings_name_label.text = "Player Name"
	settings_vbox.add_child(settings_name_label)

	_settings_name_edit = LineEdit.new()
	settings_vbox.add_child(_settings_name_edit)

	var settings_port_label: Label = Label.new()
	settings_port_label.text = "Host Port"
	settings_vbox.add_child(settings_port_label)

	_settings_port_edit = LineEdit.new()
	_settings_port_edit.placeholder_text = "41234"
	settings_vbox.add_child(_settings_port_edit)

	var settings_players_label: Label = Label.new()
	settings_players_label.text = "Player Cap"
	settings_vbox.add_child(settings_players_label)

	_settings_players_edit = LineEdit.new()
	_settings_players_edit.placeholder_text = "4"
	settings_vbox.add_child(_settings_players_edit)

	var settings_buttons: HBoxContainer = HBoxContainer.new()
	settings_buttons.add_theme_constant_override("separation", 8)
	settings_vbox.add_child(settings_buttons)

	var apply_settings_button: Button = Button.new()
	apply_settings_button.text = "Apply"
	apply_settings_button.custom_minimum_size = Vector2(140, 38)
	apply_settings_button.pressed.connect(_on_apply_settings_pressed)
	settings_buttons.add_child(apply_settings_button)

	var close_settings_button: Button = Button.new()
	close_settings_button.text = "Close"
	close_settings_button.custom_minimum_size = Vector2(140, 38)
	close_settings_button.pressed.connect(func() -> void: _settings_panel.visible = false)
	settings_buttons.add_child(close_settings_button)

func _apply_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if _main_panel != null:
		_main_panel.position = Vector2(
			floor((viewport_size.x - PANEL_SIZE.x) * 0.5),
			110
		)
	if _settings_panel != null and _main_panel != null:
		_settings_panel.position = Vector2(
			floor((_main_panel.size.x - SETTINGS_PANEL_SIZE.x) * 0.5),
			80
		)

func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _refresh() -> void:
	if _status_label == null or _players_label == null:
		return
	if NetworkManager:
		var phase_label: String = NetworkManager.get_session_phase_label() if NetworkManager.has_method("get_session_phase_label") else ""
		_status_label.text = NetworkManager.get_connection_label()
		if not phase_label.is_empty():
			_status_label.text += "\n" + phase_label
		if NetworkManager.has_method("get_ready_summary"):
			_status_label.text += "\n" + NetworkManager.get_ready_summary()
	else:
		_status_label.text = "Offline"
	if _join_code_label:
		if NetworkManager and NetworkManager.has_method("is_host") and NetworkManager.is_host() and NetworkManager.has_method("build_join_code"):
			_join_code_label.text = "Join Code: %s" % NetworkManager.build_join_code()
		else:
			_join_code_label.text = ""

	var lines: Array[String] = []
	var players: Array = NetworkManager.get_lobby_players() if NetworkManager else []
	var local_peer_id: int = NetworkManager.get_local_peer_id() if NetworkManager and NetworkManager.has_method("get_local_peer_id") else 1
	for player_entry: Variant in players:
		if not player_entry is Dictionary:
			continue
		var entry: Dictionary = player_entry
		var peer_id: int = int(entry.get("peer_id", -1))
		var player_name: String = str(entry.get("name", "Player"))
		var ready: bool = bool(entry.get("ready", false))
		var host_suffix: String = " [Host]" if peer_id == 1 else ""
		var local_suffix: String = " [You]" if peer_id == local_peer_id else ""
		var ready_text: String = "Ready" if ready else "Not Ready"
		lines.append("P%d %s%s%s - %s" % [peer_id, player_name, host_suffix, local_suffix, ready_text])
	if lines.is_empty():
		lines.append("Waiting for players...")
	_players_label.text = "\n".join(lines)

	var is_host: bool = NetworkManager != null and NetworkManager.has_method("is_host") and NetworkManager.is_host()
	var is_ready: bool = NetworkManager != null and NetworkManager.has_method("is_local_ready") and NetworkManager.is_local_ready()
	var run_active: bool = NetworkManager != null and NetworkManager.has_method("has_active_run") and NetworkManager.has_active_run()
	if _ready_button:
		_ready_button.text = "Unready" if is_ready else "Ready"
		_ready_button.visible = not run_active
	if _start_button:
		_start_button.visible = is_host
		if run_active:
			_start_button.text = "Run Active"
		elif NetworkManager and NetworkManager.has_method("get_ready_summary"):
			_start_button.text = "Start Run (%s)" % NetworkManager.get_ready_summary()
		else:
			_start_button.text = "Start Run"
		_start_button.disabled = run_active or not (NetworkManager != null and NetworkManager.has_method("can_host_start_run") and NetworkManager.can_host_start_run())
		if not run_active and _start_button.disabled:
			_start_button.tooltip_text = "All connected players must be ready before the host can start."
		else:
			_start_button.tooltip_text = ""
	if _settings_name_edit and NetworkManager:
		_settings_name_edit.text = NetworkManager.local_player_name
	if _settings_port_edit and NetworkManager:
		_settings_port_edit.text = str(NetworkManager.listen_port if NetworkManager.listen_port > 0 else NetworkManager.DEFAULT_PORT)
	if _settings_players_edit and NetworkManager:
		_settings_players_edit.text = str(NetworkManager.max_players if NetworkManager.max_players > 0 else NetworkManager.DEFAULT_MAX_PLAYERS)
	if _settings_port_edit:
		_settings_port_edit.editable = is_host
	if _settings_players_edit:
		_settings_players_edit.editable = is_host

func _on_ready_pressed() -> void:
	if NetworkManager and not (NetworkManager.has_method("has_active_run") and NetworkManager.has_active_run()):
		NetworkManager.set_local_ready(not NetworkManager.is_local_ready())

func _on_start_pressed() -> void:
	if NetworkManager and NetworkManager.has_method("has_active_run") and NetworkManager.has_active_run():
		return
	if NetworkManager and NetworkManager.request_lobby_start():
		return

func _on_leave_pressed() -> void:
	if NetworkManager:
		NetworkManager.close_session("Left lobby.")
	var title_script: GDScript = load("res://src/scenes/title_scene.gd") as GDScript
	if title_script:
		SceneManager.go_to(title_script, "TitleScene")

func _on_settings_pressed() -> void:
	if _settings_panel:
		_settings_panel.visible = true
	_refresh()

func _on_apply_settings_pressed() -> void:
	if NetworkManager == null:
		return
	if _settings_name_edit:
		NetworkManager.set_local_player_name(_settings_name_edit.text)
	var is_host: bool = NetworkManager.has_method("is_host") and NetworkManager.is_host()
	if is_host:
		var port: int = int(_settings_port_edit.text) if _settings_port_edit and not _settings_port_edit.text.strip_edges().is_empty() else NetworkManager.DEFAULT_PORT
		var player_cap: int = int(_settings_players_edit.text) if _settings_players_edit and not _settings_players_edit.text.strip_edges().is_empty() else NetworkManager.DEFAULT_MAX_PLAYERS
		player_cap = clampi(player_cap, 1, GameManager.MAX_PARTY_SIZE if GameManager else NetworkManager.DEFAULT_MAX_PLAYERS)
		if port <= 0:
			port = NetworkManager.DEFAULT_PORT
		if port != NetworkManager.listen_port or player_cap != NetworkManager.max_players:
			NetworkManager.host_game(port, player_cap)
			if MessageLog:
				MessageLog.add("Lobby restarted with updated host settings.")
	if _settings_panel:
		_settings_panel.visible = false
	_refresh()

func _on_copy_join_code_pressed() -> void:
	if NetworkManager == null or not NetworkManager.has_method("build_join_code"):
		return
	var join_code: String = NetworkManager.build_join_code()
	DisplayServer.clipboard_set(join_code)
	if MessageLog:
		MessageLog.add_positive("Copied join code: %s" % join_code)

func _on_lobby_start_requested() -> void:
	if NetworkManager and NetworkManager.is_host():
		var hero_select_script: GDScript = load("res://src/scenes/hero_select_scene.gd") as GDScript
		if hero_select_script:
			SceneManager.go_to(hero_select_script, "HeroSelectScene")
	else:
		_refresh()

func _on_online_run_start_requested(config: Dictionary) -> void:
	var loading_script: GDScript = load("res://src/scenes/loading_scene.gd") as GDScript
	if loading_script == null:
		return
	SceneManager.go_to(loading_script, "LoadingScene", config)

func _on_network_disconnected(reason: String) -> void:
	if reason != "Disconnected from host.":
		return
	if MessageLog:
		MessageLog.add_warning("Lost connection to host.")
	var title_script: GDScript = load("res://src/scenes/title_scene.gd") as GDScript
	if title_script:
		SceneManager.go_to(title_script, "TitleScene")
