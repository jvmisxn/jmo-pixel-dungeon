class_name SurfaceScene
extends Control
## Victory/surface scene shown when the hero ascends with the Amulet of Yendor.
## Displays congratulations, score breakdown, and celebratory particles.

# --- State ---
var _final_score: int = 0
var _depth_bonus: int = 0
var _gold_bonus: int = 0
var _enemy_bonus: int = 0
var _victory_bonus: int = 5000
var _time_elapsed: float = 0.0
var _particles: Array[Dictionary] = []

# --- Constants ---
const RANKINGS_PATH: String = "user://rankings.dat"
const PARTICLE_COUNT: int = 60

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_compute_score()
	_save_ranking()
	_generate_particles()
	_build_ui()

	# Play theme music — original SurfaceScene plays theme_2 then theme_1
	if AudioManager:
		AudioManager.play_theme_music()

func _process(delta: float) -> void:
	_time_elapsed += delta
	_update_particles(delta)
	queue_redraw()

func _draw() -> void:
	# Sky gradient background
	draw_rect(Rect2(0, 0, 1280, 360), Color(0.2, 0.4, 0.7))
	draw_rect(Rect2(0, 360, 1280, 360), Color(0.3, 0.6, 0.3))

	# Sun
	var sun_y: float = 120.0 + 10.0 * sin(_time_elapsed * 0.5)
	draw_circle(Vector2(640, sun_y), 50.0, Color(1.0, 0.9, 0.4, 0.9))
	draw_circle(Vector2(640, sun_y), 60.0, Color(1.0, 0.9, 0.4, 0.2))

	# Gold sparkle particles
	for p: Dictionary in _particles:
		var alpha: float = p["life"] as float
		var particle_color: Color = Color(1.0, 0.85, 0.2, alpha * 0.8)
		var pos: Vector2 = p["pos"] as Vector2
		var particle_size: float = p["size"] as float
		draw_rect(Rect2(pos.x - particle_size * 0.5, pos.y - particle_size * 0.5, particle_size, particle_size), particle_color)

# ---------------------------------------------------------------------------
# Score Computation
# ---------------------------------------------------------------------------

func _compute_score() -> void:
	_depth_bonus = GameManager.depth * 100
	@warning_ignore("integer_division")
	_gold_bonus = GameManager.gold / 10
	_enemy_bonus = GameManager.stats.get("enemies_slain", 0) * 10
	_victory_bonus = 5000
	_final_score = GameManager.compute_final_score()

# ---------------------------------------------------------------------------
# Particles
# ---------------------------------------------------------------------------

func _generate_particles() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for i: int in range(PARTICLE_COUNT):
		var p: Dictionary = {
			"pos": Vector2(rng.randf_range(100, 1180), rng.randf_range(50, 670)),
			"vel": Vector2(rng.randf_range(-20, 20), rng.randf_range(-40, -10)),
			"life": rng.randf_range(0.3, 1.0),
			"max_life": 1.0,
			"size": rng.randf_range(3.0, 8.0),
			"phase": rng.randf_range(0.0, TAU),
		}
		p["max_life"] = p["life"]
		_particles.append(p)

func _update_particles(delta: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for p: Dictionary in _particles:
		var pos: Vector2 = p["pos"] as Vector2
		var vel: Vector2 = p["vel"] as Vector2
		p["pos"] = pos + vel * delta
		p["life"] = (p["life"] as float) - delta * 0.3

		# Respawn dead particles
		if (p["life"] as float) <= 0.0:
			p["pos"] = Vector2(rng.randf_range(100, 1180), rng.randf_range(400, 700))
			p["vel"] = Vector2(rng.randf_range(-20, 20), rng.randf_range(-50, -15))
			p["life"] = rng.randf_range(0.7, 1.0)
			p["max_life"] = p["life"]

# ---------------------------------------------------------------------------
# Rankings
# ---------------------------------------------------------------------------

func _save_ranking() -> void:
	var entry: Dictionary = {
		"hero_class": GameManager.hero_class,
		"depth": GameManager.depth,
		"score": _final_score,
		"gold": GameManager.gold,
		"victory": true,
		"cause": "Victory!",
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

	# End the game in GameManager
	GameManager.end_game(true)
	# Delete saves from both systems
	if SaveManager:
		SaveManager.delete_save()
	GameManager.delete_save()

# ---------------------------------------------------------------------------
# UI Construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Congratulations
	var congrats: Label = Label.new()
	congrats.text = "You have escaped the dungeon!"
	congrats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	congrats.add_theme_font_size_override("font_size", 36)
	congrats.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	congrats.position = Vector2(290, 160)
	congrats.custom_minimum_size = Vector2(700, 50)
	add_child(congrats)

	# Hero class
	var class_name_str: String = HeroClassData.get_class_name_str(GameManager.hero_class)
	var hero_label: Label = Label.new()
	hero_label.text = "The %s ascends to the surface, victorious." % class_name_str
	hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_label.add_theme_font_size_override("font_size", 20)
	hero_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	hero_label.position = Vector2(290, 220)
	hero_label.custom_minimum_size = Vector2(700, 30)
	add_child(hero_label)

	# Score breakdown panel
	var score_panel: PanelContainer = PanelContainer.new()
	score_panel.position = Vector2(390, 280)
	score_panel.custom_minimum_size = Vector2(500, 240)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	score_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(score_panel)

	var score_vbox: VBoxContainer = VBoxContainer.new()
	score_vbox.add_theme_constant_override("separation", 10)
	score_panel.add_child(score_vbox)

	var score_title: Label = Label.new()
	score_title.text = "-- Score Breakdown --"
	score_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_title.add_theme_font_size_override("font_size", 20)
	score_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	score_vbox.add_child(score_title)

	_add_score_line(score_vbox, "Depth Bonus (%d x 100):" % GameManager.depth, _depth_bonus)
	_add_score_line(score_vbox, "Gold Bonus (%d / 10):" % GameManager.gold, _gold_bonus)
	_add_score_line(score_vbox, "Enemy Bonus (%d x 10):" % GameManager.stats.get("enemies_slain", 0), _enemy_bonus)
	_add_score_line(score_vbox, "Victory Bonus:", _victory_bonus)
	_add_score_line(score_vbox, "Exploration Score:", GameManager.score)

	# Separator
	var sep: HSeparator = HSeparator.new()
	score_vbox.add_child(sep)

	_add_score_line(score_vbox, "TOTAL SCORE:", _final_score, Color(1.0, 0.9, 0.3))

	# Continue button
	var continue_btn: Button = Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(200, 44)
	continue_btn.add_theme_font_size_override("font_size", 22)
	continue_btn.position = Vector2(540, 560)
	continue_btn.pressed.connect(_on_continue_pressed)
	add_child(continue_btn)

func _add_score_line(parent: VBoxContainer, label_text: String, value: int, color: Color = Color(0.8, 0.8, 0.85)) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	parent.add_child(hbox)

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(350, 24)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", color)
	hbox.add_child(lbl)

	var val_lbl: Label = Label.new()
	val_lbl.text = str(value)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.custom_minimum_size = Vector2(100, 24)
	val_lbl.add_theme_font_size_override("font_size", 16)
	val_lbl.add_theme_color_override("font_color", color)
	hbox.add_child(val_lbl)

# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_continue_pressed() -> void:
	var title_script: GDScript = preload("res://src/scenes/title_scene.gd")
	SceneManager.go_to(title_script, "TitleScene")
