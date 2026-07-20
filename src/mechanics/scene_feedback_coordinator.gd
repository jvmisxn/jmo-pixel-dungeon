class_name SceneFeedbackCoordinator
extends RefCounted

static func refresh_after_turn(scene: Variant) -> void:
	if scene == null:
		return
	var local_hero: Variant = scene._get_focused_hero()
	if scene._current_level == null or local_hero == null:
		return
	scene._ensure_mob_sprites()
	var view_distance: int = local_hero.get_view_distance() if local_hero.has_method("get_view_distance") else ConstantsData.VIEW_DISTANCE
	scene._current_level.update_fov(local_hero.pos, view_distance)
	scene.fog_of_war.update_visibility()
	scene.tile_map.render_changed()
	scene.tile_map.update_tile_visibility()
	scene._update_entity_visibility()
	var hero_world: Vector2 = scene.tile_map.cell_to_world(local_hero.pos)
	scene.game_camera.set_target(hero_world)
	scene._cleanup_dead_mobs()
	scene._refresh_item_sprites()
	scene._refresh_plant_sprites()
	scene._refresh_armed_bomb_sprites()
	scene._interrupt_rest_if_needed()
	scene._sync_online_snapshot()

static func on_mob_action(scene: Variant, actor: Node) -> void:
	if scene == null or actor == null or not is_instance_valid(actor):
		return
	var actor_id: int = actor.get("actor_id") if actor.get("actor_id") != null else -1
	var sprite: Variant = scene._mob_sprites.get(actor_id) if actor_id >= 0 else null
	if sprite and is_instance_valid(sprite):
		var mob_pos: int = actor.get("pos") if actor.get("pos") != null else -1
		var action_name: String = str(actor.get("last_visible_action"))
		var action_target_pos: int = int(actor.get("last_visible_target_pos")) if actor.get("last_visible_target_pos") != null else -1
		if mob_pos >= 0 and mob_pos != sprite.cell_pos:
			sprite.move_to(mob_pos)
		if action_name == "attack" and action_target_pos >= 0:
			sprite.play_attack(action_target_pos)
		if actor.get("hp") != null and actor.get("ht") != null:
			sprite.update_hp_bar(actor.hp, actor.ht)
	var local_hero: Variant = scene._get_focused_hero()
	if scene._current_level and local_hero:
		var view_distance: int = local_hero.get_view_distance() if local_hero.has_method("get_view_distance") else ConstantsData.VIEW_DISTANCE
		scene._current_level.update_fov(local_hero.pos, view_distance)
		scene.fog_of_war.update_visibility()
		scene._update_entity_visibility()
		scene._interrupt_rest_if_needed()
	scene._queue_online_snapshot_sync(true)

static func on_mob_defeated(scene: Variant, mob_pos: int, mob_name: String, mob_id: String) -> void:
	if scene == null:
		return
	if scene.effect_manager:
		scene.effect_manager.particle_burst(mob_pos, Color(0.8, 0.2, 0.1), 6)
	if AudioManager:
		AudioManager.play_sfx("hit")
	if scene._is_online_host():
		OnlineEventCodec.emit_world_event(NetworkManager, OnlineEventCodec.build_mob_defeated_world_event_payload(mob_pos, mob_name, mob_id))

static func on_hero_damaged(scene: Variant, amount: int, source: Variant) -> void:
	if scene == null:
		return
	var hero: Variant = scene._get_focused_hero()
	scene._cancel_auto_walk()
	if hero and hero.has_method("interrupt"):
		hero.interrupt()
	if scene.game_camera:
		var intensity: float = clampf(float(amount) / 10.0, 1.0, 5.0)
		scene.game_camera.shake(intensity, 0.2)
	if scene.effect_manager and hero:
		scene.effect_manager.show_damage(hero.pos, amount)
	if AudioManager:
		AudioManager.play_sfx("hit")
		if hero and hero.get("hp") != null and hero.get("ht") != null:
			var hp: int = hero.hp
			var ht: int = hero.ht
			if ht > 0:
				var hp_ratio: float = float(hp) / float(ht)
				if hp_ratio < 0.25:
					AudioManager.play_sfx("health_critical")
				elif hp_ratio < 0.5:
					AudioManager.play_sfx("health_warn")

static func on_hero_damaged_detailed(scene: Variant, hero_node: Variant, amount: int, source: Variant) -> void:
	if scene == null:
		return
	var focused_hero: Variant = scene._get_focused_hero()
	if focused_hero != hero_node:
		return
	on_hero_damaged(scene, amount, source)
	if source is Buff:
		OnlineEventCodec.show_status_effect_feedback(scene.effect_manager, hero_node.pos, str((source as Buff).buff_id))

static func on_status_effect_applied(scene: Variant, target: Variant, effect_id: String) -> void:
	if scene == null or target == null or not is_instance_valid(target):
		return
	var normalized_effect: String = effect_id.to_lower()
	var target_pos: int = int(ConstantsData.get_prop(target, "pos", -1))
	if target_pos < 0:
		return
	var feedback: Dictionary = OnlineEventCodec.get_status_effect_feedback(normalized_effect)
	if feedback.is_empty():
		return
	OnlineEventCodec.show_status_effect_feedback(scene.effect_manager, target_pos, normalized_effect)
	if scene._is_online_host():
		OnlineEventCodec.emit_world_event(NetworkManager, OnlineEventCodec.build_status_effect_world_event_payload(target_pos, normalized_effect))

static func on_mob_revealed(scene: Variant, mob: Variant) -> void:
	if scene == null:
		return
	if mob is Object and mob.get("is_alive") == true:
		scene._spawn_single_mob_sprite(mob)
		if scene._is_online_host():
			OnlineEventCodec.emit_world_event(NetworkManager, OnlineEventCodec.build_mob_revealed_world_event_payload(mob))

static func on_mob_damaged(scene: Variant, mob_pos: int, amount: int) -> void:
	if scene == null:
		return
	if scene.effect_manager:
		scene.effect_manager.show_damage(mob_pos, amount)
	scene._queue_online_snapshot_sync(true)

static func on_hero_attack_missed(scene: Variant, mob_pos: int) -> void:
	if scene == null:
		return
	if scene.effect_manager:
		scene.effect_manager.show_status(mob_pos, "0", Color(0.7, 0.7, 0.7))
	if AudioManager:
		AudioManager.play_sfx("miss")
	if scene._is_online_host():
		OnlineEventCodec.emit_world_event(NetworkManager, {"type": "hero_attack_missed", "pos": mob_pos})

static func on_round_completed(scene: Variant, round_number: int) -> void:
	if scene == null or scene._current_level == null:
		return
	if scene._current_level.has_method("tick_pending_bombs"):
		var detonated: bool = scene._current_level.tick_pending_bombs()
		if detonated:
			refresh_after_turn(scene)
	scene._queue_online_snapshot_sync()

static func on_turn_processed(scene: Variant, _actor: Node, _turn_number: int) -> void:
	if scene == null or scene._current_level == null:
		return
	# Advance gas/liquid blobs after every processed actor turn. The level self-
	# limits by the shared TurnManager clock, so this produces one blob step per
	# game-time tick without batching behind party rounds.
	if scene._current_level.has_method("advance_blobs"):
		var now_time: float = TurnManager.now() if (TurnManager != null and TurnManager.has_method("now")) else 0.0
		var blobs_changed: bool = scene._current_level.advance_blobs(now_time)
		if blobs_changed:
			refresh_after_turn(scene)
			scene._queue_online_snapshot_sync()
	elif scene._current_level.has_method("tick_blobs"):
		var blobs_active: bool = scene._current_level.tick_blobs()
		if blobs_active:
			refresh_after_turn(scene)
			scene._queue_online_snapshot_sync()

static func on_trap_triggered(scene: Variant, pos: int, trap_name: String) -> void:
	if scene == null:
		return
	if AudioManager:
		AudioManager.play_sfx("trap")
	if scene._current_level != null:
		if scene.tile_map:
			scene.tile_map.level = scene._current_level
			scene.tile_map.render_changed()
		var hero: Variant = scene._get_focused_hero()
		if GameManager and hero and scene._current_level.has_method("update_fov"):
			var view_distance: int = hero.get_view_distance() if hero.has_method("get_view_distance") else ConstantsData.VIEW_DISTANCE
			scene._current_level.update_fov(hero.pos, view_distance)
		if scene.fog_of_war:
			scene.fog_of_war.update_visibility()
		scene._update_entity_visibility()
	if scene._is_online_host():
		OnlineEventCodec.emit_world_event(NetworkManager, {"type": "trap_triggered", "pos": pos, "trap_name": trap_name})
	scene._queue_online_snapshot_sync(true)
