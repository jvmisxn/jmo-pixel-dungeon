extends RefCounted
## Regression coverage for in-game menu reachability.
##
## The toolbar "Menu" button (and the Esc key) must open the real in-game
## WndGame menu — the only touch-reachable path to Settings, the full Map, and
## Save & Quit — instead of jumping straight to the audio-only WndSettings, which
## left WndGame (and its Save & Quit / Quit actions) orphaned and unreachable on
## mobile where the minimap and M/Esc keys are unavailable.

class SubWindowSpy:
	extends RefCounted
	var captured: Array = []
	func on_open(wnd: Variant) -> void:
		captured.append(wnd)


func _make_hud() -> HUD:
	var hud := HUD.new()
	var layer := Control.new()
	layer.name = "WindowLayer"
	layer.visible = false
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.window_layer = layer
	hud.add_child(layer)
	return hud


func run(t: Object) -> void:
	# --- Toolbar "Menu"/Esc routes to the game menu, not audio settings ---
	var hud := _make_hud()
	hud._on_settings_pressed()
	t.check(
		hud._active_window != null
				and hud._active_window.get_script() != null
				and str(hud._active_window.get_script().resource_path).ends_with("wnd_game.gd"),
		"toolbar Menu button opens the in-game game menu (not the audio settings window)"
	)

	# --- open_settings() toggles the game menu closed when it is already open ---
	hud.open_settings()
	t.check(
		hud._active_window == null,
		"Esc/open_settings toggles the open game menu closed"
	)
	hud.free()

	# --- Game menu exposes a Map entry that layers the full map over the menu ---
	var wg := WndGame.new()
	var map_spy := SubWindowSpy.new()
	wg.open_sub_window.connect(map_spy.on_open)
	wg._on_map()
	t.check(
		map_spy.captured.size() == 1 and map_spy.captured[0] is WndMap,
		"game menu Map button opens the full map as a sub-window"
	)
	for wnd: Variant in map_spy.captured:
		if wnd is Node:
			(wnd as Node).free()
	wg.free()

	# --- Game menu Settings entry layers audio settings over the menu ---
	var wg_settings := WndGame.new()
	var settings_spy := SubWindowSpy.new()
	wg_settings.open_sub_window.connect(settings_spy.on_open)
	wg_settings._on_settings()
	t.check(
		settings_spy.captured.size() == 1 and settings_spy.captured[0] is WndSettings,
		"game menu Settings button opens audio settings as a sub-window"
	)
	for wnd: Variant in settings_spy.captured:
		if wnd is Node:
			(wnd as Node).free()
	wg_settings.free()
