class_name WndSettings
extends WndBase
## Settings window for adjusting music volume, SFX volume, zoom, and brightness.
## Reads current values from AudioManager and applies changes in real-time.

# --- Slider references ---
var _music_slider: HSlider = null
var _sfx_slider: HSlider = null
var _zoom_option: OptionButton = null
var _brightness_slider: HSlider = null
var _music_mute_btn: CheckButton = null
var _sfx_mute_btn: CheckButton = null

var _music_val_label: Label = null
var _sfx_val_label: Label = null
var _brightness_val_label: Label = null


func _init() -> void:
	window_title = "Settings"
	custom_minimum_size = Vector2(420, 380)


func _build_content() -> Control:
	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# --- Music Volume ---
	var music_section: Dictionary = _create_slider_section("Music Volume")
	_music_slider = music_section["slider"] as HSlider
	_music_val_label = music_section["value_label"] as Label
	_music_slider.min_value = 0
	_music_slider.max_value = 100
	_music_slider.step = 1
	_music_slider.value = _get_music_volume_percent()
	_music_val_label.text = "%d%%" % int(_music_slider.value)
	_music_slider.value_changed.connect(_on_music_changed)
	main.add_child(music_section["container"] as Control)

	# Music mute toggle
	_music_mute_btn = CheckButton.new()
	_music_mute_btn.text = "Mute Music"
	_music_mute_btn.button_pressed = _get_music_muted()
	_music_mute_btn.add_theme_font_size_override("font_size", 12)
	_music_mute_btn.add_theme_color_override("font_color", Color(0.82, 0.82, 0.85))
	_music_mute_btn.toggled.connect(_on_music_mute_toggled)
	main.add_child(_music_mute_btn)

	# --- SFX Volume ---
	var sfx_section: Dictionary = _create_slider_section("SFX Volume")
	_sfx_slider = sfx_section["slider"] as HSlider
	_sfx_val_label = sfx_section["value_label"] as Label
	_sfx_slider.min_value = 0
	_sfx_slider.max_value = 100
	_sfx_slider.step = 1
	_sfx_slider.value = _get_sfx_volume_percent()
	_sfx_val_label.text = "%d%%" % int(_sfx_slider.value)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	main.add_child(sfx_section["container"] as Control)

	# SFX mute toggle
	_sfx_mute_btn = CheckButton.new()
	_sfx_mute_btn.text = "Mute SFX"
	_sfx_mute_btn.button_pressed = _get_sfx_muted()
	_sfx_mute_btn.add_theme_font_size_override("font_size", 12)
	_sfx_mute_btn.add_theme_color_override("font_color", Color(0.82, 0.82, 0.85))
	_sfx_mute_btn.toggled.connect(_on_sfx_mute_toggled)
	main.add_child(_sfx_mute_btn)

	# --- Zoom Level ---
	var zoom_container: VBoxContainer = VBoxContainer.new()
	zoom_container.add_theme_constant_override("separation", 4)
	var zoom_label: Label = Label.new()
	zoom_label.text = "Zoom Level"
	zoom_label.add_theme_font_size_override("font_size", 12)
	zoom_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	zoom_container.add_child(zoom_label)

	_zoom_option = OptionButton.new()
	_zoom_option.add_item("1x", 0)
	_zoom_option.add_item("1.5x", 1)
	_zoom_option.add_item("2x", 2)
	_zoom_option.add_item("3x", 3)
	_zoom_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zoom_option.selected = _get_current_zoom_index()
	_zoom_option.item_selected.connect(_on_zoom_changed)
	zoom_container.add_child(_zoom_option)
	main.add_child(zoom_container)

	# --- Brightness ---
	var bright_section: Dictionary = _create_slider_section("Brightness")
	_brightness_slider = bright_section["slider"] as HSlider
	_brightness_val_label = bright_section["value_label"] as Label
	_brightness_slider.min_value = 0
	_brightness_slider.max_value = 100
	_brightness_slider.step = 1
	_brightness_slider.value = _get_brightness_percent()
	_brightness_val_label.text = "%d%%" % int(_brightness_slider.value)
	_brightness_slider.value_changed.connect(_on_brightness_changed)
	main.add_child(bright_section["container"] as Control)

	# --- Separator ---
	var sep: HSeparator = HSeparator.new()
	main.add_child(sep)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	main.add_child(action_row)

	var back_btn: Button = WndBase.create_spd_button("Back")
	back_btn.pressed.connect(close_window)
	action_row.add_child(back_btn)

	var save_btn: Button = WndBase.create_spd_button("Save")
	save_btn.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	save_btn.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.7))
	save_btn.pressed.connect(_on_save_close)
	action_row.add_child(save_btn)

	var game_scene: Node = get_tree().root.get_node_or_null("GameScene")
	if game_scene != null:
		var exit_btn: Button = WndBase.create_spd_button("Exit to Menu")
		exit_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
		exit_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.45, 0.45))
		exit_btn.pressed.connect(_on_exit_to_menu)
		action_row.add_child(exit_btn)

	return main


func _create_slider_section(title: String) -> Dictionary:
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

	return { "container": container, "slider": slider, "value_label": value_label }


# --- Callbacks ---

func _on_music_changed(value: float) -> void:
	_music_val_label.text = "%d%%" % int(value)
	var audio: Node = AudioManager
	if audio and audio.has_method("set_music_volume"):
		audio.set_music_volume(value / 100.0)


func _on_sfx_changed(value: float) -> void:
	_sfx_val_label.text = "%d%%" % int(value)
	var audio: Node = AudioManager
	if audio and audio.has_method("set_sfx_volume"):
		audio.set_sfx_volume(value / 100.0)


func _on_music_mute_toggled(pressed: bool) -> void:
	var audio: Node = AudioManager
	if audio and audio.has_method("set_music_muted"):
		audio.set_music_muted(pressed)


func _on_sfx_mute_toggled(pressed: bool) -> void:
	var audio: Node = AudioManager
	if audio and audio.has_method("set_sfx_muted"):
		audio.set_sfx_muted(pressed)


func _on_zoom_changed(index: int) -> void:
	var zoom_values: Array[float] = [1.0, 1.5, 2.0, 3.0]
	if index >= 0 and index < zoom_values.size():
		var zoom_val: float = zoom_values[index]
		var game_manager: Node = GameManager
		if game_manager:
			game_manager.set("zoom_level", zoom_val)
		# Also try to apply directly to the camera
		var game_scene: Node = get_tree().root.get_node_or_null("GameScene")
		if game_scene:
			var camera: Camera2D = game_scene.get_node_or_null("GameCamera") as Camera2D
			if camera == null:
				# Try finding it recursively
				for child: Node in game_scene.get_children():
					if child is Camera2D:
						camera = child as Camera2D
						break
			if camera:
				camera.zoom = Vector2(zoom_val, zoom_val)


func _on_brightness_changed(value: float) -> void:
	_brightness_val_label.text = "%d%%" % int(value)
	# Map 0-100 to a brightness modulation (0.5 = dim, 1.0 = normal, 1.5 = bright)
	var brightness: float = 0.5 + (value / 100.0)
	var env: WorldEnvironment = _find_world_environment()
	if env and env.environment:
		env.environment.adjustment_brightness = brightness
	else:
		# Fallback: modulate the game scene root
		var game_scene: Node = get_tree().root.get_node_or_null("GameScene")
		if game_scene and game_scene is CanvasItem:
			(game_scene as CanvasItem).modulate = Color(brightness, brightness, brightness)


func _on_save_close() -> void:
	# Persist settings via GameManager if available
	var game_manager: Node = GameManager
	if game_manager:
		game_manager.set("setting_music_volume", _music_slider.value / 100.0)
		game_manager.set("setting_sfx_volume", _sfx_slider.value / 100.0)
		game_manager.set("setting_brightness", _brightness_slider.value / 100.0)
		game_manager.set("setting_music_muted", _music_mute_btn.button_pressed if _music_mute_btn else false)
		game_manager.set("setting_sfx_muted", _sfx_mute_btn.button_pressed if _sfx_mute_btn else false)
		if game_manager.has_method("save_settings"):
			game_manager.save_settings()
	# Also persist via SaveManager if available
	if SaveManager:
		SaveManager.save_audio_settings()
	close_window()


func _on_exit_to_menu() -> void:
	close_window()
	var title_script: GDScript = load("res://src/scenes/title_scene.gd") as GDScript
	if title_script == null:
		return
	SceneManager.go_to(title_script, "TitleScene")


# --- Helpers ---

func _get_music_volume_percent() -> float:
	var audio: Node = AudioManager
	if audio:
		var vol: Variant = audio.get("music_volume")
		if vol is float:
			return vol * 100.0
	return 50.0


func _get_sfx_volume_percent() -> float:
	var audio: Node = AudioManager
	if audio:
		var vol: Variant = audio.get("sfx_volume")
		if vol is float:
			return vol * 100.0
	return 50.0


func _get_music_muted() -> bool:
	var audio: Node = AudioManager
	if audio:
		var m: Variant = audio.get("music_muted")
		if m is bool:
			return m
	return false


func _get_sfx_muted() -> bool:
	var audio: Node = AudioManager
	if audio:
		var m: Variant = audio.get("sfx_muted")
		if m is bool:
			return m
	return false


func _get_current_zoom_index() -> int:
	var game_manager: Node = GameManager
	if game_manager:
		var zoom: Variant = game_manager.get("zoom_level")
		if zoom is float:
			var zoom_values: Array[float] = [1.0, 1.5, 2.0, 3.0]
			for i: int in range(zoom_values.size()):
				if absf(zoom_values[i] - zoom) < 0.01:
					return i
	return 0


func _get_brightness_percent() -> float:
	var game_manager: Node = GameManager
	if game_manager:
		var b: Variant = game_manager.get("setting_brightness")
		if b is float:
			return b * 100.0
	return 50.0



func _find_world_environment() -> WorldEnvironment:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	for child: Node in tree.root.get_children():
		if child is WorldEnvironment:
			return child as WorldEnvironment
	return null
