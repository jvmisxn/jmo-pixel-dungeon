extends RefCounted
## SaveManager durability tests for atomic save promotion, backup rotation, and
## migration scaffolding. These use test-only user:// paths, not the real save.

const TEST_SAVE_PATH: String = "user://test_save_manager_full.dat"
const TEST_TMP_PATH: String = "user://test_save_manager_full.dat.tmp"
const TEST_BAK_PATH: String = "user://test_save_manager_full.dat.bak"

func run(t: Object) -> void:
	_cleanup()
	var script: Variant = load("res://src/autoloads/save_manager.gd")
	t.check(script != null and script is GDScript, "save_manager.gd compiles")
	if script == null:
		return

	var manager: Object = script.new()
	var first_save: Dictionary = {"save_version": 1, "marker": "first"}
	var second_save: Dictionary = {"save_version": 1, "marker": "second"}

	t.check(
		manager._write_atomic_var(TEST_SAVE_PATH, TEST_TMP_PATH, TEST_BAK_PATH, first_save),
		"atomic write creates primary save"
	)
	t.check(FileAccess.file_exists(TEST_SAVE_PATH), "primary save exists after first write")
	t.check(not FileAccess.file_exists(TEST_TMP_PATH), "temp save is promoted away")
	t.check(
		not FileAccess.file_exists(TEST_BAK_PATH),
		"backup is not created without a previous save"
	)

	t.check(
		manager._write_atomic_var(TEST_SAVE_PATH, TEST_TMP_PATH, TEST_BAK_PATH, second_save),
		"atomic write rotates previous save"
	)
	t.check(
		manager._read_save_dictionary(TEST_SAVE_PATH).get("marker", "") == "second",
		"primary contains latest save"
	)
	t.check(
		manager._read_save_dictionary(TEST_BAK_PATH).get("marker", "") == "first",
		"backup contains previous save"
	)

	var migrated: Dictionary = manager._migrate_save({"marker": "legacy"}, 0)
	t.check(migrated.get("save_version", 0) == manager.SAVE_VERSION, "legacy saves receive current save version")
	t.check(migrated.get("marker", "") == "legacy", "migration preserves existing fields")

	manager.free()
	_cleanup()

func _cleanup() -> void:
	for path: String in [TEST_SAVE_PATH, TEST_TMP_PATH, TEST_BAK_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
