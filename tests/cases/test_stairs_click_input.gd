extends RefCounted
## Clicking stairs should walk to them and then use them. This covers the input
## path that previously stopped after moving onto the down-stairs cell.

class FakeHero:
	extends RefCounted
	var pos: int = 0
	var hp: int = 10
	var is_alive: bool = true

class FakeLevel:
	extends RefCounted
	var entrance: int = 5
	var exit_pos: int = 12
	var passable: Array[bool] = []
	var mobs: Array[Node] = []
	var visible: Array[bool] = []

	func _init() -> void:
		passable.resize(ConstantsData.WIDTH * ConstantsData.HEIGHT)
		visible.resize(ConstantsData.WIDTH * ConstantsData.HEIGHT)
		for i: int in range(passable.size()):
			passable[i] = true
			visible[i] = false

	func find_char_at(_cell: int) -> Variant:
		return null

	func adjacent(a: int, b: int) -> bool:
		return abs(ConstantsData.pos_to_x(a) - ConstantsData.pos_to_x(b)) <= 1 \
			and abs(ConstantsData.pos_to_y(a) - ConstantsData.pos_to_y(b)) <= 1

	func terrain_at(cell: int) -> int:
		if cell == entrance:
			return ConstantsData.Terrain.ENTRANCE
		if cell == exit_pos:
			return ConstantsData.Terrain.EXIT
		return ConstantsData.Terrain.EMPTY

	func heaps_at(_cell: int) -> Array[Dictionary]:
		return []

class FakeScene:
	extends RefCounted
	var _targeting_active: bool = false
	var _current_level := FakeLevel.new()
	var hero := FakeHero.new()
	var _auto_walk_target: int = -1
	var _auto_walk_known_mobs: Dictionary[int, bool] = {}
	var _auto_walk_prev_hp: int = -1
	var _auto_walk_cooldown: float = 0.0
	var submitted_actions: Array[Dictionary] = []

	func _get_input_hero() -> Variant:
		return hero

	func _resolve_targeting(_cell: int) -> void:
		pass

	func _cancel_auto_walk() -> void:
		AutoWalkCoordinator.cancel(self)

	func _start_auto_walk(target: int) -> void:
		AutoWalkCoordinator.start(self, target)

	func _submit_hero_action(action: Dictionary) -> void:
		submitted_actions.append(action)

func run(t: Object) -> void:
	_test_adjacent_exit_click_keeps_stair_target(t)
	_test_auto_walk_reaching_exit_submits_descend(t)
	_test_auto_walk_reaching_entrance_submits_ascend(t)

func _test_adjacent_exit_click_keeps_stair_target(t: Object) -> void:
	var scene := FakeScene.new()
	scene.hero.pos = scene._current_level.exit_pos - 1

	InputCoordinator.handle_cell_click(scene, scene._current_level.exit_pos)

	t.check(
		scene._auto_walk_target == scene._current_level.exit_pos,
		"clicking adjacent stairs down keeps auto-walk target for follow-up descend"
	)
	t.check(
		scene.submitted_actions.size() == 1
			and scene.submitted_actions[0].get("type") == "move"
			and int(scene.submitted_actions[0].get("target_pos", -1)) == scene._current_level.exit_pos,
		"clicking adjacent stairs down first submits movement onto the stair"
	)

func _test_auto_walk_reaching_exit_submits_descend(t: Object) -> void:
	var scene := FakeScene.new()
	scene.hero.pos = scene._current_level.exit_pos
	scene._auto_walk_target = scene._current_level.exit_pos

	AutoWalkCoordinator.process_step(scene, 0.0)

	t.check(
		scene._auto_walk_target == -1,
		"auto-walk clears after reaching stairs down"
	)
	t.check(
		scene.submitted_actions.size() == 1 and scene.submitted_actions[0].get("type") == "descend",
		"auto-walk reaching stairs down submits descend"
	)

func _test_auto_walk_reaching_entrance_submits_ascend(t: Object) -> void:
	var scene := FakeScene.new()
	scene.hero.pos = scene._current_level.entrance
	scene._auto_walk_target = scene._current_level.entrance

	AutoWalkCoordinator.process_step(scene, 0.0)

	t.check(
		scene._auto_walk_target == -1,
		"auto-walk clears after reaching stairs up"
	)
	t.check(
		scene.submitted_actions.size() == 1 and scene.submitted_actions[0].get("type") == "ascend",
		"auto-walk reaching stairs up submits ascend"
	)
