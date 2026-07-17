extends RefCounted

class FakeHud:
	extends RefCounted

	var inventory_toggled: bool = false

	func toggle_inventory() -> void:
		inventory_toggled = true

class FakeScene:
	extends RefCounted

	var cancelled: bool = false
	var auto_walk_cancelled: bool = false
	var submitted_actions: Array[Dictionary] = []
	var _targeting_active: bool = true
	var _hud: FakeHud = FakeHud.new()

	func _cancel_targeting_mode() -> void:
		cancelled = true
		_targeting_active = false

	func _cancel_auto_walk() -> void:
		auto_walk_cancelled = true

	func _submit_hero_action(action: Dictionary) -> void:
		submitted_actions.append(action)

	func _movement_dir_for_key(_keycode: int) -> int:
		return 0

func run(t: Object) -> void:
	var targeting_scene := FakeScene.new()
	t.check(
		InputCoordinator.handle_key_input(targeting_scene, KEY_SPACE),
		"targeting mode consumes non-Escape keyboard input"
	)
	t.check(
		targeting_scene._targeting_active,
		"non-Escape keyboard input leaves targeting active"
	)
	t.check(
		not targeting_scene.auto_walk_cancelled and targeting_scene.submitted_actions.is_empty(),
		"non-Escape targeting input does not leak hero actions"
	)

	var hud_scene := FakeScene.new()
	t.check(
		InputCoordinator.handle_key_input(hud_scene, KEY_I),
		"targeting mode consumes inventory shortcut"
	)
	t.check(
		not hud_scene._hud.inventory_toggled,
		"inventory shortcut does not open HUD while targeting"
	)

	var cancel_scene := FakeScene.new()
	t.check(
		InputCoordinator.handle_key_input(cancel_scene, KEY_ESCAPE),
		"Escape cancels targeting mode"
	)
	t.check(
		cancel_scene.cancelled and not cancel_scene._targeting_active,
		"Escape clears targeting state"
	)
