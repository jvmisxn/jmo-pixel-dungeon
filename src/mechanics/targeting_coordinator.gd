class_name TargetingCoordinator
extends RefCounted

static func enter(scene: Variant, item: Variant, max_range: int, callback: Callable) -> void:
	if scene == null:
		return
	scene._targeting_active = true
	scene._targeting_item = item
	scene._targeting_max_range = max_range
	scene._targeting_callback = callback
	scene._cancel_auto_walk()
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
	scene._targeting_active = false
	scene._targeting_item = null
	scene._targeting_max_range = 0
	scene._targeting_callback = Callable()
	if item != null and (
		(item is Object and item.get("item_id") == "spirit_bow") or
		(item != null and item.has_method("proc")) or
		(item != null and item.has_method("explode")) or
		(item != null and item.has_method("zap"))
	):
		var acting_hero: Variant = scene._get_input_hero()
		var hero_sprite: Variant = scene._hero_sprites.get(acting_hero.actor_id) if acting_hero != null else null
		if hero_sprite != null:
			hero_sprite.play_attack(cell)
	if callback.is_valid():
		callback.call(cell)
	scene.call_deferred("refresh_after_turn")
