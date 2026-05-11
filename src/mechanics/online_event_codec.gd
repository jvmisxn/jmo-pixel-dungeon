class_name OnlineEventCodec
extends RefCounted

static func serialize_shop_items(shopkeeper_node: Variant) -> Array[Dictionary]:
	var shop_data: Array[Dictionary] = []
	if shopkeeper_node == null or not shopkeeper_node.has_method("get_shop_items"):
		return shop_data
	for entry: Dictionary in shopkeeper_node.get_shop_items():
		var serialized_entry: Dictionary = {"price": int(entry.get("price", 0))}
		var item: Variant = entry.get("item")
		if item != null and item.has_method("serialize"):
			serialized_entry["item_data"] = item.serialize()
		shop_data.append(serialized_entry)
	return shop_data

static func deserialize_shop_items(items_data: Variant) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if not (items_data is Array):
		return items
	for entry: Variant in items_data:
		if not (entry is Dictionary):
			continue
		var item_entry: Dictionary = entry
		var item_dict: Dictionary = {"price": int(item_entry.get("price", 0))}
		var item_data: Variant = item_entry.get("item_data", {})
		if item_data is Dictionary:
			var item_node: Variant = OnlineSnapshotUtils.make_item_from_data(item_data)
			if item_node != null:
				item_dict["item"] = item_node
		items.append(item_dict)
	return items

static func deserialize_item_list(items_data: Variant) -> Array:
	var items: Array = []
	if not (items_data is Array):
		return items
	for item_entry: Variant in items_data:
		if item_entry is Dictionary:
			var item_node: Variant = OnlineSnapshotUtils.make_item_from_data(item_entry)
			if item_node != null:
				items.append(item_node)
	return items

static func deserialize_item(item_data: Variant) -> Variant:
	return OnlineSnapshotUtils.make_item_from_data(item_data) if item_data is Dictionary else null

static func get_npc_reward_choices(npc_node: Variant) -> Array:
	var rewards: Array = []
	if npc_node == null:
		return rewards
	var reward_weapon: Variant = ConstantsData.get_prop(npc_node, "reward_weapon", null)
	var reward_armor: Variant = ConstantsData.get_prop(npc_node, "reward_armor", null)
	var reward_ring: Variant = ConstantsData.get_prop(npc_node, "reward_ring", null)
	var wand_choice_a: Variant = ConstantsData.get_prop(npc_node, "wand_choice_a", null)
	var wand_choice_b: Variant = ConstantsData.get_prop(npc_node, "wand_choice_b", null)
	if reward_weapon != null:
		rewards.append(reward_weapon)
	if reward_armor != null:
		rewards.append(reward_armor)
	if reward_ring != null:
		rewards.append(reward_ring)
	if wand_choice_a != null:
		rewards.append(wand_choice_a)
	if wand_choice_b != null:
		rewards.append(wand_choice_b)
	return rewards

static func make_plant_from_type(plant_type: String) -> Variant:
	var normalized_type: String = plant_type.to_lower()
	var plant_script_path: String = ""
	match normalized_type:
		"sungrass":
			plant_script_path = "res://src/plants/sungrass.gd"
		"earthroot":
			plant_script_path = "res://src/plants/earthroot.gd"
		"fadeleaf":
			plant_script_path = "res://src/plants/fadeleaf.gd"
		"firebloom":
			plant_script_path = "res://src/plants/firebloom.gd"
		"icecap":
			plant_script_path = "res://src/plants/icecap.gd"
		"sorrowmoss":
			plant_script_path = "res://src/plants/sorrowmoss.gd"
		"dreamfoil":
			plant_script_path = "res://src/plants/dreamfoil.gd"
		"stormvine":
			plant_script_path = "res://src/plants/stormvine.gd"
		"blindweed":
			plant_script_path = "res://src/plants/blindweed.gd"
		"rotberry":
			plant_script_path = "res://src/plants/rotberry.gd"
		"starflower":
			plant_script_path = "res://src/plants/starflower.gd"
		"swiftthistle":
			plant_script_path = "res://src/plants/swiftthistle.gd"
		_:
			return null
	var plant_script: Variant = load(plant_script_path)
	return plant_script.new() if plant_script != null else null

static func get_status_effect_feedback(effect_id: String) -> Dictionary:
	match effect_id.to_lower():
		"poison":
			return {"text": "Poison", "color": Color(0.45, 0.82, 0.38), "burst": 8}
		"burning":
			return {"text": "Burn!", "color": Color(1.0, 0.42, 0.12), "burst": 9}
		"paralysis":
			return {"text": "Paralyzed", "color": Color(1.0, 0.92, 0.35), "burst": 7}
		"blindness":
			return {"text": "Blind", "color": Color(0.72, 0.72, 0.72), "burst": 6}
		"chill":
			return {"text": "Chill", "color": Color(0.45, 0.74, 1.0), "burst": 7}
		"frozen":
			return {"text": "Frozen", "color": Color(0.55, 0.82, 1.0), "burst": 8}
		"rooted":
			return {"text": "Rooted", "color": Color(0.42, 0.72, 0.28), "burst": 7}
		"cripple":
			return {"text": "Crippled", "color": Color(0.82, 0.72, 0.38), "burst": 6}
		"weakness":
			return {"text": "Weak", "color": Color(0.74, 0.56, 0.82), "burst": 6}
		"ooze":
			return {"text": "Ooze", "color": Color(0.56, 0.82, 0.42), "burst": 6}
		_:
			return {}

static func show_status_effect_feedback(effect_manager: Variant, pos: int, effect_id: String) -> void:
	if pos < 0 or effect_manager == null:
		return
	var feedback: Dictionary = get_status_effect_feedback(effect_id)
	if feedback.is_empty():
		return
	var effect_color: Color = feedback.get("color", Color.WHITE) as Color
	var effect_text: String = str(feedback.get("text", effect_id.capitalize()))
	var burst_count: int = int(feedback.get("burst", 6))
	effect_manager.particle_burst(pos, effect_color, burst_count)
	effect_manager.show_status(pos, effect_text, effect_color)

static func handle_ui_event(event: Dictionary, hud: Variant, event_bus: Variant, message_log: Variant, find_hero_by_actor_id: Callable) -> bool:
	var event_type: String = str(event.get("type", ""))
	match event_type:
		"npc_message":
			return _handle_npc_message(event, message_log)
		"shop_open", "shop_refresh":
			return _handle_shop_event(event_type, event, hud, event_bus, find_hero_by_actor_id)
		"quest_reward_open":
			return _handle_quest_reward_event(event, event_bus, find_hero_by_actor_id)
		"item_select_open":
			return _handle_item_select_event(event, event_bus, find_hero_by_actor_id)
		"augment_select_open":
			return _handle_augment_select_event(event, event_bus, find_hero_by_actor_id)
		"transmute_open":
			return _handle_transmute_event(event, event_bus, find_hero_by_actor_id)
		"alchemy_open":
			return _handle_alchemy_event(event, event_bus, find_hero_by_actor_id)
		"reforge_open":
			return _handle_reforge_event(event, event_bus, find_hero_by_actor_id)
		_:
			return false

static func handle_world_event(event: Dictionary, context: Dictionary) -> bool:
	var event_type: String = str(event.get("type", ""))
	match event_type:
		"pickup":
			return handle_pickup_world_event(
				event,
				context.get("suppressed_snapshot_pickups", {}),
				context.get("item_sprites", {}),
				context.get("effect_manager"),
				context.get("message_log"),
				context.get("audio_manager"),
				context.get("suppress_snapshot_feedback", Callable()),
				context.get("remove_local_heap_at_pos", Callable())
			)
		"hero_moved":
			return apply_remote_hero_move(
				int(event.get("actor_id", -1)),
				int(event.get("pos", -1)),
				context.get("hero_sprites", {}),
				context.get("current_level"),
				context.get("fog_of_war"),
				context.get("tile_map"),
				context.get("game_camera"),
				context.get("hud"),
				context.get("audio_manager"),
				context.get("get_focused_hero", Callable()),
				context.get("refresh_client_visibility_preview", Callable())
			)
		"mob_moved":
			return apply_remote_mob_move(
				int(event.get("actor_id", -1)),
				int(event.get("pos", -1)),
				context.get("mob_sprites", {}),
				context.get("current_level")
			)
		"door_opened":
			return handle_door_opened_world_event(
				event,
				context.get("current_level"),
				context.get("effect_manager"),
				context.get("suppressed_snapshot_doors", {}),
				context.get("suppress_snapshot_feedback", Callable()),
				context.get("on_door_opened", Callable())
			)
		"item_dropped":
			return handle_item_dropped_world_event(
				event,
				context.get("current_level"),
				context.get("entity_layer"),
				context.get("item_sprites", {}),
				context.get("effect_manager"),
				context.get("message_log"),
				context.get("remove_local_heap_at_pos", Callable())
			)
		"seed_planted":
			return handle_seed_planted_world_event(event, context.get("current_level"), context.get("on_seed_planted", Callable()))
		"plant_activated":
			return handle_plant_activated_world_event(event, context.get("current_level"), context.get("on_plant_activated_vfx", Callable()))
		"status_effect":
			return handle_status_effect_world_event(event, context.get("effect_manager"))
		"hero_attack_missed":
			return handle_hero_attack_missed_world_event(event, context.get("effect_manager"), context.get("audio_manager"))
		"mob_revealed":
			return handle_mob_revealed_world_event(
				event,
				context.get("current_level"),
				context.get("effect_manager"),
				context.get("message_log"),
				context.get("spawn_single_mob_sprite", Callable())
			)
		"mob_defeated":
			return handle_mob_defeated_world_event(event, context.get("effect_manager"), context.get("audio_manager"))
		"trap_triggered":
			return handle_trap_triggered_world_event(
				event,
				context.get("current_level"),
				context.get("fog_of_war"),
				context.get("tile_map"),
				context.get("effect_manager"),
				context.get("message_log"),
				context.get("audio_manager"),
				context.get("get_focused_hero", Callable()),
				context.get("update_entity_visibility", Callable())
			)
		_:
			return false

static func send_ui_event_to_hero(network_manager: Variant, hero_node: Variant, payload: Dictionary) -> bool:
	if network_manager == null or hero_node == null or not network_manager.has_method("send_ui_event_to_peer"):
		return false
	var owner_peer_id: int = int(ConstantsData.get_prop(hero_node, "owner_peer_id", 1))
	network_manager.send_ui_event_to_peer(owner_peer_id, payload)
	return true

static func send_remote_hero_message(network_manager: Variant, hero_node: Variant, text: String, kind: String) -> bool:
	var trimmed_text: String = text.strip_edges()
	if trimmed_text.is_empty() or network_manager == null or hero_node == null:
		return false
	var owner_peer_id: int = int(ConstantsData.get_prop(hero_node, "owner_peer_id", 1))
	var local_peer_id: int = network_manager.get_local_peer_id() if network_manager.has_method("get_local_peer_id") else 1
	if owner_peer_id == local_peer_id or not network_manager.has_method("send_ui_event_to_peer"):
		return false
	network_manager.send_ui_event_to_peer(owner_peer_id, {
		"type": "npc_message",
		"text": trimmed_text,
		"message_kind": kind,
	})
	return true

static func send_shop_refresh(network_manager: Variant, hero_node: Variant, shopkeeper_actor_id: int, shopkeeper_node: Variant) -> bool:
	if network_manager == null or hero_node == null or not network_manager.has_method("send_ui_event_to_peer"):
		return false
	return send_ui_event_to_hero(network_manager, hero_node, {
		"type": "shop_refresh",
		"hero_actor_id": int(ConstantsData.get_prop(hero_node, "actor_id", -1)),
		"shopkeeper_actor_id": shopkeeper_actor_id,
		"shop_items": serialize_shop_items(shopkeeper_node),
	})

static func send_augment_select_open(network_manager: Variant, hero_node: Variant, item_node: Variant, action_type: String) -> bool:
	if network_manager == null or hero_node == null or item_node == null or not network_manager.has_method("send_ui_event_to_peer") or not item_node.has_method("serialize"):
		return false
	return send_ui_event_to_hero(network_manager, hero_node, {
		"type": "augment_select_open",
		"hero_actor_id": int(ConstantsData.get_prop(hero_node, "actor_id", -1)),
		"action_type": action_type,
		"item": item_node.serialize(),
	})

static func emit_world_event(network_manager: Variant, payload: Dictionary) -> bool:
	if network_manager == null or not network_manager.has_method("broadcast_world_event"):
		return false
	network_manager.broadcast_world_event(payload)
	return true

static func request_online_action(network_manager: Variant, slot_index: int, action: Dictionary) -> bool:
	if network_manager == null or not network_manager.has_method("request_online_action"):
		return false
	network_manager.request_online_action(slot_index, action)
	return true

static func broadcast_run_snapshot(network_manager: Variant, snapshot: Dictionary) -> bool:
	if network_manager == null or not network_manager.has_method("broadcast_run_snapshot"):
		return false
	network_manager.broadcast_run_snapshot(snapshot)
	return true

static func broadcast_level_transition(network_manager: Variant, depth: int, transition_type: String) -> bool:
	if network_manager == null or not network_manager.has_method("broadcast_level_transition"):
		return false
	network_manager.broadcast_level_transition({
		"depth": depth,
		"transition_type": transition_type,
	})
	return true

static func broadcast_run_end(network_manager: Variant, victory: bool, payload: Dictionary = {}) -> bool:
	if network_manager == null or not network_manager.has_method("broadcast_run_end"):
		return false
	network_manager.broadcast_run_end(victory, payload)
	return true

static func reject_online_action(network_manager: Variant, peer_id: int, slot_index: int, reason: String) -> bool:
	if network_manager == null or not network_manager.has_method("reject_online_action"):
		return false
	network_manager.reject_online_action(peer_id, slot_index, reason)
	return true

static func validate_online_action_request(network_manager: Variant, input_hero: Variant, slot_index: int) -> String:
	if network_manager == null or not network_manager.has_method("is_host") or not network_manager.is_host():
		return "__not_host__"
	if input_hero == null:
		return "No hero is ready to act yet."
	if int(ConstantsData.get_prop(input_hero, "hero_slot_index", -1)) != slot_index:
		return "It is not that hero's turn."
	if input_hero.get("is_alive") != true:
		return "That hero cannot act right now."
	return ""

static func should_route_online_action(network_manager: Variant, hero_node: Variant) -> Dictionary:
	if network_manager == null or not network_manager.has_method("is_online_session") or not network_manager.is_online_session():
		return {"route": false, "message": ""}
	if hero_node == null:
		return {"route": false, "message": ""}
	var owner_peer_id: int = int(ConstantsData.get_prop(hero_node, "owner_peer_id", 1))
	var local_peer_id: int = network_manager.get_local_peer_id() if network_manager.has_method("get_local_peer_id") else 1
	if owner_peer_id != local_peer_id:
		return {"route": true, "message": "It is not your hero's turn."}
	if network_manager.has_method("is_host") and network_manager.is_host():
		return {"route": false, "message": ""}
	return {"route": true, "message": "Action sent to host."}

static func is_local_hero(network_manager: Variant, hero_node: Variant) -> bool:
	if network_manager == null or hero_node == null:
		return false
	var local_peer_id: int = network_manager.get_local_peer_id() if network_manager.has_method("get_local_peer_id") else 1
	return int(ConstantsData.get_prop(hero_node, "owner_peer_id", 1)) == local_peer_id

static func choose_local_spectate_hero(network_manager: Variant, living_heroes: Array[Node]) -> Variant:
	if network_manager == null or not network_manager.has_method("is_online_session") or not network_manager.is_online_session():
		return null
	for hero_node: Node in living_heroes:
		if is_local_hero(network_manager, hero_node):
			return hero_node
	return null

static func build_pickup_world_event_payload(pos: int, item_name: String, hero_name: String, hero_slot_index: int = -1) -> Dictionary:
	var payload: Dictionary = {
		"type": "pickup",
		"pos": pos,
		"item_name": item_name,
		"hero_name": hero_name,
	}
	if hero_slot_index >= 0:
		payload["hero_slot_index"] = hero_slot_index
	return payload

static func build_move_world_event_payload(event_type: String, actor_node: Variant, pos: int) -> Dictionary:
	return {
		"type": event_type,
		"actor_id": int(ConstantsData.get_prop(actor_node, "actor_id", -1)),
		"pos": pos,
	}

static func build_item_dropped_world_event_payload(pos: int, item_node: Variant, hero_node: Variant) -> Dictionary:
	return {
		"type": "item_dropped",
		"pos": pos,
		"item_name": str(ConstantsData.get_prop(item_node, "item_name", "item")),
		"hero_name": str(ConstantsData.get_prop(hero_node, "hero_name", "Hero")),
		"item_data": item_node.serialize() if item_node != null and item_node.has_method("serialize") else {},
	}

static func build_status_effect_world_event_payload(pos: int, effect_id: String) -> Dictionary:
	return {
		"type": "status_effect",
		"pos": pos,
		"effect_id": effect_id,
	}

static func build_mob_revealed_world_event_payload(mob: Variant) -> Dictionary:
	return {
		"type": "mob_revealed",
		"actor_id": int(ConstantsData.get_prop(mob, "actor_id", -1)),
		"pos": int(ConstantsData.get_prop(mob, "pos", -1)),
		"mob_name": str(ConstantsData.get_prop(mob, "mob_name", "Mob")),
	}

static func build_mob_defeated_world_event_payload(pos: int, mob_name: String, mob_id: String) -> Dictionary:
	return {
		"type": "mob_defeated",
		"pos": pos,
		"mob_name": mob_name,
		"mob_id": mob_id,
	}

static func _handle_npc_message(event: Dictionary, message_log: Variant) -> bool:
	var message_text: String = str(event.get("text", "")).strip_edges()
	var message_kind: String = str(event.get("message_kind", "info"))
	if message_text.is_empty() or message_log == null:
		return true
	match message_kind:
		"positive":
			message_log.add_positive(message_text)
		"warning":
			message_log.add_warning(message_text)
		"negative":
			message_log.add_negative(message_text)
		_:
			message_log.add_info(message_text)
	return true

static func _handle_shop_event(event_type: String, event: Dictionary, hud: Variant, event_bus: Variant, find_hero_by_actor_id: Callable) -> bool:
	var hero_node: Variant = find_hero_by_actor_id.call(int(event.get("hero_actor_id", -1)))
	if hero_node == null:
		return true
	var shopkeeper_actor_id: int = int(event.get("shopkeeper_actor_id", -1))
	var items: Array[Dictionary] = deserialize_shop_items(event.get("shop_items", []))
	var active_window: Variant = hud.get("_active_window") if hud != null else null
	if event_type == "shop_refresh" and active_window != null and is_instance_valid(active_window) and active_window.has_method("refresh_shop"):
		if int(ConstantsData.get_prop(active_window, "_shopkeeper_actor_id", -1)) == shopkeeper_actor_id:
			active_window.refresh_shop(items)
			return true
	if event_type == "shop_refresh":
		return true
	var wnd: Variant = load("res://src/ui/windows/wnd_shop.gd").new()
	if wnd != null and wnd.has_method("setup"):
		wnd.setup(items, hero_node, null, shopkeeper_actor_id)
		_emit_window(event_bus, wnd)
	return true

static func _handle_quest_reward_event(event: Dictionary, event_bus: Variant, find_hero_by_actor_id: Callable) -> bool:
	var reward_hero: Variant = find_hero_by_actor_id.call(int(event.get("hero_actor_id", -1)))
	if reward_hero == null:
		return true
	var reward_wnd: Variant = load("res://src/ui/windows/wnd_quest_reward.gd").new()
	if reward_wnd != null and reward_wnd.has_method("setup"):
		reward_wnd.setup(
			str(event.get("quest_name", "Reward")),
			str(event.get("quest_description", "")),
			deserialize_item_list(event.get("reward_items", [])),
			reward_hero,
			int(event.get("npc_actor_id", -1))
		)
		_emit_window(event_bus, reward_wnd)
	return true

static func _handle_item_select_event(event: Dictionary, event_bus: Variant, find_hero_by_actor_id: Callable) -> bool:
	var select_hero: Variant = find_hero_by_actor_id.call(int(event.get("hero_actor_id", -1)))
	if select_hero == null:
		return true
	var select_wnd: Variant = load("res://src/ui/windows/wnd_item_select.gd").new()
	if select_wnd != null and select_wnd.has_method("setup_online"):
		select_wnd.setup_online(deserialize_item_list(event.get("items", [])), str(event.get("prompt", "Select an item:")), str(event.get("action_type", "")))
		_emit_window(event_bus, select_wnd)
	return true

static func _handle_augment_select_event(event: Dictionary, event_bus: Variant, find_hero_by_actor_id: Callable) -> bool:
	var augment_hero: Variant = find_hero_by_actor_id.call(int(event.get("hero_actor_id", -1)))
	if augment_hero == null:
		return true
	var augment_item_node: Variant = deserialize_item(event.get("item", {}))
	if augment_item_node == null:
		return true
	var augment_wnd: Variant = load("res://src/ui/windows/wnd_augment_select.gd").new()
	if augment_wnd != null and augment_wnd.has_method("setup_online"):
		augment_wnd.setup_online(augment_item_node, str(event.get("action_type", "")))
		_emit_window(event_bus, augment_wnd)
	return true

static func _handle_transmute_event(event: Dictionary, event_bus: Variant, find_hero_by_actor_id: Callable) -> bool:
	var transmute_hero: Variant = find_hero_by_actor_id.call(int(event.get("hero_actor_id", -1)))
	if transmute_hero == null:
		return true
	var scroll_item_id: String = str(event.get("scroll_item_id", "transmutation"))
	var transmute_scroll: Variant = null
	var transmute_belongings: Variant = transmute_hero.get("belongings")
	if transmute_belongings != null and transmute_belongings.has_method("find_item"):
		transmute_scroll = transmute_belongings.find_item(scroll_item_id)
	if transmute_scroll == null:
		return true
	var transmute_wnd: Variant = load("res://src/ui/windows/wnd_transmute.gd").new()
	if transmute_wnd != null and transmute_wnd.has_method("setup"):
		transmute_wnd.setup(transmute_scroll, transmute_hero)
		_emit_window(event_bus, transmute_wnd)
	return true

static func _handle_alchemy_event(event: Dictionary, event_bus: Variant, find_hero_by_actor_id: Callable) -> bool:
	var alchemy_hero: Variant = find_hero_by_actor_id.call(int(event.get("hero_actor_id", -1)))
	if alchemy_hero == null:
		return true
	var alchemy_wnd: Variant = load("res://src/ui/windows/wnd_alchemy.gd").new()
	if alchemy_wnd != null:
		_emit_window(event_bus, alchemy_wnd)
	return true

static func _handle_reforge_event(event: Dictionary, event_bus: Variant, find_hero_by_actor_id: Callable) -> bool:
	var reforge_hero: Variant = find_hero_by_actor_id.call(int(event.get("hero_actor_id", -1)))
	if reforge_hero == null:
		return true
	var reforge_wnd: Variant = load("res://src/ui/windows/wnd_reforge.gd").new()
	if reforge_wnd != null and reforge_wnd.has_method("setup"):
		reforge_wnd.setup(reforge_hero, null, int(event.get("npc_actor_id", -1)))
		_emit_window(event_bus, reforge_wnd)
	return true

static func _emit_window(event_bus: Variant, wnd: Variant) -> void:
	if wnd == null or event_bus == null or not event_bus.has_signal("show_window"):
		return
	event_bus.show_window.emit(wnd)

static func apply_remote_hero_move(actor_id: int, new_pos: int, hero_sprites: Dictionary, current_level: Variant, fog_of_war: Variant, tile_map: Variant, game_camera: Variant, hud: Variant, audio_manager: Variant, get_focused_hero: Callable, refresh_client_visibility_preview: Callable) -> bool:
	if actor_id < 0 or new_pos < 0:
		return false
	var hero_sprite: Variant = hero_sprites.get(actor_id)
	if hero_sprite != null and is_instance_valid(hero_sprite):
		hero_sprite.move_to(new_pos, 0.12)
	var focused_hero: Variant = get_focused_hero.call()
	if focused_hero == null or int(ConstantsData.get_prop(focused_hero, "actor_id", -1)) != actor_id:
		return true
	if current_level != null and current_level.has_method("update_fov"):
		var view_distance: int = focused_hero.get_view_distance() if focused_hero.has_method("get_view_distance") else ConstantsData.VIEW_DISTANCE
		current_level.update_fov(new_pos, view_distance)
	if fog_of_war:
		fog_of_war.update_visibility()
	if tile_map:
		tile_map.update_tile_visibility()
		if game_camera:
			game_camera.set_target(tile_map.cell_to_world(new_pos), true)
	refresh_client_visibility_preview.call()
	if hud and hud.has_method("update_all"):
		hud.update_all()
	if audio_manager:
		audio_manager.play_sfx("step")
	return true

static func apply_remote_mob_move(actor_id: int, new_pos: int, mob_sprites: Dictionary, current_level: Variant) -> bool:
	if actor_id < 0 or new_pos < 0:
		return false
	var mob_sprite: Variant = mob_sprites.get(actor_id)
	if mob_sprite == null or not is_instance_valid(mob_sprite):
		return false
	mob_sprite.move_to(new_pos, 0.12)
	if mob_sprite.has_method("set_visible_state") and current_level != null and new_pos < current_level.visible.size():
		mob_sprite.set_visible_state(current_level.visible[new_pos])
	return true

static func handle_pickup_world_event(event: Dictionary, suppressed_snapshot_pickups: Dictionary, item_sprites: Dictionary, effect_manager: Variant, message_log: Variant, audio_manager: Variant, suppress_snapshot_feedback: Callable, remove_local_heap_at_pos: Callable) -> bool:
	var pickup_pos: int = int(event.get("pos", -1))
	var item_name: String = str(event.get("item_name", "item"))
	var actor_name: String = str(event.get("hero_name", "Hero"))
	if pickup_pos >= 0:
		suppress_snapshot_feedback.call(suppressed_snapshot_pickups, pickup_pos)
		remove_local_heap_at_pos.call(pickup_pos)
		var item_sprite: Variant = item_sprites.get(pickup_pos)
		if item_sprite != null and is_instance_valid(item_sprite):
			item_sprite.play_pickup(0.18)
			item_sprites.erase(pickup_pos)
		if effect_manager != null:
			effect_manager.show_status(pickup_pos, "Pickup", Color(1.0, 0.9, 0.45))
	if message_log:
		message_log.add("%s picks up %s." % [actor_name, item_name])
	if audio_manager:
		audio_manager.play_sfx("item_pickup")
	return true

static func handle_door_opened_world_event(event: Dictionary, current_level: Variant, effect_manager: Variant, suppressed_snapshot_doors: Dictionary, suppress_snapshot_feedback: Callable, on_door_opened: Callable) -> bool:
	var door_pos: int = int(event.get("pos", -1))
	if door_pos < 0:
		return true
	suppress_snapshot_feedback.call(suppressed_snapshot_doors, door_pos)
	if current_level != null and current_level.has_method("set_terrain"):
		current_level.set_terrain(door_pos, ConstantsData.Terrain.OPEN_DOOR)
	on_door_opened.call(door_pos)
	if effect_manager != null:
		effect_manager.show_status(door_pos, "Open", Color(0.82, 0.72, 0.5))
	return true

static func handle_item_dropped_world_event(event: Dictionary, current_level: Variant, entity_layer: Variant, item_sprites: Dictionary, effect_manager: Variant, message_log: Variant, remove_local_heap_at_pos: Callable) -> bool:
	var drop_pos: int = int(event.get("pos", -1))
	var drop_item_name: String = str(event.get("item_name", "item"))
	var drop_actor_name: String = str(event.get("hero_name", "Hero"))
	var drop_item_data: Variant = event.get("item_data", {})
	if drop_pos >= 0:
		var dropped_item: Variant = drop_item_data if not (drop_item_data is Dictionary) else deserialize_item(drop_item_data)
		if dropped_item != null and current_level != null:
			remove_local_heap_at_pos.call(drop_pos)
			current_level.drop_item(drop_pos, dropped_item)
			var existing_sprite: Variant = item_sprites.get(drop_pos)
			if existing_sprite != null and is_instance_valid(existing_sprite):
				existing_sprite.queue_free()
				item_sprites.erase(drop_pos)
			var drop_sprite: Variant = load("res://src/sprites/item_sprite.gd").new()
			if dropped_item is Object:
				drop_sprite.setup_from_item(dropped_item)
			else:
				drop_sprite.setup_manual(ConstantsData.ItemCategory.MISC)
			drop_sprite.place_at(drop_pos)
			drop_sprite.play_drop()
			entity_layer.add_child(drop_sprite)
			item_sprites[drop_pos] = drop_sprite
		if effect_manager != null:
			effect_manager.show_status(drop_pos, "Drop", Color(0.85, 0.82, 0.65))
	if message_log:
		message_log.add("%s drops %s." % [drop_actor_name, drop_item_name])
	return true

static func handle_seed_planted_world_event(event: Dictionary, current_level: Variant, on_seed_planted: Callable) -> bool:
	var plant_pos: int = int(event.get("pos", -1))
	var plant_type: String = str(event.get("plant_type", ""))
	var plant_persists: bool = bool(event.get("persists", false))
	if plant_pos >= 0 and current_level != null:
		if plant_persists:
			var planted_plant: Variant = make_plant_from_type(plant_type)
			if planted_plant != null and current_level.get("plants") is Dictionary:
				planted_plant.pos = plant_pos
				current_level.plants[plant_pos] = planted_plant
			if current_level.has_method("set_terrain"):
				current_level.set_terrain(plant_pos, ConstantsData.Terrain.HIGH_GRASS)
		on_seed_planted.call(plant_pos, plant_type)
	return true

static func handle_plant_activated_world_event(event: Dictionary, current_level: Variant, on_plant_activated_vfx: Callable) -> bool:
	var activated_pos: int = int(event.get("pos", -1))
	var activated_plant_name: String = str(event.get("plant_name", ""))
	if activated_pos >= 0 and current_level != null:
		if current_level.get("plants") is Dictionary:
			current_level.plants.erase(activated_pos)
		if current_level.has_method("set_terrain"):
			current_level.set_terrain(activated_pos, ConstantsData.Terrain.GRASS)
		on_plant_activated_vfx.call(activated_pos, activated_plant_name)
	return true

static func handle_mob_revealed_world_event(event: Dictionary, current_level: Variant, effect_manager: Variant, message_log: Variant, spawn_single_mob_sprite: Callable) -> bool:
	var revealed_actor_id: int = int(event.get("actor_id", -1))
	var revealed_pos: int = int(event.get("pos", -1))
	var revealed_name: String = str(event.get("mob_name", "Mob"))
	if current_level != null:
		for mob_node: Variant in current_level.mobs:
			if mob_node == null or not is_instance_valid(mob_node):
				continue
			if int(ConstantsData.get_prop(mob_node, "actor_id", -1)) != revealed_actor_id:
				continue
			spawn_single_mob_sprite.call(mob_node)
			break
	if revealed_pos >= 0 and effect_manager != null:
		effect_manager.show_status(revealed_pos, "Revealed!", Color(1.0, 0.62, 0.28))
	if message_log:
		message_log.add_warning("%s revealed!" % revealed_name)
	return true

static func handle_mob_defeated_world_event(event: Dictionary, effect_manager: Variant, audio_manager: Variant) -> bool:
	var defeat_pos: int = int(event.get("pos", -1))
	if defeat_pos >= 0 and effect_manager != null:
		effect_manager.particle_burst(defeat_pos, Color(0.8, 0.2, 0.1), 6)
	if audio_manager:
		audio_manager.play_sfx("hit")
	return true

static func handle_status_effect_world_event(event: Dictionary, effect_manager: Variant) -> bool:
	var effect_pos: int = int(event.get("pos", -1))
	var effect_id: String = str(event.get("effect_id", "")).to_lower()
	if effect_pos >= 0:
		show_status_effect_feedback(effect_manager, effect_pos, effect_id)
	return true

static func handle_hero_attack_missed_world_event(event: Dictionary, effect_manager: Variant, audio_manager: Variant) -> bool:
	var miss_pos: int = int(event.get("pos", -1))
	if miss_pos >= 0 and effect_manager != null:
		effect_manager.show_status(miss_pos, "0", Color(0.7, 0.7, 0.7))
	if audio_manager:
		audio_manager.play_sfx("miss")
	return true

static func handle_trap_triggered_world_event(event: Dictionary, current_level: Variant, fog_of_war: Variant, tile_map: Variant, effect_manager: Variant, message_log: Variant, audio_manager: Variant, get_focused_hero: Callable, update_entity_visibility: Callable) -> bool:
	var trap_pos: int = int(event.get("pos", -1))
	var trap_name: String = str(event.get("trap_name", "Trap"))
	if audio_manager:
		audio_manager.play_sfx("trap")
	if current_level != null:
		if tile_map:
			tile_map.level = current_level
			tile_map.render_changed()
		var focused_hero: Variant = get_focused_hero.call()
		if focused_hero and current_level.has_method("update_fov"):
			var view_distance: int = focused_hero.get_view_distance() if focused_hero.has_method("get_view_distance") else ConstantsData.VIEW_DISTANCE
			current_level.update_fov(focused_hero.pos, view_distance)
		if fog_of_war:
			fog_of_war.update_visibility()
		update_entity_visibility.call()
	if trap_pos >= 0 and effect_manager != null:
		effect_manager.show_status(trap_pos, "Trap!", Color(1.0, 0.55, 0.25))
	if message_log and not trap_name.is_empty():
		message_log.add_warning("%s triggered!" % trap_name.capitalize())
	return true
