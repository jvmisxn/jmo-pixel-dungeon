extends RefCounted
## Look-and-feel wiring: every Control falls back to the SPD pixel font, window
## chrome comes from scaled SPD nine-patches, every button clicks, scene
## swaps fade in from black, and brightness is a real persisted setting.

func run(t: Object) -> void:
	_test_global_theme(t)
	_test_scaled_chrome(t)
	_test_spd_button_style(t)
	_test_button_click_hook(t)
	_test_scene_fade_cover(t)
	_test_brightness_setting(t)


func _test_global_theme(t: Object) -> void:
	t.check(str(ProjectSettings.get_setting("gui/theme/custom", "")) == "",
		"no project theme (it would load before a fresh import has the font)")
	UIUtils.apply_global_font()
	var font: Font = ThemeDB.fallback_font
	t.check(font != null and font.resource_path == UIUtils.PIXEL_FONT_PATH,
		"every Control falls back to the SPD pixel font")
	t.check(ThemeDB.fallback_font_size == UIUtils.DEFAULT_FONT_SIZE,
		"fallback font size is the UI default")
	var default_theme: Theme = ThemeDB.get_default_theme()
	t.check(default_theme != null and default_theme.default_font == font,
		"engine default theme uses the SPD pixel font too")
	var label := Label.new()
	t.check(label.get_theme_default_font() == font, "a plain Label resolves the SPD pixel font")
	label.free()


func _test_scaled_chrome(t: Object) -> void:
	var source: Texture2D = load(UIUtils.CHROME_PATH) as Texture2D
	var scaled: Texture2D = UIUtils.scaled_texture(UIUtils.CHROME_PATH, UIUtils.CHROME_SCALE)
	t.check(source != null and scaled != null, "chrome texture and its scaled copy load")
	if source == null or scaled == null:
		return
	t.check(scaled.get_size() == source.get_size() * UIUtils.CHROME_SCALE,
		"scaled chrome is a whole-pixel multiple of the source")
	t.check(UIUtils.scaled_texture(UIUtils.CHROME_PATH, UIUtils.CHROME_SCALE) == scaled,
		"scaled chrome texture is cached")

	var style: StyleBoxTexture = UIUtils.scaled_chrome_stylebox(
		UIUtils.CHROME_WINDOW, UIUtils.CHROME_WINDOW_MARGIN)
	var s: float = float(UIUtils.CHROME_SCALE)
	t.check(style.region_rect == Rect2(UIUtils.CHROME_WINDOW.position * s, UIUtils.CHROME_WINDOW.size * s),
		"window stylebox region is scaled with the texture")
	t.check(is_equal_approx(style.texture_margin_left, UIUtils.CHROME_WINDOW_MARGIN * s),
		"window stylebox slice margin is scaled")

	var icon: AtlasTexture = UIUtils.scaled_icon(UIUtils.ICON_CLOSE)
	t.check(icon != null and icon.get_size() == UIUtils.ICON_CLOSE.size * s,
		"close icon is drawn at the chrome scale")


func _test_spd_button_style(t: Object) -> void:
	var btn: Button = WndBase.create_spd_button("OK")
	t.check(btn.get_theme_stylebox("normal") is StyleBoxTexture,
		"SPD buttons use the chrome nine-patch, not a flat box")
	btn.free()


func _test_button_click_hook(t: Object) -> void:
	# The runner executes before autoloads (and the root) enter the tree, so
	# node_added cannot fire here. Check the two halves directly: the tree
	# signal is connected, and the handler wires a button's press to a click.
	AudioManager._hook_button_clicks()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	t.check(tree.node_added.is_connected(AudioManager._on_node_added_for_click),
		"AudioManager listens for buttons entering the tree")
	var btn := Button.new()
	AudioManager._on_node_added_for_click(btn)
	var hooked: bool = false
	for connection: Dictionary in btn.button_down.get_connections():
		var callable: Callable = connection["callable"]
		if callable.get_object() == AudioManager:
			hooked = true
	t.check(hooked, "a new button's press is wired to the click sound")
	AudioManager._on_node_added_for_click(btn)
	t.check(btn.button_down.get_connections().size() == 1,
		"re-adding a button does not double the click hook")
	btn.free()


func _test_scene_fade_cover(t: Object) -> void:
	SceneManager._play_fade_in()
	var rect: ColorRect = SceneManager._fade_rect
	t.check(rect != null and is_instance_valid(rect), "scene fade cover is created")
	if rect == null:
		return
	t.check(is_equal_approx(rect.modulate.a, 1.0), "fade starts fully black after a swap")
	t.check(rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "fade cover never blocks input")
	t.check(SceneManager._fade_layer.layer >= 100, "fade cover draws above game layers")


func _test_brightness_setting(t: Object) -> void:
	var previous: float = GameManager.setting_brightness
	GameManager.setting_brightness = 0.5
	t.check(is_equal_approx(GameManager.brightness_factor(), 1.0), "50% brightness is neutral")
	GameManager.setting_brightness = 1.0
	t.check(is_equal_approx(GameManager.brightness_factor(), 1.5), "100% brightness brightens")
	var node := Node2D.new()
	GameManager.apply_brightness(node)
	t.check(is_equal_approx(node.modulate.r, 1.5), "brightness is applied as a modulate")
	node.free()
	GameManager.setting_brightness = previous
