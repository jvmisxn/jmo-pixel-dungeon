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
var _profile_icon_picker_window: Variant = null
var _network_status_label: Label = null
var _network_name_edit: LineEdit = null
var _network_address_edit: LineEdit = null
var _network_port_edit: LineEdit = null
var _network_players_edit: LineEdit = null
var _profile_name_edit: LineEdit = null
var _profile_name_display_label: Label = null
var _profile_name_edit_button: Button = null
var _profile_icon_preview: Variant = null
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
var _jmo_title_label: Label = null
var _pd_title_label: Label = null
var _menu_box: VBoxContainer = null
var _top_menu_row: HBoxContainer = null
var _version_label: Label = null
var _buttons: Array[Button] = []
var _selected_index: int = 0
var _layout_viewport_size: Vector2 = Vector2.ZERO
var _web_layout_poll_elapsed: float = 0.0

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
const SUBMENU_PANEL_SIZE: Vector2 = Vector2(760, 680)
const SUBMENU_PANEL_TOP: float = 20.0
const SUBMENU_CONTENT_MARGIN: int = 24
const SUBMENU_CONTENT_WIDTH: float = 712.0
const SUBMENU_ACTION_WIDTH: float = 350.0
const WEB_LAYOUT_POLL_INTERVAL: float = 0.25
const PORTRAIT_MENU_MAX_WIDTH: float = 320.0
const PROFILE_ICON_SPRITES: Dictionary = {
	"warrior": "res://assets/spd/sprites/warrior.png",
	"mage": "res://assets/spd/sprites/mage.png",
	"rogue": "res://assets/spd/sprites/rogue.png",
	"huntress": "res://assets/spd/sprites/huntress.png",
	"duelist": "res://assets/spd/sprites/duelist.png",
	"rat": "res://assets/spd/sprites/rat.png",
	"gnoll": "res://assets/spd/sprites/gnoll.png",
	"crab": "res://assets/spd/sprites/crab.png",
	"skeleton": "res://assets/spd/sprites/skeleton.png",
	"goo": "res://assets/spd/sprites/goo.png",
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RenderingServer.set_default_clear_color(Color.BLACK)
	_build_background()
	_build_ui()
	_apply_layout()
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
	get_viewport().size_changed.connect(_apply_layout)

func _process(_delta: float) -> void:
	if OS.get_name() == "Web":
		_web_layout_poll_elapsed += _delta
		if _web_layout_poll_elapsed >= WEB_LAYOUT_POLL_INTERVAL:
			_web_layout_poll_elapsed = 0.0
			var current_size: Vector2 = _get_layout_viewport_size()
			if not current_size.is_equal_approx(_layout_viewport_size):
				_apply_layout()
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
	_jmo_title_label = Label.new()
	_jmo_title_label.text = "JMO"
	_jmo_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_jmo_title_label.add_theme_font_size_override("font_size", 72)
	_jmo_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_jmo_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	_jmo_title_label.add_theme_constant_override("shadow_offset_x", 3)
	_jmo_title_label.add_theme_constant_override("shadow_offset_y", 3)
	_jmo_title_label.position = Vector2(340, 20)
	_jmo_title_label.custom_minimum_size = Vector2(600, 80)
	add_child(_jmo_title_label)

	# "Pixel Dungeon" below
	_pd_title_label = Label.new()
	_pd_title_label.text = "Pixel Dungeon"
	_pd_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pd_title_label.add_theme_font_size_override("font_size", 40)
	_pd_title_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.6))
	_pd_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	_pd_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_pd_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_pd_title_label.position = Vector2(340, 105)
	_pd_title_label.custom_minimum_size = Vector2(600, 50)
	add_child(_pd_title_label)

	# --- Menu Buttons ---
	_menu_box = VBoxContainer.new()
	_menu_box.position = Vector2(440, 190)
	_menu_box.custom_minimum_size = Vector2(400, 300)
	_menu_box.add_theme_constant_override("separation", 12)
	add_child(_menu_box)

	var has_save: bool = _check_has_save()

	_top_menu_row = HBoxContainer.new()
	_top_menu_row.custom_minimum_size = Vector2(400, 44)
	_top_menu_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_menu_row.add_theme_constant_override("separation", 12)
	_menu_box.add_child(_top_menu_row)

	_btn_new_game = _create_spd_button("New Game", Vector2(400 if not has_save else 258, 44))
	_btn_new_game.pressed.connect(_on_new_game_pressed)
	_top_menu_row.add_child(_btn_new_game)

	if has_save:
		_btn_continue = _create_spd_button("Continue", Vector2(130, 44))
		_btn_continue.pressed.connect(_on_continue_pressed)
		_btn_continue.disabled = false
		_top_menu_row.add_child(_btn_continue)
	else:
		_btn_continue = null

	_btn_multiplayer = _create_spd_button("Multiplayer")
	_btn_multiplayer.pressed.connect(_on_multiplayer_pressed)
	_menu_box.add_child(_btn_multiplayer)

	_btn_profile = _create_spd_button("Player Profile")
	_btn_profile.pressed.connect(_on_profile_pressed)
	_menu_box.add_child(_btn_profile)

	_btn_settings = _create_spd_button("Settings")
	_btn_settings.pressed.connect(_on_settings_pressed)
	_menu_box.add_child(_btn_settings)

	_buttons = [_btn_new_game]
	if _btn_continue != null:
		_buttons.append(_btn_continue)
	_buttons.append_array([_btn_multiplayer, _btn_profile, _btn_settings])

	# --- Version label ---
	_version_label = Label.new()
	_version_label.text = "v0.1.2"
	_version_label.add_theme_font_size_override("font_size", 12)
	_version_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	_version_label.position = Vector2(1210, 700)
	add_child(_version_label)

	# --- Network panel (hidden) ---
	_network_panel = PanelContainer.new()
	_network_panel.visible = false
	_network_panel.position = _get_centered_submenu_position(SUBMENU_PANEL_SIZE)
	_network_panel.custom_minimum_size = SUBMENU_PANEL_SIZE
	var network_style: StyleBoxFlat = StyleBoxFlat.new()
	network_style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	network_style.border_color = Color(0.35, 0.42, 0.55)
	network_style.set_border_width_all(2)
	network_style.set_corner_radius_all(8)
	network_style.set_content_margin_all(SUBMENU_CONTENT_MARGIN)
	_network_panel.add_theme_stylebox_override("panel", network_style)
	add_child(_network_panel)

	var network_vbox: VBoxContainer = VBoxContainer.new()
	network_vbox.custom_minimum_size = Vector2(SUBMENU_CONTENT_WIDTH, SUBMENU_PANEL_SIZE.y - (SUBMENU_CONTENT_MARGIN * 2))
	network_vbox.add_theme_constant_override("separation", 12)
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
	host_btn.custom_minimum_size = Vector2(SUBMENU_CONTENT_WIDTH, 40)
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

	var network_spacer: Control = Control.new()
	network_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	network_vbox.add_child(network_spacer)

	var network_buttons: HBoxContainer = HBoxContainer.new()
	network_buttons.add_theme_constant_override("separation", 12)
	network_vbox.add_child(network_buttons)

	var close_network_btn: Button = _create_spd_button("Back")
	close_network_btn.custom_minimum_size = Vector2(SUBMENU_ACTION_WIDTH, 40)
	close_network_btn.pressed.connect(func() -> void: _network_panel.visible = false)
	network_buttons.add_child(close_network_btn)

	var connect_btn: Button = _create_spd_button("Join Lobby")
	connect_btn.custom_minimum_size = Vector2(SUBMENU_ACTION_WIDTH, 40)
	connect_btn.pressed.connect(_on_network_join_host_pressed)
	network_buttons.add_child(connect_btn)

	_profile_panel = PanelContainer.new()
	_profile_panel.visible = false
	_profile_panel.position = _get_centered_submenu_position(SUBMENU_PANEL_SIZE)
	_profile_panel.custom_minimum_size = SUBMENU_PANEL_SIZE
	var profile_style: StyleBoxFlat = StyleBoxFlat.new()
	profile_style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	profile_style.border_color = Color(0.4, 0.35, 0.25)
	profile_style.set_border_width_all(2)
	profile_style.set_corner_radius_all(8)
	profile_style.set_content_margin_all(SUBMENU_CONTENT_MARGIN)
	_profile_panel.add_theme_stylebox_override("panel", profile_style)
	add_child(_profile_panel)

	var profile_vbox: VBoxContainer = VBoxContainer.new()
	profile_vbox.custom_minimum_size = Vector2(SUBMENU_CONTENT_WIDTH, SUBMENU_PANEL_SIZE.y - (SUBMENU_CONTENT_MARGIN * 2))
	profile_vbox.add_theme_constant_override("separation", 12)
	_profile_panel.add_child(profile_vbox)

	var profile_title: Label = Label.new()
	profile_title.text = "Player Profile"
	profile_title.add_theme_font_size_override("font_size", 22)
	profile_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	profile_vbox.add_child(profile_title)

	var profile_header: HBoxContainer = HBoxContainer.new()
	profile_header.add_theme_constant_override("separation", 20)
	profile_vbox.add_child(profile_header)

	var icon_column: VBoxContainer = VBoxContainer.new()
	icon_column.add_theme_constant_override("separation", 10)
	profile_header.add_child(icon_column)

	var icon_anchor: CenterContainer = CenterContainer.new()
	icon_anchor.custom_minimum_size = Vector2(92, 92)
	icon_column.add_child(icon_anchor)

	var circular_icon_script: GDScript = load("res://src/ui/components/circular_icon_view.gd") as GDScript
	_profile_icon_preview = circular_icon_script.new() if circular_icon_script else TextureRect.new()
	_profile_icon_preview.custom_minimum_size = Vector2(76, 76)
	_profile_icon_preview.size = Vector2(76, 76)
	if _profile_icon_preview.has_method("set_ring"):
		_profile_icon_preview.set_ring(Color(0.5, 0.45, 0.35), 0.03)
	icon_anchor.add_child(_profile_icon_preview)

	_profile_icon_edit_button = _create_spd_button("Edit", Vector2(92, 28))
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
	icon_note_label.text = "Profile icons unlock through class progress and enemy trophy milestones."
	icon_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	icon_note_label.add_theme_font_size_override("font_size", 12)
	icon_note_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	name_column.add_child(icon_note_label)

	_profile_name_edit = LineEdit.new()
	_profile_name_edit.visible = false
	profile_vbox.add_child(_profile_name_edit)

	_profile_summary_label = RichTextLabel.new()
	_profile_summary_label.bbcode_enabled = true
	_profile_summary_label.fit_content = false
	_profile_summary_label.scroll_active = false
	_profile_summary_label.custom_minimum_size = Vector2(0, 148)
	_profile_summary_label.add_theme_color_override("default_color", Color(0.82, 0.84, 0.9))
	profile_vbox.add_child(_profile_summary_label)

	var profile_spacer: Control = Control.new()
	profile_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	profile_vbox.add_child(profile_spacer)

	var profile_links: HBoxContainer = HBoxContainer.new()
	profile_links.add_theme_constant_override("separation", 12)
	profile_vbox.add_child(profile_links)

	var badges_btn: Button = _create_spd_button("Achievements")
	badges_btn.custom_minimum_size = Vector2(SUBMENU_ACTION_WIDTH, 40)
	badges_btn.pressed.connect(_on_badges_pressed)
	profile_links.add_child(badges_btn)

	var rankings_btn: Button = _create_spd_button("View Rankings")
	rankings_btn.custom_minimum_size = Vector2(SUBMENU_ACTION_WIDTH, 40)
	rankings_btn.pressed.connect(_on_rankings_pressed)
	profile_links.add_child(rankings_btn)

	var profile_actions: HBoxContainer = HBoxContainer.new()
	profile_actions.add_theme_constant_override("separation", 12)
	profile_vbox.add_child(profile_actions)

	var close_profile_btn: Button = _create_spd_button("Back")
	close_profile_btn.custom_minimum_size = Vector2(SUBMENU_ACTION_WIDTH, 40)
	close_profile_btn.pressed.connect(func() -> void: _profile_panel.visible = false)
	profile_actions.add_child(close_profile_btn)

	var save_profile_btn: Button = _create_spd_button("Save")
	save_profile_btn.custom_minimum_size = Vector2(SUBMENU_ACTION_WIDTH, 40)
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
	_profile_prompt_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_vbox.add_child(_profile_prompt_name_edit)

	var prompt_confirm_btn: Button = _create_spd_button("Continue")
	prompt_confirm_btn.custom_minimum_size = Vector2(220, 40)
	prompt_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_confirm_btn.pressed.connect(_on_profile_prompt_confirmed)
	prompt_vbox.add_child(prompt_confirm_btn)

	_settings_panel = PanelContainer.new()
	_settings_panel.visible = false
	_settings_panel.position = _get_centered_submenu_position(SUBMENU_PANEL_SIZE)
	_settings_panel.custom_minimum_size = SUBMENU_PANEL_SIZE
	var settings_style: StyleBoxFlat = StyleBoxFlat.new()
	settings_style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	settings_style.border_color = Color(0.4, 0.35, 0.25)
	settings_style.set_border_width_all(2)
	settings_style.set_corner_radius_all(8)
	settings_style.set_content_margin_all(SUBMENU_CONTENT_MARGIN)
	_settings_panel.add_theme_stylebox_override("panel", settings_style)
	add_child(_settings_panel)

	var settings_vbox: VBoxContainer = VBoxContainer.new()
	settings_vbox.custom_minimum_size = Vector2(SUBMENU_CONTENT_WIDTH, SUBMENU_PANEL_SIZE.y - (SUBMENU_CONTENT_MARGIN * 2))
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

	var settings_spacer: Control = Control.new()
	settings_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_vbox.add_child(settings_spacer)

	var settings_actions: HBoxContainer = HBoxContainer.new()
	settings_actions.add_theme_constant_override("separation", 12)
	settings_vbox.add_child(settings_actions)

	var close_settings_btn: Button = _create_spd_button("Back")
	close_settings_btn.custom_minimum_size = Vector2(SUBMENU_ACTION_WIDTH, 40)
	close_settings_btn.pressed.connect(func() -> void: _settings_panel.visible = false)
	settings_actions.add_child(close_settings_btn)

	var save_settings_btn: Button = _create_spd_button("Save")
	save_settings_btn.custom_minimum_size = Vector2(SUBMENU_ACTION_WIDTH, 40)
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
	return SaveManager != null and SaveManager.has_method("has_save") and SaveManager.has_save()


func _apply_layout() -> void:
	var viewport_size: Vector2 = _get_layout_viewport_size()
	_layout_viewport_size = viewport_size
	var is_portrait: bool = viewport_size.y > viewport_size.x
	var margin: float = 56.0 if is_portrait else 24.0
	var menu_width: float = _title_menu_width(viewport_size)
	var title_width: float = maxf(1.0, viewport_size.x - (margin * 2.0))
	var title_top: float = 64.0 if is_portrait else 20.0

	if _jmo_title_label:
		_jmo_title_label.add_theme_font_size_override("font_size", 58 if is_portrait else 72)
		_jmo_title_label.position = Vector2(margin, title_top)
		_jmo_title_label.custom_minimum_size = Vector2(title_width, 70 if is_portrait else 80)
		_jmo_title_label.size = _jmo_title_label.custom_minimum_size
	if _pd_title_label:
		_pd_title_label.add_theme_font_size_override("font_size", 28 if is_portrait else 40)
		_pd_title_label.position = Vector2(margin, title_top + (70.0 if is_portrait else 85.0))
		_pd_title_label.custom_minimum_size = Vector2(title_width, 42 if is_portrait else 50)
		_pd_title_label.size = _pd_title_label.custom_minimum_size
	if _menu_box:
		_menu_box.position = Vector2(floor((viewport_size.x - menu_width) * 0.5), title_top + (150.0 if is_portrait else 170.0))
		_menu_box.custom_minimum_size = Vector2(menu_width, 300)
		_menu_box.size = Vector2(menu_width, 300)
	if _top_menu_row:
		_top_menu_row.custom_minimum_size = Vector2(menu_width, 44)
		_top_menu_row.size = Vector2(menu_width, 44)
	if _btn_continue:
		var split_gap: float = 12.0
		_set_button_width(_btn_new_game, floor((menu_width - split_gap) * 0.62), 44)
		_set_button_width(_btn_continue, ceil((menu_width - split_gap) * 0.38), 44)
	elif _btn_new_game:
		_set_button_width(_btn_new_game, menu_width, 44)
	for btn: Button in [_btn_multiplayer, _btn_profile, _btn_settings]:
		if btn:
			_set_button_width(btn, menu_width, 44)
	if _version_label:
		_version_label.position = Vector2(maxf(margin, viewport_size.x - 70.0), maxf(margin, viewport_size.y - 24.0))

	var submenu_size: Vector2 = _get_submenu_panel_size()
	for panel: PanelContainer in [_network_panel, _profile_panel, _settings_panel]:
		if panel:
			panel.custom_minimum_size = submenu_size
			panel.size = submenu_size
			panel.position = _get_centered_submenu_position(submenu_size)
	if _profile_prompt_panel:
		var prompt_size: Vector2 = Vector2(minf(500.0, viewport_size.x - (margin * 2.0)), 220.0)
		_profile_prompt_panel.custom_minimum_size = prompt_size
		_profile_prompt_panel.size = prompt_size
		_profile_prompt_panel.position = _get_centered_submenu_position(prompt_size)
		_fit_panel_first_child(_profile_prompt_panel, prompt_size, 18.0)


func _fit_panel_first_child(panel: PanelContainer, panel_size: Vector2, content_margin: float) -> void:
	if panel == null or panel.get_child_count() == 0:
		return
	var child: Control = panel.get_child(0) as Control
	if child == null:
		return
	var content_size: Vector2 = Vector2(
		maxf(1.0, panel_size.x - (content_margin * 2.0)),
		maxf(1.0, panel_size.y - (content_margin * 2.0))
	)
	child.custom_minimum_size = content_size
	child.size = content_size


func _set_button_width(btn: Button, width: float, height: float) -> void:
	if btn == null:
		return
	var button_size: Vector2 = Vector2(width, height)
	btn.custom_minimum_size = button_size
	btn.size = button_size
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _title_menu_width(viewport_size: Vector2) -> float:
	var is_portrait: bool = viewport_size.y > viewport_size.x
	var margin: float = 56.0 if is_portrait else 24.0
	var max_width: float = PORTRAIT_MENU_MAX_WIDTH if is_portrait else 400.0
	return maxf(1.0, minf(max_width, viewport_size.x - (margin * 2.0)))


func _get_layout_viewport_size() -> Vector2:
	var engine_size: Vector2 = get_viewport_rect().size
	return _apply_mobile_safe_layout_reserve(_choose_layout_viewport_size(engine_size, _get_browser_viewport_size()))


func _choose_layout_viewport_size(engine_size: Vector2, browser_size: Vector2i) -> Vector2:
	if browser_size != Vector2i.ZERO and _should_layout_against_browser_size(browser_size):
		return Vector2(browser_size)
	return engine_size


func _get_browser_viewport_size() -> Vector2i:
	if OS.get_name() != "Web":
		return Vector2i.ZERO
	var js_result: Variant = JavaScriptBridge.eval(
		"(function(){var v=window.visualViewport;var w=v?v.width:window.innerWidth;var h=v?v.height:window.innerHeight;return Math.round(w)+'x'+Math.round(h);})()",
		true
	)
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
	if mini(browser_size.x, browser_size.y) < 760:
		return true
	return false


func _apply_mobile_safe_layout_reserve(viewport_size: Vector2) -> Vector2:
	if viewport_size.y <= viewport_size.x:
		return viewport_size
	return Vector2(maxf(1.0, viewport_size.x - 16.0), viewport_size.y)


func _get_submenu_panel_size() -> Vector2:
	var viewport_size: Vector2 = _layout_viewport_size if _layout_viewport_size != Vector2.ZERO else _get_layout_viewport_size()
	return Vector2(
		minf(SUBMENU_PANEL_SIZE.x, viewport_size.x - 24.0),
		minf(SUBMENU_PANEL_SIZE.y, viewport_size.y - 40.0)
	)


func _get_centered_submenu_position(panel_size: Vector2) -> Vector2:
	var viewport_size: Vector2 = _layout_viewport_size if _layout_viewport_size != Vector2.ZERO else _get_layout_viewport_size()
	return Vector2(
		maxf(12.0, floor((viewport_size.x - panel_size.x) * 0.5)),
		maxf(12.0, minf(SUBMENU_PANEL_TOP, floor((viewport_size.y - panel_size.y) * 0.5)))
	)


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
	var region: Rect2i = Rect2i(0, 90, 12, 15)
	match icon_id:
		"warrior", "mage", "rogue", "huntress", "duelist":
			region = Rect2i(0, 90, 12, 15)
		"rat":
			region = Rect2i(0, 0, 16, 15)
		"gnoll":
			region = Rect2i(0, 0, 12, 15)
		"crab":
			region = Rect2i(0, 0, 16, 16)
		"skeleton":
			region = Rect2i(0, 0, 12, 15)
		"goo":
			region = Rect2i(0, 0, 16, 14)
		_:
			region = Rect2i(0, 90, 12, 15)
	var source_image: Image = sheet.get_image()
	if source_image == null:
		return sheet
	var cropped_image: Image = source_image.get_region(region)
	return ImageTexture.create_from_image(cropped_image)

func _apply_profile_icon_crop(icon_view: Variant, icon_id: String) -> void:
	if icon_view == null or not icon_view.has_method("set_crop_adjustment"):
		return
	if ["warrior", "mage", "rogue", "huntress", "duelist"].has(icon_id):
		icon_view.set_crop_adjustment(1.24, Vector2(0.035, -0.03))
	else:
		icon_view.set_crop_adjustment(1.35, Vector2.ZERO)

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
	if PlayerProfile == null:
		return
	if _profile_icon_picker_window != null and is_instance_valid(_profile_icon_picker_window):
		return
	var picker_script: GDScript = load("res://src/ui/windows/wnd_profile_icon_picker.gd") as GDScript
	if picker_script == null:
		return
	_profile_icon_picker_window = picker_script.new()
	_profile_icon_picker_window.icon_selected.connect(_on_profile_icon_selected)
	_profile_icon_picker_window.window_closed.connect(func() -> void:
		_profile_icon_picker_window = null
	)
	add_child(_profile_icon_picker_window)

func _on_profile_icon_selected(icon_id: String) -> void:
	if PlayerProfile == null or not PlayerProfile.has_method("set_selected_icon_id"):
		return
	PlayerProfile.set_selected_icon_id(icon_id)
	if NetworkManager and NetworkManager.has_method("set_local_profile_icon_id"):
		NetworkManager.set_local_profile_icon_id(PlayerProfile.get_selected_icon_id())
	_refresh_profile_ui()

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
		var selected_icon_id: String = PlayerProfile.get_selected_icon_id()
		_profile_icon_preview.texture = _get_profile_icon_texture(selected_icon_id)
		_apply_profile_icon_crop(_profile_icon_preview, selected_icon_id)
	if _profile_icon_edit_button and PlayerProfile and PlayerProfile.has_method("get_unlocked_profile_icon_ids"):
		var unlocked_count: int = PlayerProfile.get_unlocked_profile_icon_ids().size()
		_profile_icon_edit_button.disabled = false
		_profile_icon_edit_button.tooltip_text = "Choose profile icon (%d unlocked)" % unlocked_count
	if _profile_summary_label == null or PlayerProfile == null:
		return
	var ranking_summary: Dictionary = PlayerProfile.get_rankings_summary()
	var unlocked_icons: int = 0
	if PlayerProfile.has_method("get_unlocked_profile_icon_ids"):
		unlocked_icons = PlayerProfile.get_unlocked_profile_icon_ids().size()
	_profile_summary_label.text = "[center][b]%s[/b][/center]\n\n[table=2]\n[cell][b]Profile Icons[/b][/cell][cell]%d/%d[/cell]\n[cell][b]Runs[/b][/cell][cell]%d[/cell]\n[cell][b]Victories[/b][/cell][cell]%d[/cell]\n[cell][b]Best Score[/b][/cell][cell]%d[/cell]\n[cell][b]Deepest Depth[/b][/cell][cell]%d[/cell]\n[/table]" % [
		PlayerProfile.get_badge_summary(),
		unlocked_icons,
		PlayerProfile.PROFILE_ICON_IDS.size() if PlayerProfile else 0,
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
