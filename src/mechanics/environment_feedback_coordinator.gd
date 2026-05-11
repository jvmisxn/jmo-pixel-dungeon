class_name EnvironmentFeedbackCoordinator
extends RefCounted

static func on_local_hero_changed(scene: Variant, hero_node: Node, hero_index: int) -> void:
	if scene == null or hero_node == null or scene._current_level == null:
		return
	if scene._current_level.has_method("update_fov"):
		var view_distance: int = hero_node.get_view_distance() if hero_node.has_method("get_view_distance") else ConstantsData.VIEW_DISTANCE
		scene._current_level.update_fov(hero_node.pos, view_distance)
	if scene.fog_of_war:
		scene.fog_of_war.update_visibility()
	scene._update_entity_visibility()
	scene._refresh_hero_identifiers()
	if scene.tile_map and scene.game_camera:
		var hero_world: Vector2 = scene.tile_map.cell_to_world(hero_node.pos)
		scene.game_camera.set_target(hero_world)
		scene.game_camera.global_position = hero_world
	if scene._hud and scene._hud.has_method("update_all"):
		scene._hud.update_all()

static func on_item_picked_up(scene: Variant, item_name: String) -> void:
	if scene == null:
		return
	if AudioManager:
		AudioManager.play_sfx("item_pickup")
	scene._queue_online_snapshot_sync(true)

static func on_door_opened(scene: Variant, pos: int) -> void:
	if scene == null:
		return
	if scene.tile_map:
		scene.tile_map.update_tile_at(pos)
	if AudioManager:
		AudioManager.play_sfx("door_open")
	if scene._is_online_host():
		OnlineEventCodec.emit_world_event(NetworkManager, {"type": "door_opened", "pos": pos})

static func on_item_used_sfx(item_name: String) -> void:
	if AudioManager == null:
		return
	var lower: String = item_name.to_lower()
	if "potion" in lower:
		AudioManager.play_sfx("drink")
	elif "scroll" in lower:
		AudioManager.play_sfx("read")
	elif "food" in lower or "ration" in lower or "pasty" in lower or "meat" in lower:
		AudioManager.play_sfx("eat")
	elif "bomb" in lower:
		AudioManager.play_sfx("blast")
	elif "honeypot" in lower:
		AudioManager.play_sfx("shatter")
	else:
		AudioManager.play_sfx("click")

static func on_grass_trampled() -> void:
	if AudioManager:
		AudioManager.play_sfx("trample")

static func on_seed_planted(scene: Variant, pos: int, plant_type: String) -> void:
	if scene == null:
		return
	if scene.effect_manager:
		scene.effect_manager.particle_burst(pos, plant_color_for(plant_type), 6)
		scene.effect_manager.show_status(pos, "Planted", Color(0.8, 0.95, 0.7))
	scene._refresh_plant_sprites()
	if scene._is_online_host():
		var plant_persists: bool = scene._current_level != null and scene._current_level.get("plants") is Dictionary and scene._current_level.plants.has(pos)
		OnlineEventCodec.emit_world_event(NetworkManager, {"type": "seed_planted", "pos": pos, "plant_type": plant_type, "persists": plant_persists})
	scene._queue_online_snapshot_sync(true)

static func on_plant_activated_vfx(scene: Variant, pos: int, plant_name: String) -> void:
	if scene == null:
		return
	if scene.effect_manager:
		var color: Color = plant_color_for(plant_name)
		scene.effect_manager.particle_burst(pos, color, 10)
		scene.effect_manager.ring_effect(pos, color, 22.0, 0.35)
		match plant_name.to_lower():
			"sungrass":
				scene.effect_manager.show_status(pos, "Regen", Color(1.0, 0.95, 0.45))
			"earthroot":
				scene.effect_manager.show_status(pos, "Armor", Color(0.72, 0.58, 0.32))
			"firebloom":
				scene.effect_manager.show_status(pos, "Burn!", Color(1.0, 0.4, 0.1))
			"icecap":
				scene.effect_manager.show_status(pos, "Frozen", Color(0.55, 0.82, 1.0))
			"sorrowmoss":
				scene.effect_manager.show_status(pos, "Poison", Color(0.45, 0.82, 0.38))
			"stormvine":
				scene.effect_manager.show_status(pos, "Rooted", Color(0.7, 0.75, 0.35))
			"blindweed":
				scene.effect_manager.show_status(pos, "Blind", Color(0.88, 0.88, 0.72))
			"dreamfoil":
				scene.effect_manager.show_status(pos, "Sleep", Color(0.72, 0.58, 0.92))
			"fadeleaf":
				scene.effect_manager.show_status(pos, "Warp", Color(0.62, 0.92, 0.72))
			"starflower":
				scene.effect_manager.show_status(pos, "XP", Color(1.0, 0.94, 0.35))
			"swiftthistle":
				scene.effect_manager.show_status(pos, "Haste", Color(0.96, 0.7, 0.95))
	scene._refresh_plant_sprites()
	if scene._is_online_host():
		OnlineEventCodec.emit_world_event(NetworkManager, {"type": "plant_activated", "pos": pos, "plant_name": plant_name})

static func plant_color_for(plant_name: String) -> Color:
	match plant_name.to_lower():
		"firebloom":
			return Color(0.96, 0.42, 0.1)
		"icecap":
			return Color(0.55, 0.82, 1.0)
		"sorrowmoss":
			return Color(0.45, 0.82, 0.38)
		"stormvine":
			return Color(0.72, 0.7, 0.95)
		"sungrass":
			return Color(0.95, 0.92, 0.38)
		"earthroot":
			return Color(0.62, 0.48, 0.24)
		"fadeleaf":
			return Color(0.62, 0.92, 0.72)
		"rotberry":
			return Color(0.82, 0.24, 0.34)
		"blindweed":
			return Color(0.88, 0.88, 0.72)
		"dreamfoil":
			return Color(0.72, 0.58, 0.92)
		"starflower":
			return Color(1.0, 0.94, 0.35)
		"swiftthistle":
			return Color(0.96, 0.7, 0.95)
		_:
			return Color(0.62, 0.86, 0.48)
