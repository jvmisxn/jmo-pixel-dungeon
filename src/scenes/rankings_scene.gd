class_name RankingsScene
extends Control
## Displays past run results from user://rankings.dat.

# --- State ---
var _rankings: Array[Dictionary] = []
var _scroll_container: ScrollContainer = null
var _list_container: VBoxContainer = null
var _confirm_panel: PanelContainer = null
var _bg_color_rect: ColorRect = null
var _back_clusters_sprite: TextureRect = null
var _mid_mixed_sprite: TextureRect = null
var _archs_sprite: TextureRect = null
var _main_panel: Panel = null

# --- Constants ---
const RANKINGS_PATH: String = "user://rankings.dat"
const BACK_CLUSTERS_PATH: String = "res://assets/spd/splashes/title/back_clusters.png"
const MID_MIXED_PATH: String = "res://assets/spd/splashes/title/mid_mixed.png"
const ARCHS_PATH: String = "res://assets/spd/splashes/title/archs.png"
const PANEL_SIZE: Vector2 = Vector2(980, 620)
const CLASS_ICONS: Array[String] = ["W", "M", "R", "H", "D"]
const CLASS_COLORS: Array[Color] = [
	Color(0.8, 0.3, 0.2),   # Warrior
	Color(0.3, 0.3, 0.9),   # Mage
	Color(0.5, 0.5, 0.5),   # Rogue
	Color(0.2, 0.7, 0.3),   # Huntress
	Color(0.8, 0.6, 0.9),   # Duelist
]

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load_rankings()
	_build_background()
	_build_ui()
	# Play title theme music (matches original RankingsScene.java)
	if AudioManager:
		AudioManager.play_theme_music()

func _process(_delta: float) -> void:
	var time_elapsed: float = float(Time.get_ticks_msec()) * 0.001
	if _back_clusters_sprite:
		_back_clusters_sprite.position.x = -fmod(time_elapsed * 2.0, 512.0)
	if _mid_mixed_sprite:
		_mid_mixed_sprite.position.x = -fmod(time_elapsed * 5.0, 2048.0)
	if _archs_sprite:
		_archs_sprite.position.x = -fmod(time_elapsed * 10.0, 1024.0)

func _unhandled_input(event: InputEvent) -> void:
	if _confirm_panel and _confirm_panel.visible:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				_confirm_panel.visible = false
				get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

func _load_rankings() -> void:
	if not FileAccess.file_exists(RANKINGS_PATH):
		_rankings = []
		return
	var file: FileAccess = FileAccess.open(RANKINGS_PATH, FileAccess.READ)
	if file == null:
		_rankings = []
		return
	var data: Variant = file.get_var()
	file.close()
	if data is Array:
		_rankings = data
	else:
		_rankings = []
	# Sort by score descending
	_rankings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("score", 0) > b.get("score", 0)
	)

func _save_rankings() -> void:
	var file: FileAccess = FileAccess.open(RANKINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_var(_rankings)
		file.close()

func _clear_rankings() -> void:
	_rankings = []
	_save_rankings()
	_rebuild_list()

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------

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
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_main_panel = Panel.new()
	_main_panel.position = Vector2(150, 60)
	_main_panel.custom_minimum_size = PANEL_SIZE
	_main_panel.size = PANEL_SIZE
	var main_style: StyleBoxFlat = StyleBoxFlat.new()
	main_style.bg_color = Color(0.08, 0.08, 0.11, 0.9)
	main_style.border_color = Color(0.48, 0.42, 0.3)
	main_style.set_border_width_all(2)
	main_style.set_corner_radius_all(8)
	_main_panel.add_theme_stylebox_override("panel", main_style)
	add_child(_main_panel)

	var title: Label = Label.new()
	title.text = "Rankings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.position = Vector2(340, 18)
	title.custom_minimum_size = Vector2(300, 50)
	_main_panel.add_child(title)

	# Scroll container for rankings list
	_scroll_container = ScrollContainer.new()
	_scroll_container.position = Vector2(30, 78)
	_scroll_container.custom_minimum_size = Vector2(920, 460)
	_scroll_container.size = Vector2(920, 460)
	_main_panel.add_child(_scroll_container)

	_list_container = VBoxContainer.new()
	_list_container.custom_minimum_size = Vector2(900, 0)
	_list_container.add_theme_constant_override("separation", 4)
	_scroll_container.add_child(_list_container)

	_rebuild_list()

	# Bottom buttons
	var btn_container: HBoxContainer = HBoxContainer.new()
	btn_container.position = Vector2(270, 552)
	btn_container.custom_minimum_size = Vector2(440, 50)
	btn_container.add_theme_constant_override("separation", 20)
	_main_panel.add_child(btn_container)

	var back_btn: Button = WndBase.create_spd_button("Back")
	back_btn.custom_minimum_size = Vector2(210, 44)
	back_btn.pressed.connect(_on_back_pressed)
	btn_container.add_child(back_btn)

	var clear_btn: Button = WndBase.create_spd_button("Clear Rankings")
	clear_btn.custom_minimum_size = Vector2(210, 44)
	clear_btn.pressed.connect(_on_clear_pressed)
	btn_container.add_child(clear_btn)

	# Confirmation panel (hidden)
	_confirm_panel = PanelContainer.new()
	_confirm_panel.visible = false
	_confirm_panel.position = Vector2(240, 230)
	_confirm_panel.custom_minimum_size = Vector2(500, 160)
	var confirm_style: StyleBoxFlat = StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.12, 0.1, 0.16)
	confirm_style.border_width_left = 2
	confirm_style.border_width_right = 2
	confirm_style.border_width_top = 2
	confirm_style.border_width_bottom = 2
	confirm_style.border_color = Color(0.8, 0.3, 0.3)
	_confirm_panel.add_theme_stylebox_override("panel", confirm_style)

	var confirm_vbox: VBoxContainer = VBoxContainer.new()
	confirm_vbox.add_theme_constant_override("separation", 20)
	_confirm_panel.add_child(confirm_vbox)

	var confirm_label: Label = Label.new()
	confirm_label.text = "Clear all rankings? This cannot be undone."
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.add_theme_font_size_override("font_size", 18)
	confirm_vbox.add_child(confirm_label)

	var confirm_btns: HBoxContainer = HBoxContainer.new()
	confirm_btns.add_theme_constant_override("separation", 40)
	confirm_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_vbox.add_child(confirm_btns)

	var yes_btn: Button = Button.new()
	yes_btn.text = "Yes, Clear"
	yes_btn.custom_minimum_size = Vector2(140, 38)
	yes_btn.pressed.connect(func() -> void:
		_clear_rankings()
		_confirm_panel.visible = false
	)
	confirm_btns.add_child(yes_btn)

	var no_btn: Button = Button.new()
	no_btn.text = "Cancel"
	no_btn.custom_minimum_size = Vector2(140, 38)
	no_btn.pressed.connect(func() -> void:
		_confirm_panel.visible = false
	)
	confirm_btns.add_child(no_btn)

	_main_panel.add_child(_confirm_panel)

func _rebuild_list() -> void:
	# Clear existing entries
	for child: Node in _list_container.get_children():
		child.queue_free()

	if _rankings.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No rankings yet. Complete a run to see results here."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		empty_label.custom_minimum_size = Vector2(900, 100)
		_list_container.add_child(empty_label)
		return

	# Header
	var header: HBoxContainer = _create_entry_row("#", "Player", "Class", "Depth", "Result", "Score", "Gold", true)
	_list_container.add_child(header)

	# Entries
	for i: int in range(_rankings.size()):
		var entry: Dictionary = _rankings[i]
		var rank_str: String = str(i + 1)
		var player_name: String = str(entry.get("player_name", "Player"))
		var class_idx: int = entry.get("hero_class", 0)
		var class_str: String = HeroClassData.get_class_name_str(class_idx)
		var depth_str: String = str(entry.get("depth", 0))
		var result_str: String = entry.get("cause", "Unknown")
		if entry.get("victory", false):
			result_str = "Victory!"
		var score_str: String = str(entry.get("score", 0))
		var gold_str: String = str(entry.get("gold", 0))

		var row: HBoxContainer = _create_entry_row(rank_str, player_name, class_str, depth_str, result_str, score_str, gold_str, false)
		# Alternate row coloring
		if i % 2 == 0:
			var bg: ColorRect = ColorRect.new()
			bg.color = Color(0.08, 0.07, 0.11, 0.5)
			bg.custom_minimum_size = Vector2(980, 36)
			bg.size = Vector2(980, 36)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(bg)
			row.move_child(bg, 0)
		_list_container.add_child(row)

func _create_entry_row(rank: String, player_name: String, cls: String, depth: String, result: String, score: String, gold: String, is_header: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(980, 36)
	row.add_theme_constant_override("separation", 0)

	var font_size: int = 16 if is_header else 15
	var font_color: Color = Color(0.9, 0.85, 0.6) if is_header else Color(0.8, 0.8, 0.85)

	var widths: Array[int] = [50, 170, 110, 70, 260, 100, 100]
	var texts: Array[String] = [rank, player_name, cls, depth, result, score, gold]

	for j: int in range(texts.size()):
		var lbl: Label = Label.new()
		lbl.text = texts[j]
		lbl.custom_minimum_size = Vector2(widths[j], 36)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.add_theme_color_override("font_color", font_color)
		if j == 0:
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(lbl)

	return row

# ---------------------------------------------------------------------------
# Button Callbacks
# ---------------------------------------------------------------------------

func _on_back_pressed() -> void:
	var title_script: GDScript = preload("res://src/scenes/title_scene.gd")
	SceneManager.go_to(title_script, "TitleScene")


func _on_clear_pressed() -> void:
	# Show confirmation panel instead of clearing immediately
	if _confirm_panel:
		_confirm_panel.visible = true
