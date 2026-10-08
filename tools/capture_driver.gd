extends Node
## Dev tool: boots the real game and saves screenshots of key screens, for
## reviewing UI/visual changes without a display. Needs a rendering driver,
## so run it under a virtual display, e.g.:
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-driver opengl3 --resolution 1280x720 \
##     -s res://tools/capture_screenshots.gd -- --out=/tmp/shots
##
## Output: title.png, game.png, inventory.png, menu.png, settings.png.
## Loaded at runtime by capture_screenshots.gd so autoloads resolve.

const WAIT_FRAMES: int = 45

var _out_dir: String = "user://screenshots"
var _frame: int = 0
var _step: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	if PlayerProfile and not PlayerProfile.has_player_name():
		PlayerProfile.set_player_name("Tester")
	seed(12345)
	SceneManager.go_to(load("res://src/scenes/title_scene.gd") as GDScript, "TitleScene")


func _process(_delta: float) -> void:
	_frame += 1
	if _frame < WAIT_FRAMES:
		return
	_frame = 0
	match _step:
		0:
			_shot("title")
			SceneManager.go_to(load("res://src/scenes/loading_scene.gd") as GDScript, "LoadingScene", {
				"chosen_class": ConstantsData.HeroClass.WARRIOR,
				"is_continue": false,
			})
		1:
			# Loading scene hands off to the game scene; give it extra time.
			if not _in_game():
				return
			_shot("game")
			_call_hud("_on_inventory_pressed")
		2:
			_shot("inventory")
			_call_hud("close_window")
			_call_hud("_on_settings_pressed")
		3:
			_shot("menu")
			_open_settings_window()
		4:
			_shot("settings")
			print("capture_screenshots: done -> ", ProjectSettings.globalize_path(_out_dir))
			get_tree().quit()
	_step += 1


func _in_game() -> bool:
	var scene: Node = SceneManager.current_scene
	return scene != null and scene.get("_hud") != null


func _call_hud(method: String) -> void:
	var scene: Node = SceneManager.current_scene
	var hud: Variant = scene.get("_hud") if scene != null else null
	if hud != null and hud.has_method(method):
		hud.call(method)


func _open_settings_window() -> void:
	var scene: Node = SceneManager.current_scene
	var hud: Variant = scene.get("_hud") if scene != null else null
	if hud == null:
		return
	hud.call("close_window")
	hud.call("show_window", WndSettings.new())


func _shot(name: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = _out_dir.path_join(name + ".png")
	image.save_png(path)
	print("capture_screenshots: saved ", path)
