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
var _players_list_container: VBoxContainer = null
var _ready_button: Button = null
var _start_button: Button = null
var _leave_button: Button = null
var _join_button: Button = null
var _class_label: Label = null
var _class_button_row: HBoxContainer = null
var _settings_panel: PanelContainer = null
var _settings_tabs: TabContainer = null
var _settings_general_tab: VBoxContainer = null
var _settings_coop_tab: VBoxContainer = null
var _join_panel: PanelContainer = null
var _join_address_edit: LineEdit = null
var _join_port_edit: LineEdit = null
var _settings_name_edit: LineEdit = null
var _settings_port_edit: LineEdit = null
var _settings_players_edit: LineEdit = null
var _main_panel: Panel = null
var _left_panel: Panel = null
var _right_panel: Panel = null
var _preview_panels: Array[Panel] = []
var _preview_sprites: Array[TextureRect] = []
var _hero_buttons: Array[Button] = []
var _selected_class: int = ConstantsData.HeroClass.WARRIOR

const BACK_CLUSTERS_PATH: String = "res://assets/spd/splashes/title/back_clusters.png"
const MID_MIXED_PATH: String = "res://assets/spd/splashes/title/mid_mixed.png"
const ARCHS_PATH: String = "res://assets/spd/splashes/title/archs.png"
const SPLASH_PATHS: Array[String] = [
	"res://assets/spd/splashes/warrior.jpg",
	"res://assets/spd/splashes/mage.jpg",
	"res://assets/spd/splashes/rogue.jpg",
	"res://assets/spd/splashes/huntress.jpg",
	"res://assets/spd/splashes/duelist.jpg",
]
const PANEL_SIZE: Vector2 = Vector2(760, 680)
const LEFT_PANEL_SIZE: Vector2 = Vector2(380, 640)
const RIGHT_PANEL_SIZE: Vector2 = Vector2(360, 620)
const SETTINGS_PANEL_SIZE: Vector2 = Vector2(460, 260)
const JOIN_PANEL_SIZE: Vector2 = Vector2(460, 220)
const SPRITE_PATHS: Array[String] = [
	"res://assets/spd/sprites/warrior.png",
	"res://assets/spd/sprites/mage.png",
	"res://assets/spd/sprites/rogue.png",
	"res://assets/spd/sprites/huntress.png",
	"res://assets/spd/sprites/duelist.png",
]
const PROFILE_ICON_SPRITES: Dictionary = {
	"warrior": "res://assets/spd/sprites/warrior.png",
	"mage": "res://assets/spd/sprites/mage.png",
	"rogue": "res://assets/spd/sprites/rogue.png",
	"huntress": "res://assets/spd/sprites/huntress.png",
	"duelist": "res://assets/spd/sprites/duelist.png",
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RenderingServer.set_default_clear_color(Color.BLACK)
	_selected_class = NetworkManager.get_local_lobby_class() if NetworkManager and NetworkManager.has_method("get_local_lobby_class") else ConstantsData.HeroClass.WARRIOR
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

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		if not (event is InputEventJoypadButton and event.pressed):
			return
	if _join_panel and _join_panel.visible:
		if _is_cancel_input(event):
			_join_panel.visible = false
			get_viewport().set_input_as_handled()
		elif _is_accept_input(event):
			_on_join_lobby_pressed()
			get_viewport().set_input_as_handled()
		return
	if _settings_panel and _settings_panel.visible:
		if _is_cancel_input(event):
			_settings_panel.visible = false
			get_viewport().set_input_as_handled()
		return
	if _is_left_input(event):
		_cycle_class(-1)
		get_viewport().set_input_as_handled()
	elif _is_right_input(event):
		_cycle_class(1)
		get_viewport().set_input_as_handled()
	elif _is_accept_input(event):
		_on_ready_pressed()
		get_viewport().set_input_as_handled()
	elif _is_cancel_input(event):
		_on_leave_pressed()
		get_viewport().set_input_as_handled()
	elif _is_aux_input(event):
		_on_settings_pressed()
		get_viewport().set_input_as_handled()

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
	_main_panel = Panel.new()
	_main_panel.custom_minimum_size = PANEL_SIZE
	_main_panel.size = PANEL_SIZE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.11, 0.9)
	style.border_color = Color(0.48, 0.42, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	_main_panel.add_theme_stylebox_override("panel", style)
	add_child(_main_panel)

	_left_panel = Panel.new()
	_left_panel.custom_minimum_size = LEFT_PANEL_SIZE
	_left_panel.size = LEFT_PANEL_SIZE
	var left_style: StyleBoxFlat = StyleBoxFlat.new()
	left_style.bg_color = Color(0.06, 0.06, 0.08, 0.45)
	left_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	left_style.set_border_width_all(0)
	left_style.set_corner_radius_all(6)
	_left_panel.add_theme_stylebox_override("panel", left_style)
	_main_panel.add_child(_left_panel)

	_right_panel = Panel.new()
	_right_panel.custom_minimum_size = RIGHT_PANEL_SIZE
	_right_panel.size = RIGHT_PANEL_SIZE
	_right_panel.clip_contents = true
	var right_style: StyleBoxFlat = StyleBoxFlat.new()
	right_style.bg_color = Color(0.05, 0.05, 0.07, 0.2)
	right_style.border_color = Color(0.22, 0.19, 0.14, 0.9)
	right_style.set_border_width_all(1)
	right_style.set_corner_radius_all(6)
	_right_panel.add_theme_stylebox_override("panel", right_style)
	_main_panel.add_child(_right_panel)

	for slot_index: int in range(GameManager.MAX_PARTY_SIZE):
		var preview_panel: Panel = Panel.new()
		preview_panel.clip_contents = true
		var preview_style: StyleBoxFlat = StyleBoxFlat.new()
		preview_style.bg_color = Color(0.03, 0.03, 0.05, 0.15)
		preview_style.border_color = Color(0.2, 0.17, 0.12, 0.7)
		preview_style.set_border_width_all(1)
		preview_style.set_corner_radius_all(4)
		preview_panel.add_theme_stylebox_override("panel", preview_style)
		_right_panel.add_child(preview_panel)
		_preview_panels.append(preview_panel)

		var preview_sprite: TextureRect = TextureRect.new()
		preview_sprite.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		preview_sprite.stretch_mode = TextureRect.STRETCH_SCALE
		preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		preview_panel.add_child(preview_sprite)
		_preview_sprites.append(preview_sprite)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.position = Vector2(22, 18)
	vbox.custom_minimum_size = Vector2(300, 604)
	_left_panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Co-op Lobby"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	vbox.add_child(title)

	_class_label = Label.new()
	_class_label.text = "Your Class"
	_class_label.add_theme_font_size_override("font_size", 12)
	_class_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.85))
	vbox.add_child(_class_label)

	_class_button_row = HBoxContainer.new()
	_class_button_row.custom_minimum_size = Vector2(300, 48)
	_class_button_row.add_theme_constant_override("separation", 4)
	vbox.add_child(_class_button_row)

	for class_index: int in range(SPRITE_PATHS.size()):
		var class_button: Button = _create_hero_button(class_index)
		_class_button_row.add_child(class_button)
		_hero_buttons.append(class_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	vbox.add_child(_status_label)

	var players_panel: Panel = Panel.new()
	players_panel.custom_minimum_size = Vector2(0, 300)
	var players_panel_style: StyleBoxFlat = StyleBoxFlat.new()
	players_panel_style.bg_color = Color(0.03, 0.03, 0.05, 0.25)
	players_panel_style.border_color = Color(0.2, 0.18, 0.14, 0.7)
	players_panel_style.set_border_width_all(1)
	players_panel_style.set_corner_radius_all(4)
	players_panel.add_theme_stylebox_override("panel", players_panel_style)
	vbox.add_child(players_panel)

	_players_list_container = VBoxContainer.new()
	_players_list_container.position = Vector2(10, 10)
	_players_list_container.custom_minimum_size = Vector2(280, 280)
	_players_list_container.add_theme_constant_override("separation", 8)
	players_panel.add_child(_players_list_container)

	var action_grid: GridContainer = GridContainer.new()
	action_grid.columns = 2
	action_grid.custom_minimum_size = Vector2(300, 92)
	action_grid.add_theme_constant_override("h_separation", 10)
	action_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(action_grid)

	var settings_button: Button = Button.new()
	settings_button.text = "Settings"
	settings_button.custom_minimum_size = Vector2(145, 42)
	settings_button.pressed.connect(_on_settings_pressed)
	action_grid.add_child(settings_button)

	_join_button = Button.new()
	_join_button.text = "Join"
	_join_button.custom_minimum_size = Vector2(145, 42)
	_join_button.pressed.connect(_on_open_join_panel_pressed)
	action_grid.add_child(_join_button)

	_leave_button = Button.new()
	_leave_button.text = "Back"
	_leave_button.custom_minimum_size = Vector2(145, 42)
	_leave_button.pressed.connect(_on_leave_pressed)
	action_grid.add_child(_leave_button)

	_ready_button = Button.new()
	_ready_button.text = "Ready Up"
	_ready_button.custom_minimum_size = Vector2(145, 42)
	_ready_button.pressed.connect(_on_ready_pressed)
	action_grid.add_child(_ready_button)

	var note: Label = Label.new()
	note.text = "Hosts open a lobby automatically here. Ready up first, then start once the whole party is ready. Clients can join another lobby from the Join button."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.65, 0.7, 0.76))
	vbox.add_child(note)

	var bottom_margin_spacer: Control = Control.new()
	bottom_margin_spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(bottom_margin_spacer)

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
	_main_panel.add_child(_settings_panel)

	var settings_vbox: VBoxContainer = VBoxContainer.new()
	settings_vbox.add_theme_constant_override("separation", 10)
	_settings_panel.add_child(settings_vbox)

	var settings_title: Label = Label.new()
	settings_title.text = "Lobby Settings"
	settings_title.add_theme_font_size_override("font_size", 20)
	settings_vbox.add_child(settings_title)

	_settings_tabs = TabContainer.new()
	_settings_tabs.custom_minimum_size = Vector2(420, 150)
	settings_vbox.add_child(_settings_tabs)

	_settings_general_tab = VBoxContainer.new()
	_settings_general_tab.name = "General"
	_settings_general_tab.add_theme_constant_override("separation", 8)
	_settings_tabs.add_child(_settings_general_tab)

	var settings_name_label: Label = Label.new()
	settings_name_label.text = "Player Name"
	_settings_general_tab.add_child(settings_name_label)

	_settings_name_edit = LineEdit.new()
	_settings_general_tab.add_child(_settings_name_edit)

	_settings_coop_tab = VBoxContainer.new()
	_settings_coop_tab.name = "Co-op"
	_settings_coop_tab.add_theme_constant_override("separation", 8)
	_settings_tabs.add_child(_settings_coop_tab)

	var settings_port_label: Label = Label.new()
	settings_port_label.text = "Host Port"
	_settings_coop_tab.add_child(settings_port_label)

	_settings_port_edit = LineEdit.new()
	_settings_port_edit.placeholder_text = "41234"
	_settings_coop_tab.add_child(_settings_port_edit)

	var settings_players_label: Label = Label.new()
	settings_players_label.text = "Player Cap"
	_settings_coop_tab.add_child(settings_players_label)

	_settings_players_edit = LineEdit.new()
	_settings_players_edit.placeholder_text = "4"
	_settings_coop_tab.add_child(_settings_players_edit)

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

	_join_panel = PanelContainer.new()
	_join_panel.visible = false
	_join_panel.custom_minimum_size = JOIN_PANEL_SIZE
	_join_panel.size = JOIN_PANEL_SIZE
	var join_style: StyleBoxFlat = StyleBoxFlat.new()
	join_style.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	join_style.border_color = Color(0.45, 0.5, 0.6)
	join_style.set_border_width_all(2)
	join_style.set_corner_radius_all(8)
	join_style.set_content_margin_all(16)
	_join_panel.add_theme_stylebox_override("panel", join_style)
	_main_panel.add_child(_join_panel)

	var join_vbox: VBoxContainer = VBoxContainer.new()
	join_vbox.add_theme_constant_override("separation", 10)
	_join_panel.add_child(join_vbox)

	var join_title: Label = Label.new()
	join_title.text = "Join Another Lobby"
	join_title.add_theme_font_size_override("font_size", 20)
	join_vbox.add_child(join_title)

	var join_desc: Label = Label.new()
	join_desc.text = "Leave your current hosted lobby and connect to another host."
	join_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	join_vbox.add_child(join_desc)

	var join_address_label: Label = Label.new()
	join_address_label.text = "Lobby IP"
	join_vbox.add_child(join_address_label)

	_join_address_edit = LineEdit.new()
	_join_address_edit.placeholder_text = "127.0.0.1"
	join_vbox.add_child(_join_address_edit)

	var join_port_label: Label = Label.new()
	join_port_label.text = "Port"
	join_vbox.add_child(join_port_label)

	_join_port_edit = LineEdit.new()
	_join_port_edit.placeholder_text = "41234"
	join_vbox.add_child(_join_port_edit)

	var join_buttons: HBoxContainer = HBoxContainer.new()
	join_buttons.add_theme_constant_override("separation", 8)
	join_vbox.add_child(join_buttons)

	var close_join_button: Button = Button.new()
	close_join_button.text = "Back"
	close_join_button.custom_minimum_size = Vector2(140, 38)
	close_join_button.pressed.connect(func() -> void: _join_panel.visible = false)
	join_buttons.add_child(close_join_button)

	var confirm_join_button: Button = Button.new()
	confirm_join_button.text = "Join"
	confirm_join_button.custom_minimum_size = Vector2(140, 38)
	confirm_join_button.pressed.connect(_on_join_lobby_pressed)
	join_buttons.add_child(confirm_join_button)

func _apply_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if _main_panel != null:
		_main_panel.position = Vector2(
			floor((viewport_size.x - PANEL_SIZE.x) * 0.5),
			20
		)
		var left_x: float = 20.0
		var left_y: float = 20.0
		var right_x: float = floor(PANEL_SIZE.x * 0.5)
		var right_y: float = floor((PANEL_SIZE.y - RIGHT_PANEL_SIZE.y) * 0.5)
		if _left_panel != null:
			_left_panel.position = Vector2(left_x, left_y)
		if _right_panel != null:
			_right_panel.position = Vector2(right_x, right_y)
	if _settings_panel != null and _main_panel != null:
		_settings_panel.position = Vector2(
			floor((_main_panel.size.x - SETTINGS_PANEL_SIZE.x) * 0.5),
			80
		)
	if _join_panel != null and _main_panel != null:
		_join_panel.position = Vector2(
			floor((_main_panel.size.x - JOIN_PANEL_SIZE.x) * 0.5),
			110
		)
	_update_preview_layout()

func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _create_hero_button(class_index: int) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(50, 44)
	btn.tooltip_text = HeroClassData.get_class_name_str(class_index)
	var icon_tex: Texture2D = _get_hero_icon(class_index)
	if icon_tex:
		btn.icon = icon_tex
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.pressed.connect(_on_class_button_pressed.bind(class_index))
	_apply_class_button_style(btn, class_index == _selected_class)
	return btn

func _get_hero_icon(class_index: int) -> Texture2D:
	if class_index < 0 or class_index >= SPRITE_PATHS.size():
		return null
	var sheet_path: String = SPRITE_PATHS[class_index]
	if not ResourceLoader.exists(sheet_path):
		return null
	var sheet: Texture2D = load(sheet_path) as Texture2D
	if sheet == null:
		return null
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0, 90, 12, 15)
	return atlas

func _get_profile_icon(icon_id: String) -> Texture2D:
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

func _apply_class_button_style(btn: Button, is_selected: bool) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.16, 0.14, 0.9) if is_selected else Color(0.12, 0.11, 0.10, 0.85)
	normal.border_color = Color(1.0, 0.85, 0.3) if is_selected else Color(0.3, 0.28, 0.25)
	normal.set_border_width_all(2 if is_selected else 1)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 4.0
	normal.content_margin_right = 4.0
	normal.content_margin_top = 4.0
	normal.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override("normal", normal)

func _cycle_class(step: int) -> void:
	var next_class: int = posmod(_selected_class + step, SPRITE_PATHS.size())
	_on_class_button_pressed(next_class)

func _on_class_button_pressed(class_index: int) -> void:
	_selected_class = class_index
	if NetworkManager and NetworkManager.has_method("set_local_lobby_class"):
		NetworkManager.set_local_lobby_class(class_index)
	_refresh()

func _is_accept_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
	if event is InputEventJoypadButton:
		return event.button_index == JOY_BUTTON_A
	return false

func _is_cancel_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.keycode == KEY_ESCAPE
	if event is InputEventJoypadButton:
		return event.button_index == JOY_BUTTON_B
	return false

func _is_aux_input(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return event.button_index == JOY_BUTTON_X
	return false

func _is_left_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.keycode == KEY_LEFT
	if event is InputEventJoypadButton:
		return event.button_index == JOY_BUTTON_DPAD_LEFT
	return false

func _is_right_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.keycode == KEY_RIGHT
	if event is InputEventJoypadButton:
		return event.button_index == JOY_BUTTON_DPAD_RIGHT
	return false

func _refresh() -> void:
	if _status_label == null or _players_list_container == null:
		return
	if NetworkManager and NetworkManager.has_method("get_local_lobby_class"):
		_selected_class = NetworkManager.get_local_lobby_class()
	if _class_label:
		_class_label.text = "Your Class: %s" % HeroClassData.get_class_name_str(_selected_class)
	for idx: int in range(_hero_buttons.size()):
		_apply_class_button_style(_hero_buttons[idx], idx == _selected_class)
	if NetworkManager:
		var phase_label: String = NetworkManager.get_session_phase_label() if NetworkManager.has_method("get_session_phase_label") else ""
		_status_label.text = NetworkManager.get_connection_label()
		if NetworkManager.has_method("is_host") and NetworkManager.is_host() and NetworkManager.has_method("get_preferred_bind_address"):
			_status_label.text += "\nHost IP: %s" % NetworkManager.get_preferred_bind_address()
		if not phase_label.is_empty():
			_status_label.text += "\n" + phase_label
		if NetworkManager.has_method("get_ready_summary"):
			_status_label.text += "\n" + NetworkManager.get_ready_summary()
	else:
		_status_label.text = "Offline"
	var players: Array = NetworkManager.get_lobby_players() if NetworkManager else []
	for child: Node in _players_list_container.get_children():
		child.queue_free()
	for player_entry: Variant in players:
		if not player_entry is Dictionary:
			continue
		var entry: Dictionary = player_entry
		var peer_id: int = int(entry.get("peer_id", -1))
		var player_name: String = str(entry.get("name", "Player"))
		var ready: bool = bool(entry.get("ready", false))
		var hero_class_name: String = HeroClassData.get_class_name_str(int(entry.get("chosen_class", ConstantsData.HeroClass.WARRIOR)))
		var profile_icon_id: String = str(entry.get("profile_icon_id", "warrior"))
		var host_suffix: String = " [Host]" if peer_id == 1 else ""
		var ready_text: String = "Ready" if ready else "Not Ready"
		var row: HBoxContainer = HBoxContainer.new()
		row.custom_minimum_size = Vector2(280, 36)
		row.add_theme_constant_override("separation", 8)
		_players_list_container.add_child(row)

		var icon_holder: Panel = Panel.new()
		icon_holder.custom_minimum_size = Vector2(28, 28)
		var icon_holder_style: StyleBoxFlat = StyleBoxFlat.new()
		icon_holder_style.bg_color = Color(0.12, 0.11, 0.1, 0.9)
		icon_holder_style.border_color = Color(0.35, 0.31, 0.24)
		icon_holder_style.set_border_width_all(1)
		icon_holder_style.set_corner_radius_all(4)
		icon_holder.add_theme_stylebox_override("panel", icon_holder_style)
		row.add_child(icon_holder)

		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.position = Vector2(5, 5)
		icon_rect.size = Vector2(18, 18)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.texture = _get_profile_icon(profile_icon_id)
		icon_holder.add_child(icon_rect)

		var row_label: Label = Label.new()
		row_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_label.add_theme_font_size_override("font_size", 12)
		row_label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.9))
		row_label.text = "%s%s - %s (%s)" % [player_name, host_suffix, ready_text, hero_class_name]
		row.add_child(row_label)
	if players.is_empty():
		var empty_label: Label = Label.new()
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.9))
		empty_label.text = "Waiting for players..."
		_players_list_container.add_child(empty_label)
	_update_preview_splashes(players)

	var is_host: bool = NetworkManager != null and NetworkManager.has_method("is_host") and NetworkManager.is_host()
	var is_ready: bool = NetworkManager != null and NetworkManager.has_method("is_local_ready") and NetworkManager.is_local_ready()
	var run_active: bool = NetworkManager != null and NetworkManager.has_method("has_active_run") and NetworkManager.has_active_run()
	if _join_button:
		_join_button.disabled = run_active
	if _ready_button:
		_ready_button.visible = not run_active
		if is_host:
			if not is_ready:
				_ready_button.text = "Ready Up"
				_ready_button.disabled = false
				_ready_button.tooltip_text = "Mark yourself ready first."
			else:
				_ready_button.text = "Start Run"
				_ready_button.disabled = not (NetworkManager != null and NetworkManager.has_method("can_host_start_run") and NetworkManager.can_host_start_run())
				_ready_button.tooltip_text = "All connected players must be ready before the host can start." if _ready_button.disabled else ""
		else:
			_ready_button.text = "Unready" if is_ready else "Ready Up"
			_ready_button.disabled = false
			_ready_button.tooltip_text = ""
	if _settings_tabs and _settings_coop_tab:
		_settings_coop_tab.visible = is_host
		var coop_tab_index: int = _settings_coop_tab.get_index()
		_settings_tabs.set_tab_hidden(coop_tab_index, not is_host)
		if not is_host and _settings_tabs.current_tab == coop_tab_index:
			_settings_tabs.current_tab = 0
	if _settings_port_edit:
		_settings_port_edit.editable = is_host
	if _settings_players_edit:
		_settings_players_edit.editable = is_host
	if _settings_name_edit and NetworkManager:
		_settings_name_edit.text = NetworkManager.local_player_name
	if _settings_port_edit and NetworkManager:
		_settings_port_edit.text = str(NetworkManager.listen_port if NetworkManager.listen_port > 0 else NetworkManager.DEFAULT_PORT)
	if _settings_players_edit and NetworkManager:
		_settings_players_edit.text = str(NetworkManager.max_players if NetworkManager.max_players > 0 else NetworkManager.DEFAULT_MAX_PLAYERS)

func _update_preview_splashes(players: Array) -> void:
	var active_count: int = clampi(players.size(), 1, GameManager.MAX_PARTY_SIZE)
	for idx: int in range(_preview_panels.size()):
		var preview_panel: Panel = _preview_panels[idx]
		var preview_sprite: TextureRect = _preview_sprites[idx]
		var is_active: bool = idx < active_count
		preview_panel.visible = is_active
		if not is_active:
			continue
		var hero_class: int = ConstantsData.HeroClass.WARRIOR
		if idx < players.size() and players[idx] is Dictionary:
			hero_class = int((players[idx] as Dictionary).get("chosen_class", hero_class))
		var splash_path: String = SPLASH_PATHS[clampi(hero_class, 0, SPLASH_PATHS.size() - 1)]
		preview_sprite.texture = _load_texture(splash_path)
		_update_preview_sprite(idx, active_count)

func _update_preview_layout() -> void:
	if _right_panel == null:
		return
	var players: Array = NetworkManager.get_lobby_players() if NetworkManager and NetworkManager.has_method("get_lobby_players") else []
	var active_count: int = clampi(players.size(), 1, GameManager.MAX_PARTY_SIZE)
	var gap: float = 8.0
	var slot_height: float = floor((_right_panel.size.y - (gap * float(active_count - 1))) / float(active_count))
	for idx: int in range(_preview_panels.size()):
		var preview_panel: Panel = _preview_panels[idx]
		if idx >= active_count:
			preview_panel.visible = false
			continue
		preview_panel.visible = true
		preview_panel.position = Vector2(0, float(idx) * (slot_height + gap))
		preview_panel.size = Vector2(_right_panel.size.x, slot_height)
		_update_preview_sprite(idx, active_count)

func _update_preview_sprite(idx: int, _active_count: int) -> void:
	if idx < 0 or idx >= _preview_panels.size() or idx >= _preview_sprites.size():
		return
	var preview_panel: Panel = _preview_panels[idx]
	var preview_sprite: TextureRect = _preview_sprites[idx]
	var texture: Texture2D = preview_sprite.texture
	if preview_panel == null or preview_sprite == null or texture == null:
		return
	var pane_size: Vector2 = preview_panel.size
	var tex_size: Vector2 = texture.get_size()
	if pane_size.x <= 0.0 or pane_size.y <= 0.0 or tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scale_factor: float = max(pane_size.x / tex_size.x, pane_size.y / tex_size.y)
	var draw_size: Vector2 = tex_size * scale_factor
	preview_sprite.size = draw_size
	preview_sprite.position = Vector2(
		floor((pane_size.x - draw_size.x) * 0.5),
		floor((pane_size.y - draw_size.y) * 0.5)
	)

func _on_ready_pressed() -> void:
	if NetworkManager == null or (NetworkManager.has_method("has_active_run") and NetworkManager.has_active_run()):
		return
	if NetworkManager.has_method("is_host") and NetworkManager.is_host():
		if NetworkManager.is_local_ready():
			_on_start_pressed()
		else:
			NetworkManager.set_local_ready(true)
		return
	NetworkManager.set_local_ready(not NetworkManager.is_local_ready())

func _on_start_pressed() -> void:
	if NetworkManager and NetworkManager.has_method("has_active_run") and NetworkManager.has_active_run():
		return
	if NetworkManager and NetworkManager.has_method("is_host") and NetworkManager.is_host():
		if not (NetworkManager.has_method("can_host_start_run") and NetworkManager.can_host_start_run()):
			return
		NetworkManager.start_online_run({
			"run_seed": randi(),
		})

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

func _on_open_join_panel_pressed() -> void:
	if _join_panel:
		_join_panel.visible = true
	if _join_address_edit:
		_join_address_edit.text = "127.0.0.1"
		_join_address_edit.grab_focus()
	if _join_port_edit and NetworkManager:
		_join_port_edit.text = str(NetworkManager.listen_port if NetworkManager.listen_port > 0 else NetworkManager.DEFAULT_PORT)

func _on_join_lobby_pressed() -> void:
	if NetworkManager == null:
		return
	var address: String = _join_address_edit.text.strip_edges() if _join_address_edit else ""
	var port: int = int(_join_port_edit.text) if _join_port_edit and not _join_port_edit.text.strip_edges().is_empty() else NetworkManager.DEFAULT_PORT
	if PlayerProfile:
		NetworkManager.set_local_player_name(PlayerProfile.get_player_name())
		if NetworkManager.has_method("set_local_profile_icon_id"):
			NetworkManager.set_local_profile_icon_id(PlayerProfile.get_selected_icon_id())
	if port <= 0:
		port = NetworkManager.DEFAULT_PORT
	NetworkManager.join_game(address, port)
	if _join_panel:
		_join_panel.visible = false

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

func _on_lobby_start_requested() -> void:
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
