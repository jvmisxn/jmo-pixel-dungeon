class_name TitleScene
extends Control
## Title screen using original SPD assets — parallax dungeon background,
## banner logo, and styled menu buttons with chrome UI.

# --- UI References ---
var _btn_new_game: Button = null
var _btn_continue: Button = null
var _btn_host_game: Button = null
var _btn_join_game: Button = null
var _btn_rankings: Button = null
var _btn_settings: Button = null
var _btn_about: Button = null
var _about_panel: PanelContainer = null
var _network_panel: PanelContainer = null
var _settings_window: Variant = null
var _network_status_label: Label = null
var _network_name_edit: LineEdit = null
var _network_join_code_edit: LineEdit = null
var _network_address_edit: LineEdit = null
var _network_port_edit: LineEdit = null
var _network_players_edit: LineEdit = null
var _buttons: Array[Button] = []
var _selected_index: int = 0

# --- Background layers (parallax) ---
var _bg_color_rect: ColorRect = null
var _back_clusters_sprite: TextureRect = null
var _mid_mixed_sprite: TextureRect = null
var _archs_sprite: TextureRect = null

# --- Animation ---

# --- Scene Paths ---
const HERO_SELECT_SCENE_PATH: String = "res://src/scenes/hero_select_scene.gd"
const LOBBY_SCENE_PATH: String = "res://src/scenes/lobby_scene.gd"
var _rankings_scene: GDScript = preload("res://src/scenes/rankings_scene.gd")

# --- Asset paths ---
const BACK_CLUSTERS_PATH: String = "res://assets/spd/splashes/title/back_clusters.png"
const MID_MIXED_PATH: String = "res://assets/spd/splashes/title/mid_mixed.png"
const ARCHS_PATH: String = "res://assets/spd/splashes/title/archs.png"
const CHROME_PATH: String = "res://assets/spd/interfaces/chrome.png"

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RenderingServer.set_default_clear_color(Color.BLACK)
	_build_background()
	_build_ui()
	_update_button_focus()
	_refresh_network_status()
	if NetworkManager:
		if NetworkManager.has_signal("session_state_changed"):
			NetworkManager.session_state_changed.connect(_refresh_network_status)
		if NetworkManager.has_signal("join_failed"):
			NetworkManager.join_failed.connect(_on_network_join_failed)
		if NetworkManager.has_signal("hosting_started"):
			NetworkManager.hosting_started.connect(_on_network_hosting_started)
		if NetworkManager.has_signal("connected_to_host"):
			NetworkManager.connected_to_host.connect(_on_network_connected_to_host)
		if NetworkManager.has_signal("disconnected"):
			NetworkManager.disconnected.connect(_on_network_disconnected)
	# Play title theme music (original plays theme_1 and theme_2 with equal weighting)
	if AudioManager:
		AudioManager.play_theme_music()

func _process(_delta: float) -> void:
	var time_elapsed: float = float(Time.get_ticks_msec()) * 0.001
	# Parallax scroll — each layer at different speed for depth effect
	if _back_clusters_sprite:
		_back_clusters_sprite.position.x = -fmod(time_elapsed * 2.0, 512.0)
	if _mid_mixed_sprite:
		_mid_mixed_sprite.position.x = -fmod(time_elapsed * 5.0, 2048.0)
	if _archs_sprite:
		_archs_sprite.position.x = -fmod(time_elapsed * 10.0, 1024.0)

func _unhandled_input(event: InputEvent) -> void:
	if _about_panel and _about_panel.visible:
		if event is InputEventKey and event.pressed:
			_about_panel.visible = false
			get_viewport().set_input_as_handled()
		return
	if _network_panel and _network_panel.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_network_panel.visible = false
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				_selected_index = (_selected_index - 1)
				if _selected_index < 0:
					_selected_index = _buttons.size() - 1
				_update_button_focus()
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_selected_index = (_selected_index + 1) % _buttons.size()
				_update_button_focus()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				if _selected_index >= 0 and _selected_index < _buttons.size():
					_buttons[_selected_index].emit_signal("pressed")
				get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Background
# ---------------------------------------------------------------------------

func _build_background() -> void:
	# Solid dark background
	_bg_color_rect = ColorRect.new()
	_bg_color_rect.color = Color(0.07, 0.06, 0.1)
	_bg_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_color_rect)

	# Layer 1 (furthest back): back_clusters — tiled across full screen
	var clusters_tex: Texture2D = _load_texture(BACK_CLUSTERS_PATH)
	if clusters_tex:
		_back_clusters_sprite = TextureRect.new()
		_back_clusters_sprite.texture = clusters_tex
		_back_clusters_sprite.stretch_mode = TextureRect.STRETCH_TILE
		_back_clusters_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_back_clusters_sprite.modulate = Color(0.25, 0.22, 0.2, 0.5)
		_back_clusters_sprite.position = Vector2(0, 0)
		# Wider than screen for scroll, tall enough to fill viewport
		_back_clusters_sprite.size = Vector2(1280 + 512, 720)
		add_child(_back_clusters_sprite)

	# Layer 2 (middle): mid_mixed — tiled, positioned in middle-to-lower area
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

	# Layer 3 (foreground): archs — tiled across the lower portion
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

	# Dark gradient overlay at the top for title text readability
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

# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# --- Title Text ---
	# "JMO" in large gold text
	var jmo_label: Label = Label.new()
	jmo_label.text = "JMO"
	jmo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jmo_label.add_theme_font_size_override("font_size", 72)
	jmo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	jmo_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	jmo_label.add_theme_constant_override("shadow_offset_x", 3)
	jmo_label.add_theme_constant_override("shadow_offset_y", 3)
	jmo_label.position = Vector2(340, 20)
	jmo_label.custom_minimum_size = Vector2(600, 80)
	add_child(jmo_label)

	# "Pixel Dungeon" below
	var pd_label: Label = Label.new()
	pd_label.text = "Pixel Dungeon"
	pd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pd_label.add_theme_font_size_override("font_size", 40)
	pd_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.6))
	pd_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	pd_label.add_theme_constant_override("shadow_offset_x", 2)
	pd_label.add_theme_constant_override("shadow_offset_y", 2)
	pd_label.position = Vector2(340, 105)
	pd_label.custom_minimum_size = Vector2(600, 50)
	add_child(pd_label)

	# --- Menu Buttons ---
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.position = Vector2(440, 190)
	vbox.custom_minimum_size = Vector2(400, 300)
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	_btn_new_game = _create_spd_button("New Game")
	_btn_new_game.pressed.connect(_on_new_game_pressed)
	vbox.add_child(_btn_new_game)

	_btn_continue = _create_spd_button("Continue")
	_btn_continue.pressed.connect(_on_continue_pressed)
	_btn_continue.disabled = not _check_has_save()
	vbox.add_child(_btn_continue)

	_btn_host_game = _create_spd_button("Host Co-op")
	_btn_host_game.pressed.connect(_on_host_game_pressed)
	vbox.add_child(_btn_host_game)

	_btn_join_game = _create_spd_button("Join Co-op")
	_btn_join_game.pressed.connect(_on_join_game_pressed)
	vbox.add_child(_btn_join_game)

	_btn_rankings = _create_spd_button("Rankings")
	_btn_rankings.pressed.connect(_on_rankings_pressed)
	vbox.add_child(_btn_rankings)

	_btn_settings = _create_spd_button("Settings")
	_btn_settings.pressed.connect(_on_settings_pressed)
	vbox.add_child(_btn_settings)

	_btn_about = _create_spd_button("About")
	_btn_about.pressed.connect(_on_about_pressed)
	vbox.add_child(_btn_about)

	_buttons = [_btn_new_game, _btn_continue, _btn_host_game, _btn_join_game, _btn_rankings, _btn_settings, _btn_about]

	# --- Version label ---
	var version_label: Label = Label.new()
	version_label.text = "v0.1.2"
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	version_label.position = Vector2(1210, 700)
	add_child(version_label)

	# --- About panel (hidden) ---
	_about_panel = PanelContainer.new()
	_about_panel.visible = false
	_about_panel.position = Vector2(290, 180)
	_about_panel.custom_minimum_size = Vector2(700, 340)
	var about_style: StyleBoxFlat = StyleBoxFlat.new()
	about_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	about_style.border_color = Color(0.4, 0.35, 0.25)
	about_style.set_border_width_all(2)
	about_style.set_corner_radius_all(8)
	about_style.set_content_margin_all(20)
	_about_panel.add_theme_stylebox_override("panel", about_style)
	add_child(_about_panel)

	var about_vbox: VBoxContainer = VBoxContainer.new()
	about_vbox.add_theme_constant_override("separation", 12)
	_about_panel.add_child(about_vbox)

	var about_title: Label = Label.new()
	about_title.text = "About"
	about_title.add_theme_font_size_override("font_size", 22)
	about_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	about_vbox.add_child(about_title)

	var about_text: RichTextLabel = RichTextLabel.new()
	about_text.bbcode_enabled = true
	about_text.text = "Shattered Pixel Dungeon\nGodot Edition v0.1.2\n\nBased on Shattered Pixel Dungeon by Evan Debenham\nOriginal Pixel Dungeon by Watabou\n\nRebuilt in Godot Engine 4.5"
	about_text.custom_minimum_size = Vector2(0, 180)
	about_text.add_theme_color_override("default_color", Color(0.8, 0.8, 0.8))
	about_vbox.add_child(about_text)

	var close_btn: Button = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.pressed.connect(func() -> void: _about_panel.visible = false)
	about_vbox.add_child(close_btn)

	# --- Network panel (hidden) ---
	_network_panel = PanelContainer.new()
	_network_panel.visible = false
	_network_panel.position = Vector2(350, 170)
	_network_panel.custom_minimum_size = Vector2(580, 360)
	var network_style: StyleBoxFlat = StyleBoxFlat.new()
	network_style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	network_style.border_color = Color(0.35, 0.42, 0.55)
	network_style.set_border_width_all(2)
	network_style.set_corner_radius_all(8)
	network_style.set_content_margin_all(18)
	_network_panel.add_theme_stylebox_override("panel", network_style)
	add_child(_network_panel)

	var network_vbox: VBoxContainer = VBoxContainer.new()
	network_vbox.add_theme_constant_override("separation", 10)
	_network_panel.add_child(network_vbox)

	var network_title: Label = Label.new()
	network_title.text = "Join Co-op"
	network_title.add_theme_font_size_override("font_size", 22)
	network_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	network_vbox.add_child(network_title)

	_network_status_label = Label.new()
	_network_status_label.text = "Offline"
	_network_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_network_status_label.add_theme_font_size_override("font_size", 13)
	_network_status_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	network_vbox.add_child(_network_status_label)

	var name_label: Label = Label.new()
	name_label.text = "Player Name"
	network_vbox.add_child(name_label)

	_network_name_edit = LineEdit.new()
	_network_name_edit.text = NetworkManager.local_player_name if NetworkManager else "Player"
	_network_name_edit.placeholder_text = "Player name"
	network_vbox.add_child(_network_name_edit)

	var join_code_label: Label = Label.new()
	join_code_label.text = "Join Code"
	network_vbox.add_child(join_code_label)

	_network_join_code_edit = LineEdit.new()
	_network_join_code_edit.text = NetworkManager.last_join_code if NetworkManager else ""
	_network_join_code_edit.placeholder_text = "friend-address:41234"
	network_vbox.add_child(_network_join_code_edit)

	var address_label: Label = Label.new()
	address_label.text = "Advanced Host Address"
	network_vbox.add_child(address_label)

	_network_address_edit = LineEdit.new()
	_network_address_edit.text = "127.0.0.1"
	_network_address_edit.placeholder_text = "example.com or 127.0.0.1"
	network_vbox.add_child(_network_address_edit)

	var port_label: Label = Label.new()
	port_label.text = "Port"
	network_vbox.add_child(port_label)

	_network_port_edit = LineEdit.new()
	_network_port_edit.text = str(NetworkManager.listen_port if NetworkManager and NetworkManager.listen_port > 0 else (NetworkManager.DEFAULT_PORT if NetworkManager else 41234))
	_network_port_edit.placeholder_text = "41234"
	network_vbox.add_child(_network_port_edit)

	var network_buttons: HBoxContainer = HBoxContainer.new()
	network_buttons.add_theme_constant_override("separation", 8)
	network_vbox.add_child(network_buttons)

	var connect_btn: Button = _create_spd_button("Join by Code")
	connect_btn.custom_minimum_size = Vector2(160, 40)
	connect_btn.pressed.connect(_on_network_join_host_pressed)
	network_buttons.add_child(connect_btn)

	var disconnect_btn: Button = _create_spd_button("Disconnect")
	disconnect_btn.custom_minimum_size = Vector2(160, 40)
	disconnect_btn.pressed.connect(_on_network_disconnect_pressed)
	network_buttons.add_child(disconnect_btn)

	var close_network_btn: Button = Button.new()
	close_network_btn.text = "Close"
	close_network_btn.custom_minimum_size = Vector2(120, 38)
	close_network_btn.pressed.connect(func() -> void: _network_panel.visible = false)
	network_vbox.add_child(close_network_btn)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _check_has_save() -> bool:
	if SaveManager and SaveManager.has_method("has_save"):
		return SaveManager.has_save()
	if GameManager and GameManager.has_method("has_save"):
		return GameManager.has_save()
	return false


func _create_spd_button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(400, 44)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.65, 0.5))

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.14, 0.12, 0.9)
	normal.border_color = Color(0.4, 0.36, 0.30)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 16.0
	normal.content_margin_right = 16.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.20, 0.16, 0.95)
	hover.border_color = Color(0.55, 0.50, 0.40)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.10, 0.09, 0.07)
	btn.add_theme_stylebox_override("pressed", pressed)

	var focus: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focus.border_color = Color(1.0, 0.85, 0.3)
	focus.set_border_width_all(2)
	btn.add_theme_stylebox_override("focus", focus)

	return btn


func _update_button_focus() -> void:
	for i: int in range(_buttons.size()):
		if i == _selected_index:
			_buttons[i].grab_focus()
		else:
			_buttons[i].release_focus()


# ---------------------------------------------------------------------------
# Button Callbacks
# ---------------------------------------------------------------------------

func _on_new_game_pressed() -> void:
	var hero_select_script: GDScript = load(HERO_SELECT_SCENE_PATH) as GDScript
	if hero_select_script:
		SceneManager.go_to(hero_select_script, "HeroSelectScene")

func _on_host_game_pressed() -> void:
	if NetworkManager == null:
		return
	NetworkManager.set_local_player_name(_network_name_edit.text if _network_name_edit else "Player")
	var port: int = NetworkManager.listen_port if NetworkManager.listen_port > 0 else NetworkManager.DEFAULT_PORT
	var player_cap: int = NetworkManager.max_players if NetworkManager.max_players > 0 else NetworkManager.DEFAULT_MAX_PLAYERS
	NetworkManager.host_game(port, player_cap)

func _on_join_game_pressed() -> void:
	if _network_panel:
		_network_panel.visible = true
	if _network_join_code_edit and NetworkManager:
		if not NetworkManager.last_join_code.is_empty():
			_network_join_code_edit.text = NetworkManager.last_join_code
		elif NetworkManager.has_method("build_join_code"):
			_network_join_code_edit.text = "127.0.0.1:%d" % NetworkManager.DEFAULT_PORT
	_refresh_network_status()

func _on_continue_pressed() -> void:
	var success: bool = false
	if SaveManager and SaveManager.has_method("load_full_game"):
		success = SaveManager.load_full_game()
	elif GameManager and GameManager.has_method("load_game"):
		success = GameManager.load_game()
	if success:
		var loading_script: GDScript = load("res://src/scenes/loading_scene.gd") as GDScript
		if loading_script:
			SceneManager.go_to(loading_script, "LoadingScene", {
				"is_continue": true,
			})
			return
	# Load failed — disable the button
	if _btn_continue:
		_btn_continue.disabled = true


func _on_rankings_pressed() -> void:
	SceneManager.go_to(_rankings_scene, "RankingsScene")

func _on_settings_pressed() -> void:
	if _settings_window != null and is_instance_valid(_settings_window):
		return
	var settings_script: GDScript = load("res://src/ui/windows/wnd_settings.gd") as GDScript
	if settings_script == null:
		return
	_settings_window = settings_script.new()
	_settings_window.window_closed.connect(func() -> void:
		_settings_window = null
	)
	add_child(_settings_window)


func _on_about_pressed() -> void:
	if _about_panel:
		_about_panel.visible = true

func _on_network_start_host_pressed() -> void:
	if NetworkManager == null:
		return
	NetworkManager.set_local_player_name(_network_name_edit.text if _network_name_edit else "Player")
	var port: int = _read_network_port()
	var player_cap: int = _read_network_player_cap()
	NetworkManager.host_game(port, player_cap)

func _on_network_join_host_pressed() -> void:
	if NetworkManager == null:
		return
	NetworkManager.set_local_player_name(_network_name_edit.text if _network_name_edit else "Player")
	var address: String = _network_address_edit.text.strip_edges() if _network_address_edit else ""
	var port: int = _read_network_port()
	if _network_join_code_edit != null and not _network_join_code_edit.text.strip_edges().is_empty() and NetworkManager.has_method("parse_join_code"):
		var join_data: Dictionary = NetworkManager.parse_join_code(_network_join_code_edit.text)
		address = str(join_data.get("address", address))
		port = int(join_data.get("port", port))
		NetworkManager.last_join_code = _network_join_code_edit.text.strip_edges()
	NetworkManager.join_game(address, port)

func _on_network_disconnect_pressed() -> void:
	if NetworkManager:
		NetworkManager.close_session()

func _on_network_hosting_started(_port: int, _max_players: int) -> void:
	_refresh_network_status()
	if MessageLog:
		MessageLog.add_positive("Host session started.")
	_go_to_lobby()

func _on_network_connected_to_host() -> void:
	_refresh_network_status()
	if MessageLog:
		MessageLog.add_positive("Connected to host.")
	_go_to_lobby()

func _on_network_join_failed(reason: String) -> void:
	_refresh_network_status()
	if MessageLog:
		MessageLog.add_warning(reason)

func _on_network_disconnected(reason: String) -> void:
	_refresh_network_status()
	if MessageLog and not reason.is_empty():
		MessageLog.add(reason)

func _read_network_port() -> int:
	var port_value: int = NetworkManager.DEFAULT_PORT if NetworkManager else 41234
	if _network_port_edit:
		port_value = int(_network_port_edit.text)
	if port_value <= 0:
		port_value = NetworkManager.DEFAULT_PORT if NetworkManager else 41234
	return port_value

func _read_network_player_cap() -> int:
	var cap_value: int = NetworkManager.DEFAULT_MAX_PLAYERS if NetworkManager else 4
	if _network_players_edit:
		cap_value = int(_network_players_edit.text)
	if GameManager and GameManager.has_method("get_party_classes"):
		cap_value = clampi(cap_value, 1, GameManager.MAX_PARTY_SIZE)
	else:
		cap_value = clampi(cap_value, 1, 4)
	return cap_value

func _refresh_network_status() -> void:
	if _network_status_label == null:
		return
	if NetworkManager == null:
		_network_status_label.text = "Offline"
		return
	if _network_name_edit:
		_network_name_edit.text = NetworkManager.local_player_name
	var status_text: String = NetworkManager.get_connection_label() if NetworkManager.has_method("get_connection_label") else "Offline"
	if NetworkManager.has_method("is_host") and NetworkManager.is_host():
		var join_code: String = NetworkManager.build_join_code() if NetworkManager.has_method("build_join_code") else ""
		if _network_join_code_edit:
			_network_join_code_edit.text = join_code
		status_text += "\nShare join code: %s" % join_code
	elif NetworkManager.has_method("is_client") and NetworkManager.is_client():
		if NetworkManager.has_method("has_active_run") and NetworkManager.has_active_run():
			status_text += "\nConnected as client. Rejoin sync for the active run will resume automatically."
		else:
			status_text += "\nConnected as client. Waiting for lobby/run state from host."
	else:
		if _network_join_code_edit and NetworkManager and not NetworkManager.last_join_code.is_empty():
			_network_join_code_edit.text = NetworkManager.last_join_code
		if _network_port_edit:
			_network_port_edit.text = str(NetworkManager.listen_port if NetworkManager.listen_port > 0 else NetworkManager.DEFAULT_PORT)
		status_text += "\nPaste a join code or enter host address details to join."
	_network_status_label.text = status_text

func _go_to_lobby() -> void:
	var lobby_script: GDScript = load(LOBBY_SCENE_PATH) as GDScript
	if lobby_script:
		SceneManager.go_to(lobby_script, "LobbyScene")
