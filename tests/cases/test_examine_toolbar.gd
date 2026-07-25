extends RefCounted
## Toolbar examine entry parity with upstream Toolbar btnSearch: the first
## press enters examine cell-select mode, a second press cancels it and
## performs an active search, and a press while targeting only cancels
## targeting. The X key routes through the same state machine.

class FakeScene:
	extends RefCounted
	var _targeting_active: bool = false
	var _current_level: Variant = null
	var _awaiting_hero_input: bool = true
	var _auto_walk_target: int = -1
	var _auto_walk_known_mobs: Dictionary[int, bool] = {}
	var _auto_walk_prev_hp: int = -1
	var _auto_walk_cooldown: float = 0.0
	var submitted_actions: Array[Dictionary] = []
	var targeting_cancelled: bool = false

	func _get_input_hero() -> Variant:
		return null

	func _cancel_targeting_mode() -> void:
		_targeting_active = false
		targeting_cancelled = true

	func _cancel_auto_walk() -> void:
		AutoWalkCoordinator.cancel(self)

	func _submit_hero_action(action: Dictionary) -> void:
		submitted_actions.append(action)

func run(t: Object) -> void:
	var old_examine: bool = InputCoordinator.examine_mode
	InputCoordinator.examine_mode = false
	_test_first_press_enters_examine_mode(t)
	_test_second_press_searches(t)
	_test_press_while_targeting_only_cancels_targeting(t)
	_test_x_key_routes_through_same_state_machine(t)
	InputCoordinator.examine_mode = old_examine

func _test_first_press_enters_examine_mode(t: Object) -> void:
	var scene := FakeScene.new()
	InputCoordinator.examine_mode = false

	InputCoordinator.handle_toolbar_examine(scene)

	t.check(InputCoordinator.examine_mode, "first examine press enters examine mode")
	t.check(scene.submitted_actions.is_empty(), "entering examine mode submits no hero action")

func _test_second_press_searches(t: Object) -> void:
	var scene := FakeScene.new()
	InputCoordinator.examine_mode = true

	InputCoordinator.handle_toolbar_examine(scene)

	t.check(not InputCoordinator.examine_mode, "second examine press leaves examine mode")
	t.check(
		scene.submitted_actions.size() == 1
			and str(scene.submitted_actions[0].get("type")) == "search",
		"second examine press performs an active search (upstream btnSearch onClick)"
	)

func _test_press_while_targeting_only_cancels_targeting(t: Object) -> void:
	var scene := FakeScene.new()
	scene._targeting_active = true
	InputCoordinator.examine_mode = false

	InputCoordinator.handle_toolbar_examine(scene)

	t.check(scene.targeting_cancelled, "examine press while targeting cancels targeting")
	t.check(not InputCoordinator.examine_mode, "examine press while targeting does not enter examine mode")
	t.check(scene.submitted_actions.is_empty(), "examine press while targeting submits no action")

func _test_x_key_routes_through_same_state_machine(t: Object) -> void:
	var scene := FakeScene.new()
	InputCoordinator.examine_mode = false

	InputCoordinator.handle_key_input(scene, KEY_X)
	t.check(InputCoordinator.examine_mode, "X key enters examine mode")

	InputCoordinator.handle_key_input(scene, KEY_X)
	t.check(not InputCoordinator.examine_mode, "second X press leaves examine mode")
	t.check(
		scene.submitted_actions.size() == 1
			and str(scene.submitted_actions[0].get("type")) == "search",
		"second X press performs an active search like the toolbar button"
	)
