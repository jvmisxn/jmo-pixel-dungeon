class_name MainScene
extends Node2D
## Entry point scene. Launches the title screen (Phase 5 UI).
## Can also be used to directly start a game for testing via _start_new_game().

var _game_scene: Variant = null

func _ready() -> void:
	# Launch the title screen via SceneManager
	var title_script: GDScript = preload("res://src/scenes/title_scene.gd")
	SceneManager.go_to(title_script, "TitleScene")

func _start_new_game() -> void:
	var loading_script: GDScript = load("res://src/scenes/loading_scene.gd") as GDScript
	if loading_script == null:
		return
	SceneManager.go_to(loading_script, "LoadingScene", {
		"chosen_class": ConstantsData.HeroClass.WARRIOR,
		"is_continue": false,
	})
