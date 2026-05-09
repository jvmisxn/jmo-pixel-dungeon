class_name DeathScene
extends Control
## Shown when the hero dies. Uses original SPD assets and styling.
## Displays hero avatar, death info, run stats, and action buttons.
## Automatically saves the run to rankings.

# --- State ---
var _final_score: int = 0
var _cause_of_death: String = "Unknown causes"

# --- Constants ---
const RANKINGS_PATH: String = "user://rankings.dat"
const GOLD_COLOR: Color = Color(1.0, 0.85, 0.3)
const ARCHS_PATH: String = "res://assets/spd/splashes/title/archs.png"

# Hero spritesheet paths (for avatar display)
const SPRITE_PATHS: Array[String] = [
	"res://assets/spd/sprites/warrior.png",
	"res://assets/spd/sprites/mage.png",
	"res://assets/spd/sprites/rogue.png",
	"res://assets/spd/sprites/huntress.png",
	"res://assets/spd/sprites/duelist.png",
]

# Region splash paths for background ambiance
const REGION_SPLASHES: Dictionary = {
	ConstantsData.Region.SEWERS: "res://assets/spd/splashes/sewers.jpg",
	ConstantsData.Region.PRISON: "res://assets/spd/splashes/prison.jpg",
	ConstantsData.Region.CAVES:  "res://assets/spd/splashes/caves.jpg",
	ConstantsData.Region.CITY:   "res://assets/spd/splashes/city.jpg",
	ConstantsData.Region.HALLS:  "res://assets/spd/splashes/halls.jpg",
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Read cause of death from metadata if set
	if has_meta("cause_of_death"):
		_cause_of_death = get_meta("cause_of_death") as String

	_final_score = GameManager.compute_final_score()
	_save_ranking()
	_build_ui()

	# Play theme music on death screen (matches original)
	if AudioManager:
		AudioManager.play_theme_music()

	# End game
	GameManager.end_game(false)
	# Delete saves from both systems
	if SaveManager:
		SaveManager.delete_save()
	GameManager.delete_save()

# ---------------------------------------------------------------------------
# Rankings
# ---------------------------------------------------------------------------

func _save_ranking() -> void:
	var entry: Dictionary = {
		"hero_class": GameManager.hero_class,
		"depth": GameManager.depth,
		"score": _final_score,
		"gold": GameManager.gold,
		"victory": false,
		"cause": _cause_of_death,
		"enemies_slain": GameManager.stats.get("enemies_slain", 0),
		"items_used": GameManager.stats.get("potions_used", 0) + GameManager.stats.get("scrolls_used", 0),
	}

	# Use SaveManager if available, fallback to manual file write
	if SaveManager:
		SaveManager.save_ranking(entry)
	else:
		var rankings: Array[Dictionary] = []
		if FileAccess.file_exists(RANKINGS_PATH):
			var file: FileAccess = FileAccess.open(RANKINGS_PATH, FileAccess.READ)
			if file:
				var data: Variant = file.get_var()
				file.close()
				if data is Array:
					rankings = data
		rankings.append(entry)
		var file: FileAccess = FileAccess.open(RANKINGS_PATH, FileAccess.WRITE)
		if file:
			file.store_var(rankings)
			file.close()

# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- Dark background ---
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.04, 0.06)
	add_child(bg)

	# --- Region splash as subtle background ---
	var region: int = _get_death_region()
	var splash_path: String = REGION_SPLASHES.get(region, REGION_SPLASHES[ConstantsData.Region.SEWERS])
	if ResourceLoader.exists(splash_path):
		var splash_tex: Texture2D = load(splash_path) as Texture2D
		if splash_tex:
			var splash_rect: TextureRect = TextureRect.new()
			splash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			splash_rect.texture = splash_tex
			splash_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			splash_rect.modulate = Color(0.25, 0.2, 0.2, 0.6)
			splash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(splash_rect)

	# --- Darkening overlay ---
	var dark_overlay: ColorRect = ColorRect.new()
	dark_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark_overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	dark_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark_overlay)

	# --- Central content panel (properly centered using anchors) ---
	var center_panel: VBoxContainer = VBoxContainer.new()
	center_panel.add_theme_constant_override("separation", 6)
	# Use anchor-based centering: anchor to center, then offset by half-size
	center_panel.anchor_left = 0.5
	center_panel.anchor_right = 0.5
	center_panel.anchor_top = 0.0
	center_panel.anchor_bottom = 1.0
	center_panel.offset_left = -260
	center_panel.offset_right = 260
	center_panel.offset_top = 30
	center_panel.offset_bottom = -20
	add_child(center_panel)

	# --- "You died..." title ---
	var death_title: Label = Label.new()
	death_title.text = "You died..."
	death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_title.add_theme_font_size_override("font_size", 32)
	death_title.add_theme_color_override("font_color", Color(0.85, 0.15, 0.1))
	center_panel.add_child(death_title)

	# --- Hero info row (avatar + class + depth) ---
	var info_row: HBoxContainer = HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 16)
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center_panel.add_child(info_row)

	# Hero avatar (from spritesheet, 12x15 scaled up)
	var avatar: TextureRect = TextureRect.new()
	var avatar_tex: Texture2D = _get_hero_avatar()
	if avatar_tex:
		avatar.texture = avatar_tex
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.custom_minimum_size = Vector2(48, 60)
		avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	info_row.add_child(avatar)

	# Hero class name + depth
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_row.add_child(info_vbox)

	var class_name_str: String = HeroClassData.get_class_name_str(GameManager.hero_class)
	var class_label: Label = Label.new()
	class_label.text = class_name_str
	class_label.add_theme_font_size_override("font_size", 20)
	class_label.add_theme_color_override("font_color", GOLD_COLOR)
	info_vbox.add_child(class_label)

	var depth_label: Label = Label.new()
	depth_label.text = "Depth %d" % GameManager.depth
	depth_label.add_theme_font_size_override("font_size", 16)
	depth_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	info_vbox.add_child(depth_label)

	# Cause of death
	var cause_label: Label = Label.new()
	cause_label.text = "Killed by: %s" % _cause_of_death
	cause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cause_label.add_theme_font_size_override("font_size", 14)
	cause_label.add_theme_color_override("font_color", Color(0.65, 0.3, 0.3))
	center_panel.add_child(cause_label)

	# --- Separator ---
	var sep1: HSeparator = HSeparator.new()
	sep1.add_theme_stylebox_override("separator", _make_separator_style())
	center_panel.add_child(sep1)

	# --- Stats panel ---
	var stats_panel: PanelContainer = PanelContainer.new()
	stats_panel.custom_minimum_size = Vector2(450, 0)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.05, 0.08, 0.85)
	panel_style.border_color = Color(0.25, 0.2, 0.2)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(3)
	panel_style.content_margin_left = 20.0
	panel_style.content_margin_right = 20.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 12.0
	stats_panel.add_theme_stylebox_override("panel", panel_style)
	center_panel.add_child(stats_panel)

	var stats_vbox: VBoxContainer = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 4)
	stats_panel.add_child(stats_vbox)

	var stats_title: Label = Label.new()
	stats_title.text = "Run Summary"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_font_size_override("font_size", 16)
	stats_title.add_theme_color_override("font_color", GOLD_COLOR)
	stats_vbox.add_child(stats_title)

	_add_stat_line(stats_vbox, "Enemies Slain", str(GameManager.stats.get("enemies_slain", 0)))
	_add_stat_line(stats_vbox, "Bosses Defeated", str(GameManager.stats.get("bosses_slain", 0)))
	_add_stat_line(stats_vbox, "Items Collected", str(GameManager.stats.get("items_collected", 0)))
	_add_stat_line(stats_vbox, "Potions Used", str(GameManager.stats.get("potions_used", 0)))
	_add_stat_line(stats_vbox, "Scrolls Used", str(GameManager.stats.get("scrolls_used", 0)))
	_add_stat_line(stats_vbox, "Food Eaten", str(GameManager.stats.get("food_eaten", 0)))
	_add_stat_line(stats_vbox, "Gold Collected", str(GameManager.gold))
	_add_stat_line(stats_vbox, "Depths Explored", str(GameManager.depth))

	var sep2: HSeparator = HSeparator.new()
	sep2.add_theme_stylebox_override("separator", _make_separator_style())
	stats_vbox.add_child(sep2)

	_add_stat_line(stats_vbox, "FINAL SCORE", str(_final_score), GOLD_COLOR)

	# --- Action buttons ---
	var btn_container: HBoxContainer = HBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 20)
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	center_panel.add_child(btn_container)

	var menu_btn: Button = _create_chrome_button("Main Menu")
	menu_btn.pressed.connect(_on_menu_pressed)
	btn_container.add_child(menu_btn)

	var try_again_btn: Button = _create_chrome_button("Try Again")
	try_again_btn.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	try_again_btn.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.7))
	try_again_btn.pressed.connect(_on_try_again_pressed)
	btn_container.add_child(try_again_btn)

	var rankings_btn: Button = _create_chrome_button("Rankings")
	rankings_btn.pressed.connect(_on_rankings_pressed)
	btn_container.add_child(rankings_btn)


func _make_separator_style() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.3, 0.25, 0.2, 0.5)
	s.content_margin_top = 1.0
	s.content_margin_bottom = 1.0
	return s


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_death_region() -> int:
	if GameManager:
		return ConstantsData.region_for_depth(GameManager.depth)
	return ConstantsData.Region.SEWERS


func _get_hero_avatar() -> Texture2D:
	var class_idx: int = GameManager.hero_class if GameManager else 0
	if class_idx < 0 or class_idx >= SPRITE_PATHS.size():
		return null
	var path: String = SPRITE_PATHS[class_idx]
	if not ResourceLoader.exists(path):
		return null
	var sheet: Texture2D = load(path) as Texture2D
	if sheet == null:
		return null
	# Extract 12x15 icon from y=0 (front-facing idle frame)
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0, 0, 12, 15)
	return atlas


func _add_stat_line(parent_vbox: VBoxContainer, label_text: String, value_text: String, value_color: Color = Color(0.8, 0.8, 0.85)) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.58, 0.55))
	row.add_child(lbl)

	var val: Label = Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 14)
	val.add_theme_color_override("font_color", value_color)
	row.add_child(val)

	parent_vbox.add_child(row)


func _create_chrome_button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(130, 38)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.65, 0.5))

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.14, 0.12, 0.9)
	normal.border_color = Color(0.4, 0.36, 0.30)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.20, 0.16, 0.95)
	hover.border_color = Color(0.55, 0.50, 0.40)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.10, 0.09, 0.07)
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn


# ---------------------------------------------------------------------------
# Button Callbacks
# ---------------------------------------------------------------------------

func _on_menu_pressed() -> void:
	var title_script: GDScript = preload("res://src/scenes/title_scene.gd")
	SceneManager.go_to(title_script, "TitleScene")


func _on_try_again_pressed() -> void:
	var hero_select_script: GDScript = preload("res://src/scenes/hero_select_scene.gd")
	SceneManager.go_to(hero_select_script, "HeroSelectScene")


func _on_rankings_pressed() -> void:
	var rankings_script: GDScript = preload("res://src/scenes/rankings_scene.gd")
	SceneManager.go_to(rankings_script, "RankingsScene")
