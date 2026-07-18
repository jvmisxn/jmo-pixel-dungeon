extends RefCounted
## Regression tests for host-authoritative online run config delivery.
##
## The client must adopt the host's already-sanitized run config verbatim.
## It must NOT re-sanitize against its own lobby_players snapshot, because
## that rebuilds party_classes/player_infos from local state and can desync
## the class-to-slot mapping between host and clients.

func run(t: Object) -> void:
	var script: Variant = load("res://src/autoloads/network_manager.gd")
	t.check(script != null and script is GDScript, "network_manager.gd compiles")
	if script == null:
		return

	var nm: Object = script.new()

	# Simulate a client whose local lobby snapshot DIVERGES from the host's:
	# different class ordering and stale/incomplete peer data. If the client
	# re-sanitized from this, the emitted mapping would come from here.
	var client_lobby: Array[Dictionary] = [
		{"peer_id": 1, "name": "Host", "chosen_class": ConstantsData.HeroClass.WARRIOR, "profile_icon_id": "warrior"},
		{"peer_id": 2, "name": "Guest", "chosen_class": ConstantsData.HeroClass.WARRIOR, "profile_icon_id": "warrior"},
	]
	nm.lobby_players = client_lobby

	# Host-authoritative config as it arrives over RPC: a specific
	# class-to-slot mapping that differs from the client's local lobby.
	var host_config: Dictionary = {
		"chosen_class": ConstantsData.HeroClass.DUELIST,
		"party_classes": [ConstantsData.HeroClass.DUELIST, ConstantsData.HeroClass.MAGE],
		"player_infos": [
			{"peer_id": 1, "name": "Host", "chosen_class": ConstantsData.HeroClass.DUELIST, "profile_icon_id": "duelist"},
			{"peer_id": 2, "name": "Guest", "chosen_class": ConstantsData.HeroClass.MAGE, "profile_icon_id": "mage"},
		],
		"run_seed": 987654,
		"is_continue": false,
	}

	var captured: Array[Dictionary] = []
	nm.online_run_start_requested.connect(func(config: Dictionary) -> void:
		captured.append(config)
	)

	nm._client_receive_online_run_start(host_config)

	t.check(captured.size() == 1, "client emits online_run_start_requested exactly once")
	if captured.is_empty():
		nm.free()
		return

	var emitted: Dictionary = captured[0]

	# Class-to-slot mapping must match the HOST, not the client's local lobby.
	var emitted_party: Array = emitted.get("party_classes", [])
	t.check(
		emitted_party.size() == 2
			and int(emitted_party[0]) == ConstantsData.HeroClass.DUELIST
			and int(emitted_party[1]) == ConstantsData.HeroClass.MAGE,
		"client adopts host party_classes verbatim (no local re-sanitize desync)"
	)
	t.check(
		int(emitted.get("chosen_class", -1)) == ConstantsData.HeroClass.DUELIST,
		"client adopts host chosen_class"
	)
	t.check(
		int(emitted.get("run_seed", -1)) == 987654,
		"client preserves host run_seed"
	)

	# player_infos must reflect the host mapping (class per peer), not local lobby.
	var emitted_infos: Array = emitted.get("player_infos", [])
	t.check(emitted_infos.size() == 2, "client preserves host player_infos count")
	if emitted_infos.size() == 2:
		t.check(
			int((emitted_infos[1] as Dictionary).get("chosen_class", -1)) == ConstantsData.HeroClass.MAGE,
			"client preserves host per-slot class in player_infos"
		)

	# Emitted config must be a deep copy — mutating it must not corrupt the source.
	emitted_party[0] = ConstantsData.HeroClass.ROGUE
	t.check(
		int((host_config.get("party_classes") as Array)[0]) == ConstantsData.HeroClass.DUELIST,
		"emitted config is an isolated deep copy of the host payload"
	)

	nm.free()
