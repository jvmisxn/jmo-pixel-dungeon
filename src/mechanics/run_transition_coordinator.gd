class_name RunTransitionCoordinator
extends RefCounted

static func handle_online_run_ended(scene: Variant, victory: bool, payload: Dictionary) -> void:
	if scene == null or not scene._is_online_client():
		return
	scene._game_ended = true
	scene._cancel_auto_walk()
	scene._detach_persistent_actors()
	if victory:
		var victory_script: GDScript = load("res://src/scenes/victory_scene.gd") as GDScript
		if victory_script:
			SceneManager.go_to(victory_script, "VictoryScene")
		return
	var death_script: GDScript = load("res://src/scenes/death_scene.gd") as GDScript
	if death_script:
		SceneManager.go_to(death_script, "DeathScene", {
			"cause_of_death": str(payload.get("cause_of_death", "the dungeon")),
		})

static func handle_party_hero_death(scene: Variant, hero_node: Variant) -> void:
	if scene == null or hero_node == null:
		return
	var hero_key: int = hero_node.get("actor_id") if hero_node.get("actor_id") != null else -1
	var hero_sprite: Variant = scene._hero_sprites.get(hero_key) if hero_key >= 0 else null
	if is_instance_valid(hero_sprite) and hero_sprite.has_method("play_hero_death"):
		hero_sprite.play_hero_death(0.7)
	var hero_name: String = ConstantsData.get_prop(hero_node, "hero_name", "A hero")
	if MessageLog:
		MessageLog.add_warning("%s has fallen." % hero_name)
	var focused_hero: Variant = scene._get_focused_hero()
	if focused_hero == hero_node:
		var spectate_hero: Variant = scene._find_best_spectate_hero()
		if spectate_hero != null and GameManager != null and GameManager.has_method("set_local_hero_index"):
			var new_index: int = GameManager.get_hero_index(spectate_hero) if GameManager.has_method("get_hero_index") else -1
			if new_index >= 0:
				GameManager.set_local_hero_index(new_index)
		else:
			scene.refresh_after_turn()
	scene._sync_online_snapshot()

static func handle_hero_died(scene: Variant) -> void:
	if scene == null:
		return
	scene._game_ended = true
	scene._cancel_auto_walk()
	if TurnManager:
		TurnManager.processing_mobs = false
		TurnManager.waiting_for_input = false
	var hero: Variant = scene._get_focused_hero()
	if hero != null:
		var hero_key: int = hero.get("actor_id") if hero.get("actor_id") != null else -1
		var hero_sprite: Variant = scene._hero_sprites.get(hero_key) if hero_key >= 0 else null
		if is_instance_valid(hero_sprite) and hero_sprite.has_method("play_hero_death"):
			hero_sprite.play_hero_death()
	if AudioManager:
		AudioManager.play_sfx("death")
		AudioManager.stop_music()
	var timer: SceneTreeTimer = scene.get_tree().create_timer(1.15)
	timer.timeout.connect(scene._transition_to_death)

static func handle_hero_died_detailed(scene: Variant, hero_node: Variant) -> void:
	if scene == null:
		return
	if GameManager != null and GameManager.has_method("are_all_heroes_dead") and not GameManager.are_all_heroes_dead():
		handle_party_hero_death(scene, hero_node)
		return
	var focused_hero: Variant = scene._get_focused_hero()
	if focused_hero != hero_node and focused_hero != null:
		var spectate_index: int = GameManager.get_hero_index(hero_node) if GameManager and GameManager.has_method("get_hero_index") else -1
		if spectate_index >= 0 and GameManager.has_method("set_local_hero_index"):
			GameManager.set_local_hero_index(spectate_index)
	handle_hero_died(scene)

static func transition_to_death(scene: Variant) -> void:
	if scene == null:
		return
	scene._detach_persistent_actors()
	var cause: String = "the dungeon"
	var hero: Variant = scene._get_focused_hero()
	if hero and hero.get("last_damage_source") != null:
		var src: Variant = hero.last_damage_source
		if src is Object and src.get("mob_name"):
			cause = src.mob_name
		elif src is String:
			cause = src
		else:
			cause = str(src)
	if scene._is_online_host():
		OnlineEventCodec.broadcast_run_end(NetworkManager, false, {"cause_of_death": cause})
	var death_script: GDScript = load("res://src/scenes/death_scene.gd") as GDScript
	if death_script:
		SceneManager.go_to(death_script, "DeathScene", {"cause_of_death": cause})

static func transition_to_victory(scene: Variant) -> void:
	if scene == null:
		return
	scene._game_ended = true
	scene._cancel_auto_walk()
	scene._detach_persistent_actors()
	if AudioManager:
		AudioManager.play_sfx("victory")
		AudioManager.stop_music()
	if scene._is_online_host():
		OnlineEventCodec.broadcast_run_end(NetworkManager, true, {})
	var victory_script: GDScript = load("res://src/scenes/victory_scene.gd") as GDScript
	if victory_script:
		SceneManager.go_to(victory_script, "VictoryScene")
		return
	if MessageLog:
		MessageLog.add_positive("You obtained the Amulet of Yendor! You win!")
	var timer: SceneTreeTimer = scene.get_tree().create_timer(3.0)
	timer.timeout.connect(func() -> void:
		var title_script: GDScript = load("res://src/scenes/title_scene.gd") as GDScript
		if title_script:
			SceneManager.go_to(title_script, "TitleScene")
	)
