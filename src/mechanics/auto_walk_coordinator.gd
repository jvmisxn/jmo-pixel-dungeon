class_name AutoWalkCoordinator
extends RefCounted

static func start(scene: Variant, target: int) -> void:
	if scene == null:
		return
	scene._auto_walk_target = target
	scene._auto_walk_known_mobs = get_visible_mob_positions(scene)
	var hero: Variant = scene._get_input_hero()
	scene._auto_walk_prev_hp = hero.hp if hero else -1

static func cancel(scene: Variant) -> void:
	if scene == null:
		return
	scene._auto_walk_target = -1
	scene._auto_walk_known_mobs.clear()
	scene._auto_walk_prev_hp = -1
	scene._auto_walk_cooldown = 0.0

static func process_step(scene: Variant, step_delay: float) -> void:
	if scene == null:
		return
	var hero: Variant = scene._get_input_hero()
	if hero == null or not hero.is_alive:
		cancel(scene)
		return
	if hero.pos == scene._auto_walk_target:
		var stair_action: String = _stair_action_for_cell(scene, hero.pos)
		cancel(scene)
		if not stair_action.is_empty():
			scene._submit_hero_action({"type": stair_action})
		return
	if scene._auto_walk_prev_hp >= 0 and hero.hp < scene._auto_walk_prev_hp:
		cancel(scene)
		return
	var current_mobs: Dictionary = get_visible_mob_positions(scene)
	for mob_key: Variant in current_mobs.keys():
		if not scene._auto_walk_known_mobs.has(mob_key):
			cancel(scene)
			return
	if scene._current_level:
		var heaps_here: Array[Dictionary] = scene._current_level.heaps_at(hero.pos)
		if not heaps_here.is_empty():
			cancel(scene)
			return
	if scene._current_level:
		var terrain: int = scene._current_level.terrain_at(hero.pos)
		if terrain == ConstantsData.Terrain.EXIT or terrain == ConstantsData.Terrain.ENTRANCE:
			cancel(scene)
			return
	if scene._current_level:
		for dir: int in ConstantsData.DIRS_8:
			var adj_pos: int = hero.pos + dir
			var char_at: Variant = scene._current_level.find_char_at(adj_pos)
			if char_at != null and char_at != hero:
				cancel(scene)
				return
	scene._auto_walk_known_mobs = current_mobs
	scene._auto_walk_prev_hp = hero.hp
	var pre_move_pos: int = hero.pos
	scene._submit_hero_action({"type": "move", "target_pos": scene._auto_walk_target})
	if hero.pos == pre_move_pos:
		cancel(scene)
	else:
		scene._auto_walk_cooldown = step_delay

static func get_visible_mob_positions(scene: Variant) -> Dictionary[int, bool]:
	var result: Dictionary[int, bool] = {}
	if scene == null or scene._current_level == null:
		return result
	for mob: Node in scene._current_level.mobs:
		if is_instance_valid(mob) and mob.get("is_alive") == true:
			var mob_pos: int = mob.get("pos") as int
			if mob_pos >= 0 and mob_pos < scene._current_level.visible.size():
				if scene._current_level.visible[mob_pos]:
					result[mob_pos] = true
	return result

static func interrupt_rest_if_needed(scene: Variant) -> void:
	if scene == null:
		return
	var hero: Variant = scene._get_input_hero()
	if hero == null or not hero.get("resting"):
		return
	var visible_mobs: Dictionary[int, bool] = get_visible_mob_positions(scene)
	if not visible_mobs.is_empty() and hero.has_method("interrupt"):
		hero.interrupt()

static func _stair_action_for_cell(scene: Variant, cell: int) -> String:
	if scene == null or scene._current_level == null:
		return ""
	var terrain: int = scene._current_level.terrain_at(cell)
	if terrain == ConstantsData.Terrain.ENTRANCE and cell == scene._current_level.entrance:
		return "ascend"
	if terrain == ConstantsData.Terrain.EXIT and cell == scene._current_level.exit_pos:
		return "descend"
	return ""
