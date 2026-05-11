class_name InputCoordinator
extends RefCounted

static func handle_cell_click(scene: Variant, cell: int) -> void:
	if scene == null:
		return
	var hero: Variant = scene._get_input_hero()
	if hero == null:
		return
	if scene._targeting_active:
		scene._resolve_targeting(cell)
		return
	scene._cancel_auto_walk()
	var hero_pos: int = hero.pos
	var char_at: Variant = scene._current_level.find_char_at(cell) if scene._current_level else null
	if char_at != null and char_at != hero:
		if scene._current_level.adjacent(hero_pos, cell):
			if char_at.has_method("interact"):
				scene._submit_hero_action({"type": "interact", "target_pos": cell})
			else:
				scene._submit_hero_action({"type": "attack", "target": char_at, "target_pos": cell})
		else:
			var ranged_action: Dictionary = hero.get_auto_ranged_action(cell) if hero.has_method("get_auto_ranged_action") else {}
			if not ranged_action.is_empty():
				scene._submit_hero_action(ranged_action)
			else:
				scene._start_auto_walk(cell)
				scene._submit_hero_action({"type": "move", "target_pos": cell})
	elif cell == hero_pos:
		var self_terrain: int = scene._current_level.terrain_at(cell) if scene._current_level else ConstantsData.Terrain.WALL
		if self_terrain == ConstantsData.Terrain.ENTRANCE and cell == scene._current_level.entrance:
			scene._submit_hero_action({"type": "ascend"})
		elif self_terrain == ConstantsData.Terrain.EXIT and cell == scene._current_level.exit_pos:
			scene._submit_hero_action({"type": "descend"})
		else:
			scene._submit_hero_action({"type": "wait"})
	else:
		if scene._current_level and scene._current_level.adjacent(hero_pos, cell):
			var terrain: int = scene._current_level.terrain_at(cell)
			if terrain == ConstantsData.Terrain.DOOR or terrain == ConstantsData.Terrain.LOCKED_DOOR or terrain == ConstantsData.Terrain.CRYSTAL_DOOR:
				scene._submit_hero_action({"type": "interact", "target_pos": cell})
			elif not scene._current_level.passable[cell]:
				scene._submit_hero_action({"type": "search"})
			else:
				scene._submit_hero_action({"type": "move", "target_pos": cell})
		else:
			scene._start_auto_walk(cell)
			scene._submit_hero_action({"type": "move", "target_pos": cell})

static func handle_key_input(scene: Variant, keycode: int) -> bool:
	if scene == null:
		return false
	if scene._targeting_active and keycode == KEY_ESCAPE:
		scene._cancel_targeting_mode()
		return true
	scene._cancel_auto_walk()
	match keycode:
		KEY_TAB:
			if GameManager and GameManager.has_method("is_party_run") and GameManager.is_party_run():
				if GameManager.has_method("cycle_local_hero_focus"):
					GameManager.cycle_local_hero_focus(1)
					return true
		KEY_A, KEY_F:
			attack_adjacent_enemy(scene)
			return true
		KEY_I:
			if scene._hud:
				scene._hud.toggle_inventory()
				return true
		KEY_M:
			if scene._hud:
				scene._hud.toggle_map()
				return true
		KEY_R:
			if scene._hud:
				scene._hud._on_rest_pressed()
				return true
		KEY_ESCAPE:
			if scene._hud and not scene._hud.has_active_window():
				scene._hud.open_settings()
				return true
		KEY_1:
			if scene._hud:
				scene._hud.use_quickslot(0)
				return true
		KEY_2:
			if scene._hud:
				scene._hud.use_quickslot(1)
				return true
		KEY_3:
			if scene._hud:
				scene._hud.use_quickslot(2)
				return true
		KEY_4:
			if scene._hud:
				scene._hud.use_quickslot(3)
				return true
		KEY_5:
			if scene._hud:
				scene._hud.use_quickslot(4)
				return true
		KEY_6:
			if scene._hud:
				scene._hud.use_quickslot(5)
				return true
		KEY_SPACE, KEY_PERIOD:
			scene._submit_hero_action({"type": "wait"})
			return true
		KEY_S:
			scene._submit_hero_action({"type": "search"})
			return true
		KEY_ENTER, KEY_KP_ENTER:
			var hero: Variant = scene._get_input_hero()
			if hero != null and scene._current_level != null:
				var terrain: int = scene._current_level.terrain_at(hero.pos)
				if terrain == ConstantsData.Terrain.ENTRANCE and hero.pos == scene._current_level.entrance:
					scene._submit_hero_action({"type": "ascend"})
					return true
				if terrain == ConstantsData.Terrain.EXIT and hero.pos == scene._current_level.exit_pos:
					scene._submit_hero_action({"type": "descend"})
					return true
		KEY_LESS:
			scene._submit_hero_action({"type": "ascend"})
			return true
		KEY_GREATER:
			scene._submit_hero_action({"type": "descend"})
			return true
	var move_dir: int = scene._movement_dir_for_key(keycode)
	if move_dir != 0:
		scene._set_held_move_state(keycode, move_dir)
		move_direction(scene, move_dir)
		return true
	return false

static func move_direction(scene: Variant, dir_offset: int) -> void:
	if scene == null:
		return
	var hero: Variant = scene._get_input_hero()
	if hero == null:
		return
	var target: int = hero.pos + dir_offset
	if not ConstantsData.is_valid_pos(target):
		return
	var char_at: Variant = scene._current_level.find_char_at(target) if scene._current_level else null
	if char_at != null and char_at != hero:
		if char_at.has_method("interact"):
			scene._submit_hero_action({"type": "interact", "target_pos": target})
		else:
			scene._submit_hero_action({"type": "attack", "target": char_at, "target_pos": target})
	else:
		var terrain: int = scene._current_level.terrain_at(target)
		if terrain == ConstantsData.Terrain.DOOR or terrain == ConstantsData.Terrain.LOCKED_DOOR or terrain == ConstantsData.Terrain.CRYSTAL_DOOR:
			scene._submit_hero_action({"type": "interact", "target_pos": target})
		elif not scene._current_level.passable[target]:
			scene._submit_hero_action({"type": "search"})
		else:
			scene._submit_hero_action({"type": "move", "target_pos": target})

static func attack_adjacent_enemy(scene: Variant) -> void:
	if scene == null:
		return
	var hero: Variant = scene._get_input_hero()
	if hero == null or scene._current_level == null:
		return
	var hero_pos: int = hero.pos
	for dir: int in ConstantsData.DIRS_8:
		var target_pos: int = hero_pos + dir
		if not ConstantsData.is_valid_pos(target_pos):
			continue
		var char_at: Variant = scene._current_level.find_char_at(target_pos)
		if char_at == null or char_at == hero or char_at.has_method("interact"):
			continue
		scene._submit_hero_action({"type": "attack", "target": char_at, "target_pos": target_pos})
		return
	if MessageLog:
		MessageLog.add_warning("No adjacent enemy to attack.")
