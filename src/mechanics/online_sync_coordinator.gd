class_name OnlineSyncCoordinator
extends RefCounted

static func sync_snapshot(scene: Variant, force: bool = false) -> void:
	if scene == null or not scene._is_online_host():
		return
	if not force and TurnManager != null and not TurnManager.waiting_for_input:
		return
	OnlineEventCodec.broadcast_run_snapshot(NetworkManager, scene._serialize_online_snapshot())

static func submit_hero_action(scene: Variant, action: Dictionary, equip_slot_names: Array[String]) -> void:
	if scene == null:
		return
	var hero: Variant = scene._get_input_hero()
	if hero == null:
		return
	if scene._should_route_online_action(hero):
		scene._preview_online_local_action(hero, action)
		var slot_index: int = int(hero.get("hero_slot_index"))
		scene._awaiting_hero_input = false
		OnlineEventCodec.request_online_action(NetworkManager, slot_index, OnlineActionCodec.encode_network_action(hero, action, equip_slot_names))
		return
	scene._apply_action_for_hero(hero, action)

static func handle_world_event(scene: Variant, event: Dictionary) -> void:
	if scene == null or not scene._is_online_client() or event.is_empty():
		return
	OnlineEventCodec.handle_world_event(event, _build_world_event_context(scene))

static func handle_ui_event(scene: Variant, event: Dictionary) -> void:
	if scene == null:
		return
	OnlineEventCodec.handle_ui_event(event, scene._hud, EventBus, MessageLog, Callable(scene, "_find_hero_by_actor_id"))

static func _build_world_event_context(scene: Variant) -> Dictionary:
	return {
		"suppressed_snapshot_pickups": scene._suppressed_snapshot_pickups,
		"suppressed_snapshot_doors": scene._suppressed_snapshot_doors,
		"item_sprites": scene._item_sprites,
		"hero_sprites": scene._hero_sprites,
		"mob_sprites": scene._mob_sprites,
		"effect_manager": scene.effect_manager,
		"message_log": MessageLog,
		"audio_manager": AudioManager,
		"current_level": scene._current_level,
		"entity_layer": scene._entity_layer,
		"fog_of_war": scene.fog_of_war,
		"tile_map": scene.tile_map,
		"game_camera": scene.game_camera,
		"hud": scene._hud,
		"suppress_snapshot_feedback": Callable(scene, "_suppress_snapshot_feedback"),
		"remove_local_heap_at_pos": Callable(scene, "_remove_local_heap_at_pos"),
		"on_door_opened": Callable(scene, "_on_door_opened"),
		"on_seed_planted": Callable(scene, "_on_seed_planted"),
		"on_plant_activated_vfx": Callable(scene, "_on_plant_activated_vfx"),
		"spawn_single_mob_sprite": Callable(scene, "_spawn_single_mob_sprite"),
		"get_focused_hero": Callable(scene, "_get_focused_hero"),
		"refresh_client_visibility_preview": Callable(scene, "_refresh_client_visibility_preview"),
		"update_entity_visibility": Callable(scene, "_update_entity_visibility"),
	}
