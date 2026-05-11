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
	if not party_ready_for_stairs(scene, scene._current_level.exit_pos, "All party members must be on the stairs down to descend."):
		scene._awaiting_hero_input = true
		return
	if MessageLog:
		MessageLog.add("You descend deeper into the dungeon...")
	if AudioManager:
		AudioManager.play_sfx("descend")
	notify_party_floor_change(scene)
	GameManager._cache_current_level()
	GameManager.depth += 1
	GameManager._on_depth_changed()
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
	if not party_ready_for_stairs(scene, scene._current_level.entrance, "All party members must be on the stairs up to ascend."):
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
	GameManager._cache_current_level()
	GameManager.depth -= 1
	GameManager._on_depth_changed()
	if scene._is_online_host():
		OnlineEventCodec.broadcast_level_transition(NetworkManager, GameManager.depth, "ascend")
	transition_to_loading(scene, "ascend")

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

static func transition_to_loading(scene: Variant, transition_type: String = "descend") -> void:
	if scene == null:
		return
	scene._game_ended = true
	scene._cancel_auto_walk()
	scene._detach_persistent_actors()
	var loading_script: GDScript = load("res://src/scenes/loading_scene.gd") as GDScript
	if loading_script:
		SceneManager.go_to(loading_script, "LoadingScene", {
			"is_continue": true,
			"transition_type": transition_type,
		})
