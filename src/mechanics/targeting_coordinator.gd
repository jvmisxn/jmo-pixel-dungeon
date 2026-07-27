class_name TargetingCoordinator
extends RefCounted

static func enter(scene: Variant, item: Variant, max_range: int, callback: Callable, auto_resolve: bool = false) -> void:
	if scene == null:
		return
	scene._targeting_active = true
	scene._targeting_item = item
	scene._targeting_max_range = max_range
	scene._targeting_callback = callback
	scene._cancel_auto_walk()
	if auto_resolve:
		var auto_cell: int = auto_target_cell(scene)
		if auto_cell >= 0:
			resolve(scene, auto_cell)
			return
	if MessageLog:
		var item_name: String = ConstantsData.get_prop(item, "item_name", "item") if item is Object else "item"
		MessageLog.add("Select a target for the %s. (Press Escape to cancel)" % item_name)

static func cancel(scene: Variant) -> void:
	if scene == null or not scene._targeting_active:
		return
	scene._targeting_active = false
	scene._targeting_item = null
	scene._targeting_max_range = 0
	scene._targeting_callback = Callable()
	scene._awaiting_hero_input = true
	if MessageLog:
		MessageLog.add("Targeting cancelled.")

static func resolve(scene: Variant, cell: int) -> void:
	if scene == null or not scene._targeting_active:
		return
	if not ConstantsData.is_valid_pos(cell):
		if MessageLog:
			MessageLog.add_warning("Invalid target!")
		return
	var hero: Variant = scene._get_input_hero()
	if hero == null:
		cancel(scene)
		return
	if scene._targeting_max_range > 0:
		var dist: int = hero.distance_to(cell) if hero.has_method("distance_to") else 999
		if dist > scene._targeting_max_range:
			if MessageLog:
				MessageLog.add_warning("Out of range!")
			return
	if scene._current_level and cell >= 0 and cell < scene._current_level.visible.size():
		if not scene._current_level.visible[cell]:
			if MessageLog:
				MessageLog.add_warning("You can't see that cell!")
			return
	var callback: Callable = scene._targeting_callback
	var item: Variant = scene._targeting_item
	scene._last_target_pos = cell
	scene._targeting_active = false
	scene._targeting_item = null
	scene._targeting_max_range = 0
	scene._targeting_callback = Callable()
	if item != null and (
		(item is Object and item.get("item_id") == "spirit_bow") or
		item.has_method("proc") or
		item.has_method("explode") or
		item.has_method("zap")
	):
		var acting_hero: Variant = scene._get_input_hero()
		var hero_sprite: Variant = scene._hero_sprites.get(acting_hero.actor_id) if acting_hero != null else null
		if hero_sprite != null:
			if item.has_method("zap") and hero_sprite.has_method("play_zap"):
				hero_sprite.play_zap(cell)
			else:
				hero_sprite.play_attack(cell)
	if callback.is_valid():
		callback.call(cell)
	scene.call_deferred("refresh_after_turn")

static func auto_target_cell(scene: Variant) -> int:
	if scene == null:
		return -1
	var hero: Variant = scene._get_input_hero()
	if hero == null:
		return -1
	var last_target: int = scene._last_target_pos
	if _is_valid_auto_target(scene, hero, last_target):
		return last_target
	var level: Variant = scene._current_level
	if level == null or level.get("mobs") == null:
		return -1
	var best_pos: int = -1
	var best_dist: int = 999999
	for mob: Variant in level.mobs:
		if mob == null:
			continue
		var mob_pos: int = int(mob.get("pos")) if mob.get("pos") != null else -1
		if not _is_valid_auto_target(scene, hero, mob_pos):
			continue
		var dist: int = hero.distance_to(mob_pos) if hero.has_method("distance_to") else best_dist
		if dist < best_dist:
			best_dist = dist
			best_pos = mob_pos
	return best_pos

static func _is_valid_auto_target(scene: Variant, hero: Variant, cell: int) -> bool:
	if scene == null or hero == null or scene._current_level == null:
		return false
	if not ConstantsData.is_valid_pos(cell):
		return false
	if scene._targeting_max_range > 0:
		var dist: int = hero.distance_to(cell) if hero.has_method("distance_to") else 999999
		if dist > scene._targeting_max_range:
			return false
	var level: Variant = scene._current_level
	if level.get("visible") != null:
		if cell < 0 or cell >= level.visible.size() or not level.visible[cell]:
			return false
	var target: Variant = level.find_char_at(cell) if level.has_method("find_char_at") else null
	if target == null or target == hero:
		return false
	# NPCs are dialogue targets, never attack targets (allies are excluded
	# below; hostile mobs now also expose interact() but stay attackable).
	if target is NPC:
		return false
	if target.get("is_alive") != null and target.get("is_alive") != true:
		return false
	if target.get("is_ally") != null and target.get("is_ally") == true:
		return false
	return true
