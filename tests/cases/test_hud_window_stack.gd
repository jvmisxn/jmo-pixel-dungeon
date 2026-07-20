extends RefCounted
## Regression coverage for modal window bookkeeping. Item detail windows are
## opened as HUD sub-windows from inventory; if their overlays or tracking
## survive close, gameplay input can remain blocked after an equip action.

class FakeWindow:
	extends Control
	signal window_closed
	signal open_sub_window(wnd: Variant)
	var _background_overlay: Control = null

class FakeOverlayWindow:
	extends Control
	var _background_overlay: Control = null

class TouchableWindow:
	extends WndBase
	func _play_close_animation() -> void:
		pass

func run(t: Object) -> void:
	_test_sub_window_close_releases_tracking(t)
	_test_hud_close_frees_sibling_overlay(t)
	_test_active_close_frees_open_sub_overlay(t)
	_test_title_bar_close_handles_screen_touch(t)

func _make_hud() -> HUD:
	var hud := HUD.new()
	var layer := Control.new()
	layer.name = "WindowLayer"
	layer.visible = false
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.window_layer = layer
	hud.add_child(layer)
	return hud

func _test_sub_window_close_releases_tracking(t: Object) -> void:
	var hud := _make_hud()
	var active := FakeWindow.new()
	var sub := FakeWindow.new()

	hud.show_window(active)
	active.open_sub_window.emit(sub)

	t.check(
		hud._sub_windows.has(sub),
		"HUD tracks inventory item detail sub-windows"
	)
	t.check(
		hud.window_layer.visible and hud.window_layer.mouse_filter == Control.MOUSE_FILTER_STOP,
		"HUD modal layer blocks world input while an inventory window is open"
	)

	sub.window_closed.emit()
	t.check(
		not hud._sub_windows.has(sub),
		"closed item detail sub-window is removed from HUD tracking"
	)
	t.check(
		hud.window_layer.visible,
		"closing an item detail keeps the parent inventory modal active"
	)

	active.window_closed.emit()
	t.check(
		not hud.window_layer.visible and hud.window_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"closing the parent inventory releases HUD modal input blocking"
	)

	hud.free()

func _test_title_bar_close_handles_screen_touch(t: Object) -> void:
	var wnd := TouchableWindow.new()
	var closed: Array[bool] = []
	wnd.window_closed.connect(func() -> void:
		closed.append(true)
	)
	wnd._setup_window()
	wnd._close_button.size = Vector2(28, 28)

	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.pressed = true
	touch_down.position = Vector2(14, 14)
	wnd._on_close_button_gui_input(touch_down)

	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 0
	touch_up.pressed = false
	touch_up.position = Vector2(14, 14)
	wnd._on_close_button_gui_input(touch_up)

	t.check(
		closed.size() == 1,
		"title-bar X closes from the first mobile touch release"
	)
	t.check(
		wnd._is_closing,
		"title-bar X does not wait for a second synthesized click to begin closing"
	)

	wnd.free()

func _test_hud_close_frees_sibling_overlay(t: Object) -> void:
	var hud := _make_hud()
	var wnd := FakeOverlayWindow.new()
	var overlay := Control.new()
	wnd._background_overlay = overlay

	hud.window_layer.add_child(overlay)
	hud.window_layer.add_child(wnd)
	hud._active_window = wnd
	hud.window_layer.visible = true
	hud.window_layer.mouse_filter = Control.MOUSE_FILTER_STOP

	hud.close_window()

	t.check(
		wnd.is_queued_for_deletion(),
		"HUD close queues the active window for deletion"
	)
	t.check(
		overlay.is_queued_for_deletion(),
		"HUD close also queues the window's sibling overlay for deletion"
	)
	t.check(
		not hud.window_layer.visible and hud.window_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"HUD close releases modal input blocking after forced close"
	)

	hud.free()

## Real-world "stuck after equip" trigger: the item detail sub-window can still be
## open (with its own sibling overlay) when the parent inventory is dismissed via
## the X/Escape self-close path. That path must free the sub-window's overlay too,
## otherwise a MOUSE_FILTER_STOP ColorRect is orphaned in the layer and blocks input.
func _test_active_close_frees_open_sub_overlay(t: Object) -> void:
	var hud := _make_hud()
	var active := FakeWindow.new()
	var sub := FakeWindow.new()
	var sub_overlay := Control.new()
	sub._background_overlay = sub_overlay

	hud.show_window(active)
	active.open_sub_window.emit(sub)
	hud.window_layer.add_child(sub_overlay)

	t.check(
		hud._sub_windows.has(sub),
		"open item detail sub-window is tracked before the inventory closes"
	)

	# Parent inventory dismissed (X button / Escape) while the item window is open.
	active.window_closed.emit()

	t.check(
		sub.is_queued_for_deletion(),
		"dismissing the inventory force-closes the open item detail sub-window"
	)
	t.check(
		sub_overlay.is_queued_for_deletion(),
		"the open sub-window's sibling overlay is freed, not orphaned in the layer"
	)
	t.check(
		not hud.window_layer.visible and hud.window_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"no orphaned overlay keeps modal input blocked after the inventory closes"
	)

	hud.free()
