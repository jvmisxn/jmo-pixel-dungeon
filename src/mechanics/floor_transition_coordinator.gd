class_name FloorTransitionCoordinator
extends RefCounted

static func handle_descend(scene: Variant) -> void:
	if scene == null:
		return
	var hero: Variant = scene._get_input_hero()
	if hero == null:
		return
	if scene._current_level and hero.pos != scene._current_level.exit_pos:
		if MessageLog:
			MessageLog.add_warning("You need to be on the stairs down to descend.")
		scene._awaiting_hero_input = true
		return
	if not party_ready_for_stairs(
		scene,
		scene._current_level.exit_pos,
		"All party members must be on the stairs down to descend."
	):
		scene._awaiting_hero_input = true
		return
	if GameManager == null or GameManager.depth >= ConstantsData.MAX_DEPTH:
		if MessageLog:
			MessageLog.add_warning("The way deeper is sealed.")
		scene._awaiting_hero_input = true
		return
	if not _consume_skeleton_key_for_boss_exit(scene, hero):
		return
	if MessageLog:
		MessageLog.add("You descend deeper into the dungeon...")
	if AudioManager:
		AudioManager.play_sfx("descend")
	notify_party_floor_change(scene)
	var new_depth: int = GameManager.descend()
	if new_depth < 0:
		scene._awaiting_hero_input = true
		return
	if scene._is_online_host():
		OnlineEventCodec.broadcast_level_transition(NetworkManager, GameManager.depth, "descend")
	transition_to_loading(scene, "descend")

static func handle_ascend(scene: Variant) -> void:
	if scene == null:
		return
	var hero: Variant = scene._get_input_hero()
	if hero == null:
		return
	if scene._current_level and hero.pos != scene._current_level.entrance:
		if MessageLog:
			MessageLog.add_warning("You need to be on the stairs up to ascend.")
		scene._awaiting_hero_input = true
		return
	if not party_ready_for_stairs(
		scene,
		scene._current_level.entrance,
		"All party members must be on the stairs up to ascend."
	):
		scene._awaiting_hero_input = true
		return
	if GameManager.depth <= 1:
		if MessageLog:
			MessageLog.add_warning("The way to the surface is sealed.")
		scene._awaiting_hero_input = true
		return
	if MessageLog:
		MessageLog.add("You ascend the staircase...")
	if AudioManager:
		AudioManager.play_sfx("descend")
	notify_party_floor_change(scene)
	var new_depth: int = GameManager.ascend()
	if new_depth < 0:
		scene._awaiting_hero_input = true
		return
	if scene._is_online_host():
		OnlineEventCodec.broadcast_level_transition(NetworkManager, GameManager.depth, "ascend")
	transition_to_loading(scene, "ascend")

static func handle_fall(scene: Variant, hero_node: Variant) -> void:
	if scene == null or hero_node == null:
		return
	if scene.get("_game_ended") == true:
		return
	if GameManager == null or GameManager.depth >= ConstantsData.MAX_DEPTH:
		_relocate_faller_on_current_level(scene, hero_node)
		Chasm.apply_landing_damage(hero_node, scene._current_level)
		scene.refresh_after_turn()
		return
	if AudioManager:
		AudioManager.play_sfx("falling")
	notify_party_floor_change(scene)
	var fall_actor_id: int = int(hero_node.get("actor_id")) if hero_node.get("actor_id") != null else -1
	var new_depth: int = GameManager.descend()
	if new_depth < 0:
		_relocate_faller_on_current_level(scene, hero_node)
		Chasm.apply_landing_damage(hero_node, scene._current_level)
		scene.refresh_after_turn()
		return
	if scene._is_online_host():
		OnlineEventCodec.broadcast_level_transition(NetworkManager, GameManager.depth, "fall")
	transition_to_loading(scene, "fall", {"fall_actor_id": fall_actor_id})

static func _consume_skeleton_key_for_boss_exit(scene: Variant, hero: Variant) -> bool:
	if GameManager == null or not _is_skeleton_key_depth(GameManager.depth):
		return true
	var key_holder: Variant = _find_skeleton_key_holder(hero)
	if key_holder != null:
		if _consume_skeleton_key(key_holder):
			return true
		if key_holder.has_method("use_key"):
			key_holder.use_key("skeleton")
		return true
	if MessageLog:
		MessageLog.add_warning("You need the skeleton key to unlock the way forward.")
	if scene != null:
		scene._awaiting_hero_input = true
	return false

static func _find_skeleton_key_holder(fallback_hero: Variant) -> Variant:
	if GameManager != null and GameManager.has_method("get_active_heroes"):
		for party_hero: Variant in GameManager.get_active_heroes():
			if _has_skeleton_key_for_current_depth(party_hero):
				return party_hero
	if _has_skeleton_key_for_current_depth(fallback_hero):
		return fallback_hero
	return null

static func _has_skeleton_key_for_current_depth(hero: Variant) -> bool:
	if hero == null:
		return false
	var belongings: Variant = hero.get("belongings") if hero is Object else null
	var backpack: Variant = belongings.get("backpack") if belongings != null else null
	if backpack is Array:
		for item: Variant in backpack:
			if _is_current_depth_skeleton_key(item):
				return true
		return false
	return hero.has_method("has_key") and hero.has_key("skeleton")

static func _consume_skeleton_key(hero: Variant) -> bool:
	if hero == null:
		return false
	var belongings: Variant = hero.get("belongings") if hero is Object else null
	var backpack: Variant = belongings.get("backpack") if belongings != null else null
	if not (backpack is Array):
		return false
	for item: Variant in backpack:
		if not _is_current_depth_skeleton_key(item):
			continue
		if belongings.has_method("remove_item"):
			belongings.remove_item(item)
			if MessageLog:
				MessageLog.add("You use the %s." % ConstantsData.get_prop(item, "item_name", "key"))
			return true
	return false

static func _is_current_depth_skeleton_key(item: Variant) -> bool:
	return item != null \
			and ConstantsData.get_prop(item, "item_id", "") == "skeleton_key" \
			and int(ConstantsData.get_prop(item, "depth", -1)) == GameManager.depth

static func _is_skeleton_key_depth(depth: int) -> bool:
	return depth > 0 and depth % 5 == 0 and depth < ConstantsData.MAX_DEPTH

static func party_ready_for_stairs(scene: Variant, stair_pos: int, failure_message: String) -> bool:
	if scene == null or GameManager == null or not GameManager.has_method("get_active_heroes"):
		return true
	var party: Array[Node] = GameManager.get_active_heroes()
	if party.size() <= 1:
		return true
	var missing_count: int = 0
	for party_hero: Variant in party:
		if party_hero == null or not party_hero.get("is_alive"):
			continue
		if int(party_hero.get("pos")) != stair_pos:
			missing_count += 1
	if missing_count <= 0:
		return true
	if MessageLog:
		MessageLog.add_warning("%s (%d missing)" % [failure_message, missing_count])
	return false

static func notify_party_floor_change(scene: Variant) -> void:
	if scene == null or GameManager == null or not GameManager.has_method("get_active_heroes"):
		return
	for party_hero: Variant in GameManager.get_active_heroes():
		if party_hero == null:
			continue
		var belongings: Variant = party_hero.get("belongings")
		if belongings != null and belongings.has_method("get_equipped_artifact"):
			var artifact: Variant = belongings.get_equipped_artifact()
			if artifact != null and artifact.has_method("on_floor_change"):
				artifact.on_floor_change()

static func transition_to_loading(scene: Variant, transition_type: String = "descend", extra_meta: Dictionary = {}) -> void:
	if scene == null:
		return
	scene._game_ended = true
	scene._cancel_auto_walk()
	scene._detach_persistent_actors()
	var loading_script: GDScript = load("res://src/scenes/loading_scene.gd") as GDScript
	if loading_script:
		var meta: Dictionary = {
			"is_continue": true,
			"transition_type": transition_type,
		}
		meta.merge(extra_meta, true)
		SceneManager.go_to(loading_script, "LoadingScene", meta)

static func _relocate_faller_on_current_level(scene: Variant, hero_node: Variant) -> void:
	if scene == null or hero_node == null:
		return
	var level: Variant = scene.get("_current_level")
	if level == null or not level.has_method("random_passable_cell"):
		return
	var landing: int = level.random_passable_cell()
	if landing < 0:
		return
	hero_node.set("pos", landing)
	hero_node.set("level", level)
