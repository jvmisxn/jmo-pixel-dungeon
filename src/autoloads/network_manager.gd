class_name NetworkManagerNode
extends Node
## Lightweight session/network bootstrap for future co-op.
## Owns ENet host/join lifecycle and exposes session state to UI/game code.

signal session_state_changed
signal hosting_started(port: int, max_players: int)
signal join_started(address: String, port: int)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal connected_to_host
signal join_failed(reason: String)
signal disconnected(reason: String)
signal lobby_updated
signal lobby_start_requested
signal online_run_start_requested(config: Dictionary)
signal online_action_requested(peer_id: int, slot_index: int, action: Dictionary)
signal online_action_rejected(slot_index: int, reason: String)
signal run_snapshot_received(snapshot: Dictionary)
signal online_world_event_received(event: Dictionary)
signal online_ui_event_received(event: Dictionary)
signal online_level_transition_requested(config: Dictionary)
signal online_run_ended(victory: bool, payload: Dictionary)

enum SessionMode {
	OFFLINE,
	HOST,
	CLIENT,
}

const DEFAULT_PORT: int = 41234
const DEFAULT_MAX_PLAYERS: int = 4
const PREFS_PATH: String = "user://network_prefs.cfg"

var session_mode: int = SessionMode.OFFLINE
var listen_port: int = DEFAULT_PORT
var remote_address: String = ""
var max_players: int = DEFAULT_MAX_PLAYERS
var last_error: String = ""
var local_player_name: String = "Player"
var lobby_players: Array[Dictionary] = []
var last_join_code: String = ""
var active_run_config: Dictionary = {}
var latest_run_snapshot: Dictionary = {}
var run_in_progress: bool = false
var local_lobby_class: int = ConstantsData.HeroClass.WARRIOR
var local_profile_icon_id: String = "warrior"

func _ready() -> void:
	_load_prefs()
	if PlayerProfile != null and PlayerProfile.has_method("has_player_name") and PlayerProfile.has_player_name():
		local_player_name = PlayerProfile.get_player_name()
	if PlayerProfile != null and PlayerProfile.has_method("get_selected_icon_id"):
		local_profile_icon_id = PlayerProfile.get_selected_icon_id()
	if multiplayer != null:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int = DEFAULT_PORT, player_cap: int = DEFAULT_MAX_PLAYERS) -> bool:
	close_session("Restarting session")
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var clamped_cap: int = clampi(player_cap, 1, GameManager.MAX_PARTY_SIZE if GameManager != null else DEFAULT_MAX_PLAYERS)
	var err: int = peer.create_server(port, clamped_cap)
	if err != OK:
		last_error = "Failed to host on port %d (error %d)." % [port, err]
		_emit_join_failed(last_error)
		return false
	multiplayer.multiplayer_peer = peer
	session_mode = SessionMode.HOST
	listen_port = port
	max_players = clamped_cap
	remote_address = ""
	last_error = ""
	_save_prefs()
	_reset_lobby_state()
	_upsert_lobby_player(multiplayer.get_unique_id(), _get_effective_local_player_name(), false, local_lobby_class, local_profile_icon_id)
	last_join_code = "%s:%d" % [get_preferred_bind_address(), port]
	_broadcast_lobby_snapshot()
	session_state_changed.emit()
	hosting_started.emit(port, clamped_cap)
	return true

func join_game(address: String, port: int = DEFAULT_PORT) -> bool:
	close_session("Restarting session")
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var trimmed_address: String = address.strip_edges()
	if trimmed_address.is_empty():
		last_error = "Host address is required."
		_emit_join_failed(last_error)
		return false
	var err: int = peer.create_client(trimmed_address, port)
	if err != OK:
		last_error = "Failed to connect to %s:%d (error %d)." % [trimmed_address, port, err]
		_emit_join_failed(last_error)
		return false
	multiplayer.multiplayer_peer = peer
	session_mode = SessionMode.CLIENT
	listen_port = port
	remote_address = trimmed_address
	last_error = ""
	last_join_code = "%s:%d" % [trimmed_address, port]
	_save_prefs()
	_reset_lobby_state()
	session_state_changed.emit()
	join_started.emit(trimmed_address, port)
	return true

func close_session(reason: String = "Session closed") -> void:
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	var had_session: bool = session_mode != SessionMode.OFFLINE
	session_mode = SessionMode.OFFLINE
	remote_address = ""
	last_error = ""
	active_run_config.clear()
	latest_run_snapshot.clear()
	run_in_progress = false
	_reset_lobby_state()
	if had_session:
		session_state_changed.emit()
		disconnected.emit(reason)

func is_online_session() -> bool:
	return session_mode != SessionMode.OFFLINE

func is_host() -> bool:
	return session_mode == SessionMode.HOST

func is_client() -> bool:
	return session_mode == SessionMode.CLIENT

func has_active_run() -> bool:
	return run_in_progress and not active_run_config.is_empty()

func get_session_phase_label() -> String:
	if not is_online_session():
		return "Offline"
	if has_active_run():
		return "Run in progress"
	return "Lobby open"

func get_connection_label() -> String:
	match session_mode:
		SessionMode.HOST:
			return "Hosting on port %d" % listen_port
		SessionMode.CLIENT:
			return "Joining %s:%d" % [remote_address, listen_port]
		_:
			return "Offline"

func _emit_join_failed(reason: String) -> void:
	session_mode = SessionMode.OFFLINE
	if multiplayer != null:
		multiplayer.multiplayer_peer = null
	_reset_lobby_state()
	session_state_changed.emit()
	join_failed.emit(reason)

func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if is_host():
		_remove_lobby_player(peer_id)
		_broadcast_lobby_snapshot()
	peer_left.emit(peer_id)

func _on_connected_to_server() -> void:
	last_error = ""
	rpc_id(1, "_server_register_player", _get_effective_local_player_name(), local_lobby_class, local_profile_icon_id)
	session_state_changed.emit()
	connected_to_host.emit()

func _on_connection_failed() -> void:
	_emit_join_failed("Connection failed.")

func _on_server_disconnected() -> void:
	close_session("Disconnected from host.")

func set_local_player_name(player_name: String) -> void:
	local_player_name = player_name.strip_edges()
	if local_player_name.is_empty():
		local_player_name = "Player"
	if PlayerProfile != null and PlayerProfile.has_method("get_player_name"):
		var profile_name: String = PlayerProfile.get_player_name()
		if profile_name != local_player_name:
			PlayerProfile.set_player_name(local_player_name)
	_save_prefs()
	if is_host():
		_upsert_lobby_player(multiplayer.get_unique_id(), _get_effective_local_player_name(), _is_local_player_ready(), local_lobby_class, local_profile_icon_id)
		_broadcast_lobby_snapshot()

func get_preferred_bind_address() -> String:
	var addresses: PackedStringArray = IP.get_local_addresses()
	for address: String in addresses:
		if "." in address and not address.begins_with("127.") and not address.begins_with("169.254."):
			return address
	for address: String in addresses:
		if "." in address:
			return address
	return "127.0.0.1"

func build_join_code() -> String:
	var host_address: String = get_preferred_bind_address() if is_host() else remote_address
	if host_address.strip_edges().is_empty():
		host_address = "127.0.0.1"
	return "%s:%d" % [host_address, listen_port]

func parse_join_code(code: String) -> Dictionary:
	var trimmed: String = code.strip_edges()
	if trimmed.is_empty():
		return {}
	var address: String = trimmed
	var port: int = DEFAULT_PORT
	if trimmed.contains(":"):
		var split_index: int = trimmed.rfind(":")
		address = trimmed.substr(0, split_index).strip_edges()
		var port_text: String = trimmed.substr(split_index + 1).strip_edges()
		if not port_text.is_empty():
			port = int(port_text)
	if address.is_empty():
		return {}
	return {"address": address, "port": port}

func get_lobby_players() -> Array[Dictionary]:
	return lobby_players.duplicate(true)

func get_local_peer_id() -> int:
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1

func get_local_slot_index() -> int:
	var local_id: int = get_local_peer_id()
	for idx: int in range(lobby_players.size()):
		if int(lobby_players[idx].get("peer_id", -1)) == local_id:
			return idx
	return 0

func get_slot_owner_peer_id(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= lobby_players.size():
		return 1
	return int(lobby_players[slot_index].get("peer_id", 1))

func get_lobby_player_name(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= lobby_players.size():
		return "Player %d" % (slot_index + 1)
	return str(lobby_players[slot_index].get("name", "Player %d" % (slot_index + 1)))

func get_lobby_player_class(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= lobby_players.size():
		return ConstantsData.HeroClass.WARRIOR
	return int(lobby_players[slot_index].get("chosen_class", ConstantsData.HeroClass.WARRIOR))

func get_lobby_player_icon(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= lobby_players.size():
		return "warrior"
	return str(lobby_players[slot_index].get("profile_icon_id", "warrior"))

func get_local_lobby_class() -> int:
	return local_lobby_class

func get_local_profile_icon_id() -> String:
	return local_profile_icon_id

func get_ready_player_count() -> int:
	var ready_count: int = 0
	for player_entry: Dictionary in lobby_players:
		if bool(player_entry.get("ready", false)):
			ready_count += 1
	return ready_count

func get_required_ready_count() -> int:
	return lobby_players.size()

func get_ready_summary() -> String:
	var required_count: int = get_required_ready_count()
	if required_count <= 0:
		return "Ready 0/0"
	return "Ready %d/%d" % [get_ready_player_count(), required_count]

func can_control_slot(slot_index: int) -> bool:
	return get_slot_owner_peer_id(slot_index) == get_local_peer_id()

func set_local_lobby_class(class_id: int) -> void:
	local_lobby_class = clampi(class_id, 0, ConstantsData.HeroClass.DUELIST)
	_save_prefs()
	if not is_online_session():
		return
	if is_host():
		_upsert_lobby_player(multiplayer.get_unique_id(), _get_effective_local_player_name(), _is_local_player_ready(), local_lobby_class, local_profile_icon_id)
		_broadcast_lobby_snapshot()
	elif is_client():
		rpc_id(1, "_server_set_lobby_class", local_lobby_class)

func set_local_profile_icon_id(icon_id: String) -> void:
	local_profile_icon_id = icon_id.strip_edges()
	if local_profile_icon_id.is_empty():
		local_profile_icon_id = "warrior"
	_save_prefs()
	if not is_online_session():
		return
	if is_host():
		_upsert_lobby_player(multiplayer.get_unique_id(), _get_effective_local_player_name(), _is_local_player_ready(), local_lobby_class, local_profile_icon_id)
		_broadcast_lobby_snapshot()
	elif is_client():
		rpc_id(1, "_server_set_profile_icon", local_profile_icon_id)

func set_local_ready(ready: bool) -> void:
	if not is_online_session():
		return
	if is_host():
		_upsert_lobby_player(multiplayer.get_unique_id(), _get_effective_local_player_name(), ready, local_lobby_class, local_profile_icon_id)
		_broadcast_lobby_snapshot()
	elif is_client():
		rpc_id(1, "_server_set_ready", ready)

func is_local_ready() -> bool:
	return _is_local_player_ready()

func can_host_start_run() -> bool:
	if not is_host() or lobby_players.is_empty():
		return false
	for player_entry: Dictionary in lobby_players:
		if not bool(player_entry.get("ready", false)):
			return false
	return true

func request_lobby_start() -> bool:
	if not can_host_start_run():
		return false
	_emit_lobby_start()
	rpc("_client_lobby_started")
	return true

func start_online_run(config: Dictionary) -> bool:
	if not is_host():
		return false
	var sanitized_config: Dictionary = _sanitize_run_config(config)
	active_run_config = sanitized_config.duplicate(true)
	latest_run_snapshot.clear()
	run_in_progress = true
	_emit_online_run_start(sanitized_config)
	rpc("_client_receive_online_run_start", sanitized_config)
	return true

func request_online_action(slot_index: int, action: Dictionary) -> bool:
	if not is_online_session():
		return false
	if is_host():
		_emit_online_action_requested(get_local_peer_id(), slot_index, action)
		return true
	rpc_id(1, "_server_receive_online_action", slot_index, action)
	return true

func broadcast_run_snapshot(snapshot: Dictionary) -> void:
	if not is_host():
		return
	latest_run_snapshot = snapshot.duplicate(true)
	rpc("_client_receive_run_snapshot", snapshot)

func broadcast_world_event(event: Dictionary) -> void:
	if not is_host():
		return
	rpc("_client_receive_world_event", event.duplicate(true))

func send_ui_event_to_peer(peer_id: int, event: Dictionary) -> void:
	if not is_host():
		return
	var payload: Dictionary = event.duplicate(true)
	if peer_id == get_local_peer_id():
		_emit_online_ui_event_received(payload)
		return
	rpc_id(peer_id, "_client_receive_ui_event", payload)

func broadcast_level_transition(config: Dictionary) -> void:
	if not is_host():
		return
	var payload: Dictionary = {
		"depth": int(config.get("depth", 1)),
		"transition_type": str(config.get("transition_type", "descend")),
	}
	rpc("_client_receive_level_transition", payload)

func broadcast_run_end(victory: bool, payload: Dictionary = {}) -> void:
	if not is_host():
		return
	run_in_progress = false
	active_run_config.clear()
	latest_run_snapshot.clear()
	var data: Dictionary = payload.duplicate(true)
	data["victory"] = victory
	rpc("_client_receive_run_end", data)

func reject_online_action(peer_id: int, slot_index: int, reason: String) -> void:
	if not is_host():
		return
	var trimmed_reason: String = reason.strip_edges()
	if trimmed_reason.is_empty():
		trimmed_reason = "Action rejected."
	if peer_id == get_local_peer_id():
		_emit_online_action_rejected(slot_index, trimmed_reason)
		return
	rpc_id(peer_id, "_client_receive_action_rejected", slot_index, trimmed_reason)

func _reset_lobby_state() -> void:
	lobby_players.clear()
	lobby_updated.emit()

func _get_effective_local_player_name() -> String:
	var trimmed_name: String = local_player_name.strip_edges()
	if trimmed_name.is_empty():
		trimmed_name = "Player"
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		return "%s %d" % [trimmed_name, multiplayer.get_unique_id()]
	return trimmed_name

func _load_prefs() -> void:
	var prefs: ConfigFile = ConfigFile.new()
	if prefs.load(PREFS_PATH) != OK:
		return
	local_player_name = str(prefs.get_value("network", "player_name", local_player_name)).strip_edges()
	if local_player_name.is_empty():
		local_player_name = "Player"
	last_join_code = str(prefs.get_value("network", "last_join_code", last_join_code)).strip_edges()
	listen_port = int(prefs.get_value("network", "listen_port", listen_port))
	if listen_port <= 0:
		listen_port = DEFAULT_PORT
	max_players = clampi(int(prefs.get_value("network", "max_players", max_players)), 1, GameManager.MAX_PARTY_SIZE if GameManager != null else DEFAULT_MAX_PLAYERS)
	local_lobby_class = clampi(int(prefs.get_value("network", "local_lobby_class", local_lobby_class)), 0, ConstantsData.HeroClass.DUELIST)
	local_profile_icon_id = str(prefs.get_value("network", "local_profile_icon_id", local_profile_icon_id)).strip_edges()
	if local_profile_icon_id.is_empty():
		local_profile_icon_id = "warrior"

func _save_prefs() -> void:
	var prefs: ConfigFile = ConfigFile.new()
	prefs.set_value("network", "player_name", local_player_name)
	prefs.set_value("network", "last_join_code", last_join_code)
	prefs.set_value("network", "listen_port", listen_port)
	prefs.set_value("network", "max_players", max_players)
	prefs.set_value("network", "local_lobby_class", local_lobby_class)
	prefs.set_value("network", "local_profile_icon_id", local_profile_icon_id)
	prefs.save(PREFS_PATH)

func _upsert_lobby_player(peer_id: int, player_name: String, ready: bool, chosen_class: int = ConstantsData.HeroClass.WARRIOR, profile_icon_id: String = "warrior") -> void:
	for idx: int in range(lobby_players.size()):
		if int(lobby_players[idx].get("peer_id", -1)) == peer_id:
			lobby_players[idx]["name"] = player_name
			lobby_players[idx]["ready"] = ready
			lobby_players[idx]["chosen_class"] = chosen_class
			lobby_players[idx]["profile_icon_id"] = profile_icon_id
			lobby_updated.emit()
			return
	lobby_players.append({
		"peer_id": peer_id,
		"name": player_name,
		"ready": ready,
		"chosen_class": chosen_class,
		"profile_icon_id": profile_icon_id,
	})
	lobby_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("peer_id", 0)) < int(b.get("peer_id", 0))
	)
	lobby_updated.emit()

func _rebind_active_run_player(player_name: String, new_peer_id: int) -> void:
	if not run_in_progress or active_run_config.is_empty():
		return
	var player_infos: Variant = active_run_config.get("player_infos", [])
	if not (player_infos is Array):
		return
	for idx: int in range(player_infos.size()):
		var player_info: Variant = player_infos[idx]
		if not (player_info is Dictionary):
			continue
		var info: Dictionary = player_info
		if str(info.get("name", "")).strip_edges() != player_name.strip_edges():
			continue
		var previous_peer_id: int = int(info.get("peer_id", -1))
		info["peer_id"] = new_peer_id
		player_infos[idx] = info
		active_run_config["player_infos"] = player_infos
		for lobby_idx: int in range(lobby_players.size() - 1, -1, -1):
			if int(lobby_players[lobby_idx].get("peer_id", -1)) == previous_peer_id and previous_peer_id != new_peer_id:
				lobby_players.remove_at(lobby_idx)
		if GameManager != null and idx >= 0 and idx < GameManager.heroes.size():
			var hero_node: Variant = GameManager.heroes[idx]
			if hero_node != null and is_instance_valid(hero_node):
				hero_node.set("owner_peer_id", new_peer_id)
				hero_node.set("hero_slot_index", idx)
		var chosen_class: int = int(info.get("chosen_class", ConstantsData.HeroClass.WARRIOR))
		var profile_icon_id: String = str(info.get("profile_icon_id", "warrior"))
		_upsert_lobby_player(new_peer_id, player_name, false, chosen_class, profile_icon_id)
		break

func _remove_lobby_player(peer_id: int) -> void:
	for idx: int in range(lobby_players.size() - 1, -1, -1):
		if int(lobby_players[idx].get("peer_id", -1)) == peer_id:
			lobby_players.remove_at(idx)
	lobby_updated.emit()

func _is_local_player_ready() -> bool:
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return false
	var local_id: int = multiplayer.get_unique_id()
	for player_entry: Dictionary in lobby_players:
		if int(player_entry.get("peer_id", -1)) == local_id:
			return bool(player_entry.get("ready", false))
	return false

func _get_existing_player_class(peer_id: int) -> int:
	for player_entry: Dictionary in lobby_players:
		if int(player_entry.get("peer_id", -1)) == peer_id:
			return int(player_entry.get("chosen_class", ConstantsData.HeroClass.WARRIOR))
	return ConstantsData.HeroClass.WARRIOR

func _get_existing_player_icon(peer_id: int) -> String:
	for player_entry: Dictionary in lobby_players:
		if int(player_entry.get("peer_id", -1)) == peer_id:
			return str(player_entry.get("profile_icon_id", "warrior"))
	return "warrior"

func _broadcast_lobby_snapshot() -> void:
	var snapshot: Array = lobby_players.duplicate(true)
	_client_receive_lobby_snapshot(snapshot)
	if is_host():
		rpc("_client_receive_lobby_snapshot", snapshot)
	session_state_changed.emit()

func _emit_lobby_start() -> void:
	lobby_start_requested.emit()

func _emit_online_run_start(config: Dictionary) -> void:
	online_run_start_requested.emit(config)

func _emit_online_action_requested(peer_id: int, slot_index: int, action: Dictionary) -> void:
	online_action_requested.emit(peer_id, slot_index, action)

func _emit_online_action_rejected(slot_index: int, reason: String) -> void:
	online_action_rejected.emit(slot_index, reason)

func _emit_run_snapshot_received(snapshot: Dictionary) -> void:
	run_snapshot_received.emit(snapshot)

func _emit_online_world_event_received(event: Dictionary) -> void:
	online_world_event_received.emit(event)

func _emit_online_ui_event_received(event: Dictionary) -> void:
	online_ui_event_received.emit(event)

func _emit_online_level_transition_requested(config: Dictionary) -> void:
	online_level_transition_requested.emit(config)

func _emit_online_run_ended(victory: bool, payload: Dictionary) -> void:
	online_run_ended.emit(victory, payload)

func _sanitize_run_config(config: Dictionary) -> Dictionary:
	var run_seed: int = int(config.get("run_seed", randi()))
	var party: Array[int] = []
	var player_infos: Array[Dictionary] = []
	for player_entry: Dictionary in lobby_players:
		player_infos.append(player_entry.duplicate(true))
		party.append(int(player_entry.get("chosen_class", ConstantsData.HeroClass.WARRIOR)))
	var chosen_class: int = int(config.get("chosen_class", ConstantsData.HeroClass.WARRIOR))
	var raw_party: Variant = config.get("party_classes", [chosen_class])
	if party.is_empty() and raw_party is Array:
		for class_value: Variant in raw_party:
			if party.size() >= (GameManager.MAX_PARTY_SIZE if GameManager != null else DEFAULT_MAX_PLAYERS):
				break
			party.append(int(class_value))
	if party.is_empty():
		party.append(chosen_class)
	var required_party_size: int = clampi(player_infos.size(), 1, GameManager.MAX_PARTY_SIZE if GameManager != null else DEFAULT_MAX_PLAYERS)
	while party.size() < required_party_size:
		party.append(chosen_class)
	if party.size() > required_party_size:
		party.resize(required_party_size)
	return {
		"chosen_class": party[0],
		"party_classes": party,
		"player_infos": player_infos,
		"run_seed": run_seed,
		"is_continue": false,
	}

@rpc("any_peer", "reliable")
func _server_register_player(player_name: String, chosen_class: int = ConstantsData.HeroClass.WARRIOR, profile_icon_id: String = "warrior") -> void:
	if not is_host():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var trimmed_name: String = player_name.strip_edges()
	_rebind_active_run_player(trimmed_name, sender_id)
	var applied_class: int = clampi(chosen_class, 0, ConstantsData.HeroClass.DUELIST)
	var applied_icon: String = profile_icon_id
	if run_in_progress:
		applied_class = _get_existing_player_class(sender_id)
		applied_icon = _get_existing_player_icon(sender_id)
	_upsert_lobby_player(sender_id, trimmed_name, false, applied_class, applied_icon)
	_broadcast_lobby_snapshot()
	if run_in_progress and not active_run_config.is_empty():
		rpc_id(sender_id, "_client_receive_online_run_start", active_run_config)
		if not latest_run_snapshot.is_empty():
			rpc_id(sender_id, "_client_receive_run_snapshot", latest_run_snapshot)

@rpc("any_peer", "reliable")
func _server_set_ready(ready: bool) -> void:
	if not is_host():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var player_name: String = "Player %d" % sender_id
	for player_entry: Dictionary in lobby_players:
		if int(player_entry.get("peer_id", -1)) == sender_id:
			player_name = str(player_entry.get("name", player_name))
			break
	_upsert_lobby_player(sender_id, player_name, ready, _get_existing_player_class(sender_id), _get_existing_player_icon(sender_id))
	_broadcast_lobby_snapshot()

@rpc("any_peer", "reliable")
func _server_set_lobby_class(class_id: int) -> void:
	if not is_host():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var player_name: String = "Player %d" % sender_id
	var ready: bool = false
	for player_entry: Dictionary in lobby_players:
		if int(player_entry.get("peer_id", -1)) == sender_id:
			player_name = str(player_entry.get("name", player_name))
			ready = bool(player_entry.get("ready", false))
			break
	_upsert_lobby_player(sender_id, player_name, ready, clampi(class_id, 0, ConstantsData.HeroClass.DUELIST), _get_existing_player_icon(sender_id))
	_broadcast_lobby_snapshot()

@rpc("any_peer", "reliable")
func _server_set_profile_icon(profile_icon_id: String) -> void:
	if not is_host():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var player_name: String = "Player %d" % sender_id
	var ready: bool = false
	for player_entry: Dictionary in lobby_players:
		if int(player_entry.get("peer_id", -1)) == sender_id:
			player_name = str(player_entry.get("name", player_name))
			ready = bool(player_entry.get("ready", false))
			break
	_upsert_lobby_player(sender_id, player_name, ready, _get_existing_player_class(sender_id), profile_icon_id)
	_broadcast_lobby_snapshot()

@rpc("authority", "reliable")
func _client_receive_lobby_snapshot(snapshot: Array) -> void:
	lobby_players.clear()
	for entry: Variant in snapshot:
		if entry is Dictionary:
			lobby_players.append((entry as Dictionary).duplicate(true))
	for player_entry: Dictionary in lobby_players:
		if int(player_entry.get("peer_id", -1)) == get_local_peer_id():
			local_lobby_class = int(player_entry.get("chosen_class", local_lobby_class))
			local_profile_icon_id = str(player_entry.get("profile_icon_id", local_profile_icon_id))
			break
	lobby_updated.emit()
	session_state_changed.emit()

@rpc("authority", "reliable")
func _client_lobby_started() -> void:
	_emit_lobby_start()

@rpc("authority", "reliable")
func _client_receive_online_run_start(config: Dictionary) -> void:
	# The host is authoritative for the run config and has already sanitized it
	# (see start_online_run). Adopt the host payload verbatim rather than calling
	# _sanitize_run_config here — that rebuilds party_classes/player_infos from
	# this client's own lobby_players snapshot, which can diverge from the host's
	# at run start and desync the class-to-slot mapping.
	_emit_online_run_start(config.duplicate(true))

@rpc("authority", "reliable")
func _client_receive_run_snapshot(snapshot: Dictionary) -> void:
	_emit_run_snapshot_received(snapshot.duplicate(true))

@rpc("authority", "reliable")
func _client_receive_world_event(event: Dictionary) -> void:
	_emit_online_world_event_received(event.duplicate(true))

@rpc("authority", "reliable")
func _client_receive_ui_event(event: Dictionary) -> void:
	_emit_online_ui_event_received(event.duplicate(true))

@rpc("authority", "reliable")
func _client_receive_level_transition(config: Dictionary) -> void:
	_emit_online_level_transition_requested(config.duplicate(true))

@rpc("authority", "reliable")
func _client_receive_run_end(payload: Dictionary) -> void:
	var data: Dictionary = payload.duplicate(true)
	var victory: bool = bool(data.get("victory", false))
	data.erase("victory")
	_emit_online_run_ended(victory, data)

@rpc("authority", "reliable")
func _client_receive_action_rejected(slot_index: int, reason: String) -> void:
	_emit_online_action_rejected(slot_index, reason)

@rpc("any_peer", "reliable")
func _server_receive_online_action(slot_index: int, action: Dictionary) -> void:
	if not is_host():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if get_slot_owner_peer_id(slot_index) != sender_id:
		reject_online_action(sender_id, slot_index, "You do not control that hero.")
		return
	_emit_online_action_requested(sender_id, slot_index, action)
