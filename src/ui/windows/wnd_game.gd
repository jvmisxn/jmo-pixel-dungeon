class_name WndGame
extends WndBase
## Game menu window with resume, settings, save & quit, and quit without saving.

func _init() -> void:
	window_title = "Game Menu"
	custom_minimum_size = Vector2(300, 320)


func _build_content() -> Control:
	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# --- Run Info ---
	var info_container: VBoxContainer = VBoxContainer.new()
	info_container.add_theme_constant_override("separation", 4)
	main.add_child(info_container)

	var depth: int = GameManager.depth if GameManager else 0
	var region: int = ConstantsData.region_for_depth(depth)
	var region_str: String = ConstantsData.region_name(region)

	var depth_label: Label = Label.new()
	depth_label.text = "Depth: %d  (%s)" % [depth, region_str]
	depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_container.add_child(depth_label)

	if GameManager and GameManager.get("hero"):
		var hero: Hero = GameManager.hero
		var class_str: String = HeroClassData.get_class_name_str(hero.hero_class)
		var hero_label: Label = Label.new()
		hero_label.text = "%s  Lv.%d  HP: %d/%d" % [class_str, hero.hero_level, hero.hp, hero.hp_max]
		hero_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hero_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		info_container.add_child(hero_label)

	var gold: int = GameManager.gold if GameManager else 0
	var gold_label: Label = Label.new()
	gold_label.text = "Gold: %d" % gold
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	info_container.add_child(gold_label)

	# --- Separator ---
	var sep: HSeparator = HSeparator.new()
	main.add_child(sep)

	# --- Buttons ---
	var btn_container: VBoxContainer = VBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 8)
	btn_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(btn_container)

	var resume_btn: Button = WndBase.create_spd_button("Resume")
	resume_btn.pressed.connect(_on_resume)
	btn_container.add_child(resume_btn)

	# Map: reachable full-dungeon-map entry from the game menu, matching SPD's
	# in-menu map access and giving a fallback where the minimap is hidden.
	var map_btn: Button = WndBase.create_spd_button("Map")
	map_btn.pressed.connect(_on_map)
	btn_container.add_child(map_btn)

	var settings_btn: Button = WndBase.create_spd_button("Settings")
	settings_btn.pressed.connect(_on_settings)
	btn_container.add_child(settings_btn)

	var save_quit_btn: Button = WndBase.create_spd_button("Save & Quit")
	save_quit_btn.pressed.connect(_on_save_quit)
	btn_container.add_child(save_quit_btn)

	var quit_btn: Button = WndBase.create_spd_button("Quit Without Saving")
	quit_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	quit_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.3, 0.3))
	quit_btn.pressed.connect(_on_quit_no_save)
	btn_container.add_child(quit_btn)

	return main


func _on_resume() -> void:
	close_window()


func _on_map() -> void:
	# Layer the map over the game menu (same pattern as inventory -> item view)
	# so closing the map returns here instead of stranding the window stack.
	open_sub_window.emit(WndMap.new())


func _on_settings() -> void:
	# Layer settings over the game menu via the sub-window signal (avoids walking
	# up the tree with get_parent()); closing settings returns to this menu.
	var wnd: WndSettings = WndSettings.new()
	open_sub_window.emit(wnd)


func _on_save_quit() -> void:
	if SaveManager:
		SaveManager.save_full_game()
	_return_to_title()


func _on_quit_no_save() -> void:
	_return_to_title()


func _return_to_title() -> void:
	close_window()
	var title_script: GDScript = load("res://src/scenes/title_scene.gd") as GDScript
	if title_script:
		SceneManager.go_to(title_script, "TitleScene")
