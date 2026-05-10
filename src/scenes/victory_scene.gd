class_name VictoryScene
extends Control
## Victory screen shown when the player obtains the Amulet of Yendor.
## Plays theme music, displays animated amulet glow, score, and saves ranking.

var _time_elapsed: float = 0.0
var _title_label: Label = null
var _subtitle_label: Label = null
var _score_label: Label = null
var _continue_btn: Button = null
var _final_score: int = 0

const RANKINGS_PATH: String = "user://rankings.dat"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_final_score = GameManager.compute_final_score() if GameManager else 0

	# End game and save
	if GameManager:
		GameManager.end_game(true)
	if SaveManager:
		SaveManager.delete_save()
	elif GameManager:
		GameManager.delete_save()

	# --- Center container for responsive layout ---
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	# Title
	_title_label = Label.new()
	_title_label.text = "Victory!"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(_title_label)

	# Subtitle
	_subtitle_label = Label.new()
	_subtitle_label.text = "You obtained the Amulet of Yendor!"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 22)
	_subtitle_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	vbox.add_child(_subtitle_label)

	# Score
	_score_label = Label.new()
	_score_label.text = "Final Score: %d" % _final_score
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 18)
	_score_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	vbox.add_child(_score_label)

	# Continue button
	_continue_btn = Button.new()
	_continue_btn.text = "Return to Title"
	_continue_btn.custom_minimum_size = Vector2(200, 50)
	_continue_btn.pressed.connect(_on_continue)
	vbox.add_child(_continue_btn)

	# Save ranking
	_save_ranking()

func _process(delta: float) -> void:
	_time_elapsed += delta
	# Pulse the title label color
	if _title_label:
		var pulse: float = 0.5 + 0.5 * sin(_time_elapsed * 2.0)
		_title_label.add_theme_color_override("font_color", Color(1.0, 0.9 + 0.1 * pulse, 0.3 + 0.2 * pulse))

func _on_continue() -> void:
	var title_script: GDScript = preload("res://src/scenes/title_scene.gd")
	SceneManager.go_to(title_script, "TitleScene")

func _save_ranking() -> void:
	var ranking: Dictionary = {
		"player_name": PlayerProfile.get_player_name() if PlayerProfile else "Player",
		"victory": true,
		"score": _final_score,
		"depth": GameManager.depth if GameManager else 0,
		"hero_class": GameManager.hero_class if GameManager else 0,
		"timestamp": Time.get_unix_time_from_system(),
	}
	var rankings: Array = []
	if FileAccess.file_exists(RANKINGS_PATH):
		var file: FileAccess = FileAccess.open(RANKINGS_PATH, FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Array:
				rankings = parsed
			file.close()
	rankings.append(ranking)
	var file: FileAccess = FileAccess.open(RANKINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(rankings))
		file.close()
