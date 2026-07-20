extends RefCounted

class FakeSpinnerLevel:
	extends RefCounted

	var heroes: Array[Char] = []
	var los_enabled: bool = true
	var last_find_step_target: int = -1
	var find_step_result: int = -1

	func get_heroes() -> Array[Char]:
		return heroes

	func has_los(_from_pos: int, _to_pos: int) -> bool:
		return los_enabled

	func find_step(_from_pos: int, target_pos: int) -> int:
		last_find_step_target = target_pos
		return find_step_result

	func is_passable(_cell: int) -> bool:
		return true

	func find_char_at(_cell: int) -> Variant:
		return null

	func terrain_at(_cell: int) -> int:
		return ConstantsData.Terrain.EMPTY

func run(t: Object) -> void:
	_test_spinner_amok_uses_base_hunting_retarget(t)
	_test_spinner_loses_unseen_target_at_last_known_cell(t)
	_test_spinner_moves_toward_last_known_target_cell(t)
	_test_spinner_visible_adjacent_attack_still_works(t)

func _test_spinner_amok_uses_base_hunting_retarget(t: Object) -> void:
	var level := FakeSpinnerLevel.new()
	var spinner := Spinner.new()
	var far_hero := Char.new()
	var near_hero := Char.new()
	spinner.pos = ConstantsData.xy_to_pos(10, 10)
	far_hero.pos = ConstantsData.xy_to_pos(16, 10)
	near_hero.pos = ConstantsData.xy_to_pos(11, 10)
	level.heroes = [far_hero, near_hero]
	spinner.level = level
	far_hero.level = level
	near_hero.level = level
	spinner.state = Mob.AIState.HUNTING
	spinner.target = far_hero
	spinner.target_pos = far_hero.pos
	spinner.web_cooldown = 99
	spinner.add_buff(Amok.new())

	spinner._act_hunting()

	t.check(
		spinner.target == near_hero,
		"Spinner hunting honors Amok by retargeting to the nearest visible character"
	)

	spinner.free()
	far_hero.free()
	near_hero.free()

func _test_spinner_loses_unseen_target_at_last_known_cell(t: Object) -> void:
	var level := FakeSpinnerLevel.new()
	level.los_enabled = false
	var spinner := Spinner.new()
	var hero := Char.new()
	spinner.pos = ConstantsData.xy_to_pos(10, 10)
	hero.pos = ConstantsData.xy_to_pos(14, 10)
	spinner.level = level
	hero.level = level
	spinner.state = Mob.AIState.HUNTING
	spinner.target = hero
	spinner.target_pos = spinner.pos
	spinner.web_cooldown = 99

	spinner._act_hunting()

	t.check(spinner.state == Mob.AIState.WANDERING, "Spinner gives up after reaching the last known target cell")
	t.check(spinner.target == null, "Spinner clears the lost unseen target")
	t.check(spinner.target_pos == -1, "Spinner clears last-known target position after losing the target")

	spinner.free()
	hero.free()

func _test_spinner_moves_toward_last_known_target_cell(t: Object) -> void:
	var level := FakeSpinnerLevel.new()
	level.los_enabled = false
	var spinner := Spinner.new()
	var hero := Char.new()
	spinner.pos = ConstantsData.xy_to_pos(10, 10)
	hero.pos = ConstantsData.xy_to_pos(18, 10)
	spinner.level = level
	hero.level = level
	spinner.state = Mob.AIState.HUNTING
	spinner.target = hero
	spinner.target_pos = ConstantsData.xy_to_pos(12, 10)
	spinner.web_cooldown = 99
	level.find_step_result = ConstantsData.xy_to_pos(11, 10)

	spinner._act_hunting()

	t.check(
		level.last_find_step_target == ConstantsData.xy_to_pos(12, 10),
		"Spinner moves toward the last-known target cell instead of live-tracking an unseen target"
	)
	t.check(
		spinner.pos == ConstantsData.xy_to_pos(11, 10),
		"Spinner still advances one path step while pursuing the last-known target cell"
	)

	spinner.free()
	hero.free()

func _test_spinner_visible_adjacent_attack_still_works(t: Object) -> void:
	var level := FakeSpinnerLevel.new()
	var spinner := Spinner.new()
	var hero := Char.new()
	spinner.pos = ConstantsData.xy_to_pos(10, 10)
	hero.pos = ConstantsData.xy_to_pos(11, 10)
	spinner.level = level
	hero.level = level
	spinner.state = Mob.AIState.HUNTING
	spinner.target = hero
	spinner.target_pos = hero.pos
	spinner.web_cooldown = 99

	spinner._act_hunting()

	t.check(spinner.did_visible_action, "Spinner still performs a visible adjacent attack")
	t.check(spinner.last_visible_action == "attack", "Spinner adjacent target path still records an attack action")
	t.check(spinner.target == hero, "Spinner keeps the visible adjacent target after attacking")

	spinner.free()
	hero.free()
