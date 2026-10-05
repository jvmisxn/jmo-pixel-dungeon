extends RefCounted
## Save safety guards: incomplete saves are rejected before the running game
## is wiped, online clients never write the shared save slot, and save files
## are read without object decoding.

const TEST_PATH: String = "user://test_save_safety_objects.dat"

func run(t: Object) -> void:
	_test_missing_sections(t)
	_test_client_does_not_save(t)
	_test_object_payload_not_decoded(t)


func _test_missing_sections(t: Object) -> void:
	var complete: Dictionary = {
		"game_manager": {"depth": 1},
		"current_level": {"depth": 1},
		"heroes": [{"hp": 10}],
	}
	t.check(SaveManagerNode.missing_save_sections(complete).is_empty(),
		"complete save has no missing sections")

	var legacy_single_hero: Dictionary = {
		"game_manager": {"depth": 1},
		"current_level": {"depth": 1},
		"hero": {"hp": 10},
	}
	t.check(SaveManagerNode.missing_save_sections(legacy_single_hero).is_empty(),
		"legacy single-hero save is accepted")

	t.check("everything" in SaveManagerNode.missing_save_sections({}),
		"empty save reports everything missing")

	var no_level: Dictionary = {"game_manager": {"depth": 1}, "heroes": [{"hp": 10}]}
	t.check("current_level" in SaveManagerNode.missing_save_sections(no_level),
		"save without a current level is rejected")

	var no_hero: Dictionary = {
		"game_manager": {"depth": 1},
		"current_level": {"depth": 1},
		"heroes": [],
		"hero": {},
	}
	t.check("hero" in SaveManagerNode.missing_save_sections(no_hero),
		"save without any hero is rejected")


func _test_client_does_not_save(t: Object) -> void:
	var previous_mode: int = NetworkManager.session_mode
	NetworkManager.session_mode = NetworkManager.SessionMode.CLIENT
	t.check(SaveManager.is_client_mirror(), "client session is detected as a mirror")
	t.check(not SaveManager.save_full_game(),
		"online client refuses to write the single-player save slot")
	NetworkManager.session_mode = NetworkManager.SessionMode.OFFLINE
	t.check(not SaveManager.is_client_mirror(), "offline session is not a mirror")
	NetworkManager.session_mode = previous_mode


func _test_object_payload_not_decoded(t: Object) -> void:
	# A file written with full objects must not come back as a live Object.
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if file == null:
		t.check(false, "could not open temp file for object payload test")
		return
	var payload: RefCounted = RefCounted.new()
	file.store_var({"payload": payload}, true)
	file.close()

	var data: Dictionary = SaveManager._read_save_dictionary(TEST_PATH)
	var decoded: Variant = data.get("payload") if not data.is_empty() else null
	t.check(not (decoded is Object and is_instance_valid(decoded)),
		"save reader does not decode embedded objects")
	DirAccess.remove_absolute(TEST_PATH)
