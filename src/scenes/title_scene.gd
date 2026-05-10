class_name TitleScene
extends Control
## Title screen using original SPD assets — parallax dungeon background,
## banner logo, and styled menu buttons with chrome UI.

# --- UI References ---
var _btn_new_game: Button = null
var _btn_continue: Button = null
var _btn_multiplayer: Button = null
var _btn_profile: Button = null
var _btn_settings: Button = null
var _network_panel: PanelContainer = null
var _profile_panel: PanelContainer = null
var _profile_prompt_panel: PanelContainer = null
var _settings_panel: PanelContainer = null
var _badges_window: Variant = null
var _network_status_label: Label = null
var _network_name_edit: LineEdit = null
var _network_address_edit: LineEdit = null
var _network_port_edit: LineEdit = null
var _network_players_edit: LineEdit = null
var _profile_name_edit: LineEdit = null
var _profile_name_display_label: Label = null
var _profile_name_edit_button: Button = null
var _profile_icon_preview: TextureRect = null
var _profile_icon_edit_button: Button = null
var _profile_summary_label: RichTextLabel = null
var _profile_prompt_name_edit: LineEdit = null
var _settings_music_slider: HSlider = null
var _settings_sfx_slider: HSlider = null
var _settings_zoom_option: OptionButton = null
var _settings_brightness_slider: HSlider = null
var _settings_music_mute_btn: CheckButton = null
var _settings_sfx_mute_btn: CheckButton = null
var _settings_music_value_label: Label = null
var _settings_sfx_value_label: Label = null
var _settings_brightness_value_label: Label = null
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
const PROFILE_ICON_SPRITES: Dictionary = {
	"warrior": "res://assets/spd/sprites/warrior.png",
	"mage": "res://assets/spd/sprites/mage.png",
	"rogue": "res://assets/spd/sprites/rogue.png",
	"huntress": "res://assets/spd/sprites/huntress.png",
	"duelist": "res://assets/spd/sprites/duelist.png",
}

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
	_refresh_profile_ui()
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
	if PlayerProfile and PlayerProfile.has_signal("profile_updated"):
		PlayerProfile.profile_updated.connect(_on_profile_updated)
	# Play title theme music (original plays theme_1 and theme_2 with equal weighting)
	if AudioManager:
		AudioManager.play_theme_music()
	if PlayerProfile and not PlayerProfile.is_profile_complete():
		_open_profile_prompt()

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
	if _profile_prompt_panel and _profile_prompt_panel.visible:
		if _is_accept_input(event):
			_on_profile_prompt_confirmed()
			get_viewport().set_input_as_handled()
		return
	if _profile_panel and _profile_panel.visible:
		if _is_cancel_input(event):
			_profile_panel.visible = false
			get_viewport().set_input_as_handled()
		return
	if _settings_panel and _settings_panel.visible:
		if _is_cancel_input(event):
			_settings_panel.visible = false
			get_viewport().set_input_as_handled()
		return
	if _network_panel and _network_panel.visible:
		if _is_cancel_input(event):
			_network_panel.visible = false
			get_viewport().set_input_as_handled()
		return

	if _is_up_input(event):
		_selected_index = (_selected_index - 1)
		if _selected_index < 0:
			_selected_index = _buttons.size() - 1
		_update_button_focus()
		get_viewport().set_input_as_handled()
	elif _is_down_input(event):
		_selected_index = (_selected_index + 1) % _buttons.size()
		_update_button_focus()
		get_viewport().set_input_as_handled()
	elif _is_accept_input(event):
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

	var has_save: bool = _check_has_save()

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.custom_minimum_size = Vector2(400, 44)
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 12)
	vbox.add_child(top_row)

	_btn_new_game = _create_spd_button("New Game", Vector2(400 if not has_save else 258, 44))
	_btn_new_game.pressed.connect(_on_new_game_pressed)
	top_row.add_child(_btn_new_game)

	if has_save:
		_btn_continue = _create_spd_button("Continue", Vector2(130, 44))
		_btn_continue.pressed.connect(_on_continue_pressed)
		_btn_continue.disabled = false
		top_row.add_child(_btn_continue)
	else:
		_btn_continue = null

	_btn_multiplayer = _create_spd_button("Multiplayer")
	_btn_multiplayer.pressed.connect(_on_multiplayer_pressed)
	vbox.add_child(_btn_multiplayer)

	_btn_profile = _create_spd_button("Player Profile")
	_btn_profile.pressed.connect(_on_profile_pressed)
	vbox.add_child(_btn_profile)

	_btn_settings = _create_spd_button("Settings")
	_btn_settings.pressed.connect(_on_settings_pressed)
	vbox.add_child(_btn_settings)

	_buttons = [_btn_new_game]
	if _btn_continue != null:
		_buttons.append(_btn_continue)
	_buttons.append_array([_btn_multiplayer, _btn_profile, _btn_settings])

	# --- Version label ---
	var version_label: Label = Label.new()
	version_label.text = "v0.1.2"
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	version_label.position = Vector2(1210, 700)
	add_child(version_label)

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
	network_title.text = "Multiplayer"
	network_title.add_theme_font_size_override("font_size", 22)
	network_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	network_vbox.add_child(network_title)

	_network_status_label = Label.new()
	_network_status_label.text = "Offline"
	_network_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_network_status_label.add_theme_font_size_override("font_size", 13)
	_network_status_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	network_vbox.add_child(_network_status_label)

	var host_btn: Button = _create_spd_button("Open Lobby")
	host_btn.custom_minimum_size = Vector2(544, 40)
	host_btn.pressed.connect(_on_network_start_host_pressed)
	network_vbox.add_child(host_btn)

	var network_sep: HSeparator = HSeparator.new()
	network_vbox.add_child(network_sep)

	var address_label: Label = Label.new()
	address_label.text = "Lobby IP"
	network_vbox.add_child(address_label)

	_network_address_edit = LineEdit.new()
	_network_address_edit.text = "127.0.0.1"
	_network_address_edit.placeholder_text = "Lobby IP or hostname"
	network_vbox.add_child(_network_address_edit)

	var port_label: Label = Label.new()
	port_label.text = "Port"
	network_vbox.add_child(port_label)

	_network_port_edit = LineEdit.new()
	_network_port_edit.text = str(NetworkManager.listen_port if NetworkManager and NetworkManager.listen_port > 0 else (NetworkManager.DEFAULT_PORT if NetworkManager else 41234))
	_network_port_edit.placeholder_text = "41234"
	network_vbox.add_child(_network_port_edit)

	var network_buttons: HBoxContainer = HBoxContainer.new()
	network_buttons.add_theme_constant_override("separation", 12)
	network_vbox.add_child(network_buttons)

	var close_network_btn: Button = _create_spd_button("Back")
	close_network_btn.custom_minimum_size = Vector2(240, 40)
	close_network_btn.pressed.connect(func() -> void: _network_panel.visible = false)
	network_buttons.add_child(close_network_btn)

	var connect_btn: Button = _create_spd_button("Join Lobby")
	connect_btn.custom_minimum_size = Vector2(240, 40)
	connect_btn.pressed.connect(_on_network_join_host_pressed)
	network_buttons.add_child(connect_btn)

	_profile_panel = PanelContainer.new()
	_profile_panel.visible = false
	_profile_panel.position = Vector2(330, 150)
	_profile_panel.custom_minimum_size = Vector2(620, 420)
	var profile_style: StyleBoxFlat = StyleBoxFlat.new()
	profile_style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	profile_style.border_color = Color(0.4, 0.35, 0.25)
	profile_style.set_border_width_all(2)
	profile_style.set_corner_radius_all(8)
	profile_style.set_content_margin_all(18)
	_profile_panel.add_theme_stylebox_override("panel", profile_style)
	add_child(_profile_panel)

	var profile_vbox: VBoxContainer = VBoxContainer.new()
	profile_vbox.add_theme_constant_override("separation", 10)
	_profile_panel.add_child(profile_vbox)

	var profile_title: Label = Label.new()
	profile_title.text = "Player Profile"
	profile_title.add_theme_font_size_override("font_size", 22)
	profile_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	profile_vbox.add_child(profile_title)

	var profile_header: HBoxContainer = HBoxContainer.new()
	profile_header.add_theme_constant_override("separation", 14)
	profile_vbox.add_child(profile_header)

	var icon_column: VBoxContainer = VBoxContainer.new()
	icon_column.add_theme_constant_override("separation", 6)
	profile_header.add_child(icon_column)

	var icon_frame: Panel = Panel.new()
	icon_frame.custom_minimum_size = Vector2(86, 86)
	var icon_style: StyleBoxFlat = StyleBoxFlat.new()
	icon_style.bg_color = Color(0.12, 0.11, 0.1, 0.92)
	icon_style.border_color = Color(0.4, 0.36, 0.28)
	icon_style.set_border_width_all(2)
	icon_style.set_corner_radius_all(6)
	icon_frame.add_theme_stylebox_override("panel", icon_style)
	icon_column.add_child(icon_frame)

	_profile_icon_preview = TextureRect.new()
	_profile_icon_preview.position = Vector2(11, 11)
	_profile_icon_preview.custom_minimum_size = Vector2(64, 64)
	_profile_icon_preview.size = Vector2(64, 64)
	_profile_icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_profile_icon_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_frame.add_child(_profile_icon_preview)

	_profile_icon_edit_button = _create_spd_button("Edit", Vector2(86, 28))
	_profile_icon_edit_button.pressed.connect(_on_profile_icon_edit_pressed)
	icon_column.add_child(_profile_icon_edit_button)

	var name_column: VBoxContainer = VBoxContainer.new()
	name_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_column.add_theme_constant_override("separation", 8)
	profile_header.add_child(name_column)

	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_column.add_child(name_row)

	_profile_name_display_label = Label.new()
	_profile_name_display_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_name_display_label.add_theme_font_size_override("font_size", 28)
	_profile_name_display_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86))
	name_row.add_child(_profile_name_display_label)

	_profile_name_edit_button = _create_spd_button("Edit", Vector2(86, 30))
	_profile_name_edit_button.pressed.connect(_on_profile_name_edit_pressed)
	name_row.add_child(_profile_name_edit_button)

	var icon_note_label: Label = Label.new()
	icon_note_label.text = "Profile icons unlock through progress. Warrior is available by default."
	icon_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	icon_note_label.add_theme_font_size_override("font_size", 12)
	icon_note_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	name_column.add_child(icon_note_label)

	_profile_name_edit = LineEdit.new()
	_profile_name_edit.visible = false
	profile_vbox.add_child(_profile_name_edit)

	_profile_summary_label = RichTextLabel.new()
	_profile_summary_label.bbcode_enabled = true
	_profile_summary_label.fit_content = true
	_profile_summary_label.custom_minimum_size = Vector2(0, 180)
	_profile_summary_label.add_theme_color_override("default_color", Color(0.82, 0.84, 0.9))
	profile_vbox.add_child(_profile_summary_label)

	var profile_links: HBoxContainer = HBoxContainer.new()
	profile_links.add_theme_constant_override("separation", 10)
	profile_vbox.add_child(profile_links)

	var badges_btn: Button = _create_spd_button("Achievements")
	badges_btn.custom_minimum_size = Vector2(260, 40)
	badges_btn.pressed.connect(_on_badges_pressed)
	profile_links.add_child(badges_btn)

	var rankings_btn: Button = _create_spd_button("View Rankings")
	rankings_btn.custom_minimum_size = Vector2(260, 40)
	rankings_btn.pressed.connect(_on_rankings_pressed)
	profile_links.add_child(rankings_btn)

	var profile_actions: HBoxContainer = HBoxContainer.new()
	profile_actions.add_theme_constant_override("separation", 10)
	profile_vbox.add_child(profile_actions)

	var close_profile_btn: Button = _create_spd_button("Back")
	close_profile_btn.custom_minimum_size = Vector2(260, 40)
	close_profile_btn.pressed.connect(func() -> void: _profile_panel.visible = false)
	profile_actions.add_child(close_profile_btn)

	var save_profile_btn: Button = _create_spd_button("Save")
	save_profile_btn.custom_minimum_size = Vector2(260, 40)
	save_profile_btn.pressed.connect(_on_save_profile_pressed)
	profile_actions.add_child(save_profile_btn)

	_profile_prompt_panel = PanelContainer.new()
	_profile_prompt_panel.visible = false
	_profile_prompt_panel.position = Vector2(390, 220)
	_profile_prompt_panel.custom_minimum_size = Vector2(500, 220)
	var prompt_style: StyleBoxFlat = StyleBoxFlat.new()
	prompt_style.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	prompt_style.border_color = Color(0.55, 0.5, 0.35)
	prompt_style.set_border_width_all(2)
	prompt_style.set_corner_radius_all(8)
	prompt_style.set_content_margin_all(18)
	_profile_prompt_panel.add_theme_stylebox_override("panel", prompt_style)
	add_child(_profile_prompt_panel)

	var prompt_vbox: VBoxContainer = VBoxContainer.new()
	prompt_vbox.add_theme_constant_override("separation", 12)
	_profile_prompt_panel.add_child(prompt_vbox)

	var prompt_title: Label = Label.new()
	prompt_title.text = "Choose Your Name"
	prompt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_title.add_theme_font_size_override("font_size", 22)
	prompt_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	prompt_vbox.add_child(prompt_title)

	var prompt_body: Label = Label.new()
	prompt_body.text = "This name is used for your profile, rankings, achievements, and multiplayer identity."
	prompt_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_vbox.add_child(prompt_body)

	_profile_prompt_name_edit = LineEdit.new()
	_profile_prompt_name_edit.placeholder_text = "Player name"
	prompt_vbox.add_child(_profile_prompt_name_edit)

	var prompt_confirm_btn: Button = _create_spd_button("Continue")
	prompt_confirm_btn.custom_minimum_size = Vector2(220, 40)
	prompt_confirm_btn.pressed.connect(_on_profile_prompt_confirmed)
	prompt_vbox.add_child(prompt_confirm_btn)

	_settings_panel = PanelContainer.new()
	_settings_panel.visible = false
	_settings_panel.position = Vector2(330, 120)
	_settings_panel.custom_minimum_size = Vector2(620, 480)
	var settings_style: StyleBoxFlat = StyleBoxFlat.new()
	settings_style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	settings_style.border_color = Color(0.4, 0.35, 0.25)
	settings_style.set_border_width_all(2)
	settings_style.set_corner_radius_all(8)
	settings_style.set_content_margin_all(18)
	_settings_panel.add_theme_stylebox_override("panel", settings_style)
	add_child(_settings_panel)

	var settings_vbox: VBoxContainer = VBoxContainer.new()
	settings_vbox.add_theme_constant_override("separation", 12)
	_settings_panel.add_child(settings_vbox)

	var settings_title: Label = Label.new()
	settings_title.text = "Settings"
	settings_title.add_theme_font_size_override("font_size", 22)
	settings_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	settings_vbox.add_child(settings_title)

	var music_section: Dictionary = _create_settings_slider_section("Music Volume")
	_settings_music_slider = music_section["slider"] as HSlider
	_settings_music_value_label = music_section["value_label"] as Label
	_settings_music_slider.min_value = 0
	_settings_music_slider.max_value = 100
	_settings_music_slider.step = 1
	_settings_music_slider.value_changed.connect(_on_settings_music_changed)
	settings_vbox.add_child(music_section["container"] as Control)

	_settings_music_mute_btn = CheckButton.new()
	_settings_music_mute_btn.text = "Mute Music"
	_settings_music_mute_btn.add_theme_font_size_override("font_size", 12)
	_settings_music_mute_btn.add_theme_color_override("font_color", Color(0.82, 0.82, 0.85))
	_settings_music_mute_btn.toggled.connect(_on_settings_music_mute_toggled)
	settings_vbox.add_child(_settings_music_mute_btn)

	var sfx_section: Dictionary = _create_settings_slider_section("SFX Volume")
	_settings_sfx_slider = sfx_section["slider"] as HSlider
	_settings_sfx_value_label = sfx_section["value_label"] as Label
	_settings_sfx_slider.min_value = 0
	_settings_sfx_slider.max_value = 100
	_settings_sfx_slider.step = 1
	_settings_sfx_slider.value_changed.connect(_on_settings_sfx_changed)
	settings_vbox.add_child(sfx_section["container"] as Control)

	_settings_sfx_mute_btn = CheckButton.new()
	_settings_sfx_mute_btn.text = "Mute SFX"
	_settings_sfx_mute_btn.add_theme_font_size_override("font_size", 12)
	_settings_sfx_mute_btn.add_theme_color_override("font_color", Color(0.82, 0.82, 0.85))
	_settings_sfx_mute_btn.toggled.connect(_on_settings_sfx_mute_toggled)
	settings_vbox.add_child(_settings_sfx_mute_btn)

	var zoom_container: VBoxContainer = VBoxContainer.new()
	zoom_container.add_theme_constant_override("separation", 4)
	var zoom_label: Label = Label.new()
	zoom_label.text = "Zoom Level"
	zoom_label.add_theme_font_size_override("font_size", 12)
	zoom_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	zoom_container.add_child(zoom_label)
	_settings_zoom_option = OptionButton.new()
	_settings_zoom_option.add_item("1x", 0)
	_settings_zoom_option.add_item("1.5x", 1)
	_settings_zoom_option.add_item("2x", 2)
	_settings_zoom_option.add_item("3x", 3)
	_settings_zoom_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_zoom_option.item_selected.connect(_on_settings_zoom_changed)
	zoom_container.add_child(_settings_zoom_option)
	settings_vbox.add_child(zoom_container)

	var brightness_section: Dictionary = _create_settings_slider_section("Brightness")
	_settings_brightness_slider = brightness_section["slider"] as HSlider
	_settings_brightness_value_label = brightness_section["value_label"] as Label
	_settings_brightness_slider.min_value = 0
	_settings_brightness_slider.max_value = 100
	_settings_brightness_slider.step = 1
	_settings_brightness_slider.value_changed.connect(_on_settings_brightness_changed)
	settings_vbox.add_child(brightness_section["container"] as Control)

	var settings_separator: HSeparator = HSeparator.new()
	settings_vbox.add_child(settings_separator)

	var settings_actions: HBoxContainer = HBoxContainer.new()
	settings_actions.add_theme_constant_override("separation", 10)
	settings_vbox.add_child(settings_actions)

	var close_settings_btn: Button = _create_spd_button("Back")
	close_settings_btn.custom_minimum_size = Vector2(260, 40)
	close_settings_btn.pressed.connect(func() -> void: _settings_panel.visible = false)
	settings_actions.add_child(close_settings_btn)

	var save_settings_btn: Button = _create_spd_button("Save")
	save_settings_btn.custom_minimum_size = Vector2(260, 40)
	save_settings_btn.pressed.connect(_on_save_settings_pressed)
	settings_actions.add_child(save_settings_btn)


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


func _create_spd_button(text: String, min_size: Vector2 = Vector2(400, 44)) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
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


func _create_settings_slider_section(title: String) -> Dictionary:
	var container: VBoxContainer = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var header: HBoxContainer = HBoxContainer.new()
	var title_label: Label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	var value_label: Label = Label.new()
	value_label.text = "0%"
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(50, 0)
	header.add_child(value_label)
	container.add_child(header)

	var slider: HSlider = HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 20)
	container.add_child(slider)

	return {"container": container, "slider": slider, "value_label": value_label}

func _get_profile_icon_texture(icon_id: String) -> Texture2D:
	var sheet_path: String = str(PROFILE_ICON_SPRITES.get(icon_id, PROFILE_ICON_SPRITES["warrior"]))
	if not ResourceLoader.exists(sheet_path):
		return null
	var sheet: Texture2D = load(sheet_path) as Texture2D
	if sheet == null:
		return null
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0, 90, 12, 15)
	return atlas

func _is_accept_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_A
	return false

func _is_cancel_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		return event.keycode == KEY_ESCAPE
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_B
	return false

func _is_up_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		return event.keycode == KEY_UP
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_DPAD_UP
	return false

func _is_down_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		return event.keycode == KEY_DOWN
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_DPAD_DOWN
	return false


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

func _on_multiplayer_pressed() -> void:
	_on_network_start_host_pressed()

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

func _on_profile_pressed() -> void:
	_refresh_profile_ui()
	if _profile_panel:
		_profile_panel.visible = true

func _on_save_profile_pressed() -> void:
	if PlayerProfile == null:
		return
	_refresh_profile_ui()
	if MessageLog:
		MessageLog.add_positive("Profile updated.")

func _on_profile_name_edit_pressed() -> void:
	if _profile_prompt_name_edit:
		_profile_prompt_name_edit.text = PlayerProfile.get_player_name() if PlayerProfile else ""
	_open_profile_prompt()

func _on_profile_icon_edit_pressed() -> void:
	if PlayerProfile == null or not PlayerProfile.has_method("cycle_selected_icon"):
		return
	PlayerProfile.cycle_selected_icon(1)
	if NetworkManager and NetworkManager.has_method("set_local_profile_icon_id"):
		NetworkManager.set_local_profile_icon_id(PlayerProfile.get_selected_icon_id())
	if MessageLog:
		MessageLog.add("Profile icon updated.")

func _on_badges_pressed() -> void:
	if _badges_window != null and is_instance_valid(_badges_window):
		return
	var badges_script: GDScript = load("res://src/ui/windows/wnd_badges.gd") as GDScript
	if badges_script == null:
		return
	_badges_window = badges_script.new()
	_badges_window.window_closed.connect(func() -> void:
		_badges_window = null
	)
	add_child(_badges_window)

func _on_settings_pressed() -> void:
	_refresh_settings_ui()
	if _settings_panel:
		_settings_panel.visible = true

func _on_network_start_host_pressed() -> void:
	if NetworkManager == null:
		return
	if PlayerProfile:
		NetworkManager.set_local_player_name(PlayerProfile.get_player_name())
		if NetworkManager.has_method("set_local_profile_icon_id"):
			NetworkManager.set_local_profile_icon_id(PlayerProfile.get_selected_icon_id())
	var port: int = _read_network_port()
	var player_cap: int = _read_network_player_cap()
	NetworkManager.host_game(port, player_cap)

func _on_network_join_host_pressed() -> void:
	if NetworkManager == null:
		return
	if PlayerProfile:
		NetworkManager.set_local_player_name(PlayerProfile.get_player_name())
		if NetworkManager.has_method("set_local_profile_icon_id"):
			NetworkManager.set_local_profile_icon_id(PlayerProfile.get_selected_icon_id())
	var address: String = _network_address_edit.text.strip_edges() if _network_address_edit else ""
	var port: int = _read_network_port()
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
		_network_name_edit.text = PlayerProfile.get_player_name() if PlayerProfile else NetworkManager.local_player_name
	var status_text: String = NetworkManager.get_connection_label() if NetworkManager.has_method("get_connection_label") else "Offline"
	if NetworkManager.has_method("is_host") and NetworkManager.is_host():
		var host_ip: String = NetworkManager.get_preferred_bind_address() if NetworkManager.has_method("get_preferred_bind_address") else "127.0.0.1"
		if _network_address_edit:
			_network_address_edit.text = host_ip
		status_text += "\nHost IP: %s" % host_ip
	elif NetworkManager.has_method("is_client") and NetworkManager.is_client():
		if NetworkManager.has_method("has_active_run") and NetworkManager.has_active_run():
			status_text += "\nConnected as client. Rejoin sync for the active run will resume automatically."
		else:
			status_text += "\nConnected as client. Waiting for lobby/run state from host."
	else:
		if _network_port_edit:
			_network_port_edit.text = str(NetworkManager.listen_port if NetworkManager.listen_port > 0 else NetworkManager.DEFAULT_PORT)
		status_text += "\nEnter the host IP address and port to join."
	_network_status_label.text = status_text

func _refresh_profile_ui() -> void:
	if _profile_name_edit:
		_profile_name_edit.text = PlayerProfile.get_player_name() if PlayerProfile else "Player"
	if _profile_name_display_label:
		_profile_name_display_label.text = PlayerProfile.get_player_name() if PlayerProfile else "Player"
	if _profile_prompt_name_edit and PlayerProfile and PlayerProfile.has_player_name():
		_profile_prompt_name_edit.text = PlayerProfile.get_player_name()
	if _profile_icon_preview and PlayerProfile:
		_profile_icon_preview.texture = _get_profile_icon_texture(PlayerProfile.get_selected_icon_id())
	if _profile_icon_edit_button and PlayerProfile and PlayerProfile.has_method("get_unlocked_profile_icon_ids"):
		var unlocked_count: int = PlayerProfile.get_unlocked_profile_icon_ids().size()
		_profile_icon_edit_button.disabled = unlocked_count <= 1
		_profile_icon_edit_button.tooltip_text = "Cycle unlocked icons (%d available)" % unlocked_count
	if _profile_summary_label == null or PlayerProfile == null:
		return
	var ranking_summary: Dictionary = PlayerProfile.get_rankings_summary()
	var unlocked_icons: int = 0
	if PlayerProfile.has_method("get_unlocked_profile_icon_ids"):
		unlocked_icons = PlayerProfile.get_unlocked_profile_icon_ids().size()
	_profile_summary_label.text = "[b]%s[/b]\n[b]Profile Icons:[/b] %d/%d\n[b]Runs:[/b] %d\n[b]Victories:[/b] %d\n[b]Best Score:[/b] %d\n[b]Deepest Depth:[/b] %d" % [
		PlayerProfile.get_badge_summary(),
		unlocked_icons,
		5,
		int(ranking_summary.get("runs", 0)),
		int(ranking_summary.get("wins", 0)),
		int(ranking_summary.get("best_score", 0)),
		int(ranking_summary.get("best_depth", 0)),
	]

func _open_profile_prompt() -> void:
	if _profile_prompt_panel:
		_profile_prompt_panel.visible = true
	if _profile_prompt_name_edit:
		if _profile_prompt_name_edit.text.strip_edges().is_empty() and PlayerProfile:
			_profile_prompt_name_edit.text = PlayerProfile.get_player_name()
		_profile_prompt_name_edit.grab_focus()

func _on_profile_prompt_confirmed() -> void:
	if PlayerProfile == null or _profile_prompt_name_edit == null:
		return
	var chosen_name: String = _profile_prompt_name_edit.text.strip_edges()
	if chosen_name.is_empty():
		if MessageLog:
			MessageLog.add_warning("Enter a player name first.")
		return
	PlayerProfile.set_player_name(chosen_name)
	if _profile_prompt_panel:
		_profile_prompt_panel.visible = false
	_refresh_profile_ui()

func _on_profile_updated() -> void:
	if NetworkManager and PlayerProfile:
		NetworkManager.set_local_player_name(PlayerProfile.get_player_name())
		if NetworkManager.has_method("set_local_profile_icon_id"):
			NetworkManager.set_local_profile_icon_id(PlayerProfile.get_selected_icon_id())
	_refresh_profile_ui()
	_refresh_network_status()


func _refresh_settings_ui() -> void:
	if _settings_music_slider:
		_settings_music_slider.value = _get_music_volume_percent()
	if _settings_music_value_label:
		_settings_music_value_label.text = "0%"
		if _settings_music_slider:
			_settings_music_value_label.text = "%d%%" % int(_settings_music_slider.value)
	if _settings_sfx_slider:
		_settings_sfx_slider.value = _get_sfx_volume_percent()
	if _settings_sfx_value_label:
		_settings_sfx_value_label.text = "0%"
		if _settings_sfx_slider:
			_settings_sfx_value_label.text = "%d%%" % int(_settings_sfx_slider.value)
	if _settings_music_mute_btn:
		_settings_music_mute_btn.button_pressed = _get_music_muted()
	if _settings_sfx_mute_btn:
		_settings_sfx_mute_btn.button_pressed = _get_sfx_muted()
	if _settings_zoom_option:
		_settings_zoom_option.selected = _get_current_zoom_index()
	if _settings_brightness_slider:
		_settings_brightness_slider.value = _get_brightness_percent()
	if _settings_brightness_value_label:
		_settings_brightness_value_label.text = "0%"
		if _settings_brightness_slider:
			_settings_brightness_value_label.text = "%d%%" % int(_settings_brightness_slider.value)


func _on_settings_music_changed(value: float) -> void:
	if _settings_music_value_label:
		_settings_music_value_label.text = "%d%%" % int(value)
	if AudioManager and AudioManager.has_method("set_music_volume"):
		AudioManager.set_music_volume(value / 100.0)


func _on_settings_sfx_changed(value: float) -> void:
	if _settings_sfx_value_label:
		_settings_sfx_value_label.text = "%d%%" % int(value)
	if AudioManager and AudioManager.has_method("set_sfx_volume"):
		AudioManager.set_sfx_volume(value / 100.0)


func _on_settings_music_mute_toggled(pressed: bool) -> void:
	if AudioManager and AudioManager.has_method("set_music_muted"):
		AudioManager.set_music_muted(pressed)


func _on_settings_sfx_mute_toggled(pressed: bool) -> void:
	if AudioManager and AudioManager.has_method("set_sfx_muted"):
		AudioManager.set_sfx_muted(pressed)


func _on_settings_zoom_changed(index: int) -> void:
	var zoom_values: Array[float] = [1.0, 1.5, 2.0, 3.0]
	if index >= 0 and index < zoom_values.size():
		var zoom_value: float = zoom_values[index]
		if GameManager:
			GameManager.set("zoom_level", zoom_value)


func _on_settings_brightness_changed(value: float) -> void:
	if _settings_brightness_value_label:
		_settings_brightness_value_label.text = "%d%%" % int(value)
	if GameManager:
		GameManager.set("setting_brightness", value / 100.0)


func _on_save_settings_pressed() -> void:
	if GameManager:
		var music_volume: float = 0.5
		var sfx_volume: float = 0.8
		var brightness_value: float = 0.5
		var music_muted: bool = false
		var sfx_muted: bool = false
		if _settings_music_slider:
			music_volume = _settings_music_slider.value / 100.0
		if _settings_sfx_slider:
			sfx_volume = _settings_sfx_slider.value / 100.0
		if _settings_brightness_slider:
			brightness_value = _settings_brightness_slider.value / 100.0
		if _settings_music_mute_btn:
			music_muted = _settings_music_mute_btn.button_pressed
		if _settings_sfx_mute_btn:
			sfx_muted = _settings_sfx_mute_btn.button_pressed
		GameManager.set("setting_music_volume", music_volume)
		GameManager.set("setting_sfx_volume", sfx_volume)
		GameManager.set("setting_brightness", brightness_value)
		GameManager.set("setting_music_muted", music_muted)
		GameManager.set("setting_sfx_muted", sfx_muted)
		if GameManager.has_method("save_settings"):
			GameManager.save_settings()
	if SaveManager and SaveManager.has_method("save_audio_settings"):
		SaveManager.save_audio_settings()
	if _settings_panel:
		_settings_panel.visible = false


func _get_music_volume_percent() -> float:
	if AudioManager:
		var volume: Variant = AudioManager.get("music_volume")
		if volume is float:
			return volume * 100.0
	return 50.0


func _get_sfx_volume_percent() -> float:
	if AudioManager:
		var volume: Variant = AudioManager.get("sfx_volume")
		if volume is float:
			return volume * 100.0
	return 80.0


func _get_music_muted() -> bool:
	if AudioManager:
		var muted: Variant = AudioManager.get("music_muted")
		if muted is bool:
			return muted
	return false


func _get_sfx_muted() -> bool:
	if AudioManager:
		var muted: Variant = AudioManager.get("sfx_muted")
		if muted is bool:
			return muted
	return false


func _get_current_zoom_index() -> int:
	if GameManager:
		var zoom: Variant = GameManager.get("zoom_level")
		if zoom is float:
			var zoom_values: Array[float] = [1.0, 1.5, 2.0, 3.0]
			for index: int in range(zoom_values.size()):
				if absf(zoom_values[index] - zoom) < 0.01:
					return index
	return 0


func _get_brightness_percent() -> float:
	if GameManager:
		var brightness: Variant = GameManager.get("setting_brightness")
		if brightness is float:
			return brightness * 100.0
	return 50.0

func _go_to_lobby() -> void:
	var lobby_script: GDScript = load(LOBBY_SCENE_PATH) as GDScript
	if lobby_script:
		SceneManager.go_to(lobby_script, "LobbyScene")
