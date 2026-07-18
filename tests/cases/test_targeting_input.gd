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
	var resolved_cells: Array[int] = []
	var _targeting_active: bool = true
	var _hud: FakeHud = FakeHud.new()
	var _targeting_item: Variant = null
	var _targeting_max_range: int = 0
	var _targeting_callback: Callable = Callable()
	var _awaiting_hero_input: bool = true
	var _hero_sprites: Dictionary = {}
	var _current_level: Variant = null

	func _cancel_targeting_mode() -> void:
		cancelled = true
		_targeting_active = false

	func _cancel_auto_walk() -> void:
		auto_walk_cancelled = true

	func _submit_hero_action(action: Dictionary) -> void:
		submitted_actions.append(action)

	func _movement_dir_for_key(_keycode: int) -> int:
		return 0

	func _get_input_hero() -> Variant:
		return FakeHero.new()

	func refresh_after_turn() -> void:
		pass

	func record_target(cell: int) -> void:
		resolved_cells.append(cell)

class FakeHero:
	extends RefCounted

	var actor_id: int = 1

	func distance_to(cell: int) -> int:
		return 0 if cell >= 0 else 999

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

	var invalid_target_scene := FakeScene.new()
	invalid_target_scene._targeting_callback = invalid_target_scene.record_target
	TargetingCoordinator.resolve(invalid_target_scene, -1)
	t.check(
		invalid_target_scene._targeting_active,
		"out-of-bounds targeting cell leaves targeting active"
	)
	t.check(
		invalid_target_scene.resolved_cells.is_empty(),
		"out-of-bounds targeting cell does not invoke the target callback"
	)

	var valid_target_scene := FakeScene.new()
	valid_target_scene._targeting_callback = valid_target_scene.record_target
	TargetingCoordinator.resolve(valid_target_scene, 0)
	t.check(
		not valid_target_scene._targeting_active,
		"valid targeting cell resolves targeting mode"
	)
	t.check(
		valid_target_scene.resolved_cells == [0],
		"valid targeting cell invokes the target callback"
	)
