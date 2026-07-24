extends RefCounted
## Floor-transition autosave contract (upstream Dungeon.saveAll on level switch):
## every in-run stair/fall transition routes through LoadingScene with
## `is_continue: true` + `transition_type`, which must arm the post-generation
## autosave. A brand-new game (no transition_type meta) must NOT autosave, and
## `SaveManager.autosave_if_active()` must refuse to write outside an active,
## depth-consistent run.

const SAVE_PATH: String = "user://save_game_full.dat"

var _had_original_save: bool = false
var _original_save_bytes: PackedByteArray = PackedByteArray()

func run(t: Object) -> void:
	_backup_existing_save()
	_prepare_clean_runtime()

	# --- LoadingScene meta contract ---
	for transition_type: String in ["descend", "ascend", "fall"]:
		var scene: Variant = _make_loading_scene({
			"is_continue": true,
			"transition_type": transition_type,
		})
		t.check(scene != null, "loading scene builds for %s meta" % transition_type)
		if scene != null:
			t.check(
				bool(scene.get("_autosave_after_generation")),
				"%s transition arms post-generation autosave" % transition_type
			)
			scene.free()

	var new_game_scene: Variant = _make_loading_scene({
		"chosen_class": ConstantsData.HeroClass.WARRIOR,
	})
	t.check(new_game_scene != null, "loading scene builds for new-game meta")
	if new_game_scene != null:
		t.check(
			not bool(new_game_scene.get("_autosave_after_generation")),
			"new game does not arm post-generation autosave"
		)
		new_game_scene.free()

	# --- autosave_if_active guards ---
	t.check(not SaveManager.autosave_if_active(), "autosave refuses with no active run")
	t.check(not FileAccess.file_exists(SAVE_PATH), "no save written without active run")

	var started_ok: bool = _start_smoke_run()
	t.check(started_ok, "smoke run starts for autosave checks")
	if started_ok:
		GameManager.depth = 2
		t.check(
			not SaveManager.autosave_if_active(),
			"autosave refuses when level depth mismatches run depth"
		)
		t.check(not FileAccess.file_exists(SAVE_PATH), "no save written on depth mismatch")

		GameManager.depth = 1
		t.check(SaveManager.autosave_if_active(), "autosave writes during consistent active run")
		t.check(FileAccess.file_exists(SAVE_PATH), "autosave produced a save file")

	_prepare_clean_runtime()
	_restore_existing_save()

func _make_loading_scene(meta: Dictionary) -> Variant:
	var loading_script: GDScript = load("res://src/scenes/loading_scene.gd") as GDScript
	if loading_script == null:
		return null
	var scene: Variant = loading_script.new()
	for key: Variant in meta:
		scene.set_meta(key, meta[key])
	# Not added to the tree so _process never starts generation; _ready only
	# reads metas and builds the static UI.
	scene._ready()
	return scene

func _start_smoke_run() -> bool:
	GameManager.hero_class = ConstantsData.HeroClass.WARRIOR
	GameManager.hero_subclass = ConstantsData.HeroSubclass.NONE
	GameManager.depth = 1
	GameManager.run_seed = 424242
	GameManager.run_active = true
	GameManager.set_party_classes([ConstantsData.HeroClass.WARRIOR])
	if GameManager.has_method("_reset_stats"):
		GameManager._reset_stats()

	var hero_script: GDScript = load("res://src/actors/hero/hero.gd") as GDScript
	if hero_script == null:
		return false
	var hero: Variant = hero_script.new()
	hero.hero_class = ConstantsData.HeroClass.WARRIOR
	hero.hero_name = "AutosaveSmoke"
	hero.name = "AutosaveSmoke"
	hero.hp = 20
	hero.hp_max = 20
	hero.ht = 20
	GameManager.add_hero(hero)

	var level: Variant = _make_smoke_level(1)
	if level == null:
		return false
	GameManager.current_level = level
	hero.level = level
	hero.pos = level.entrance
	return GameManager.get_primary_hero() != null

func _make_smoke_level(depth: int) -> Variant:
	var level_script: GDScript = load("res://src/levels/level.gd") as GDScript
	if level_script == null:
		return null
	var level: Variant = level_script.new()
	level.depth = depth
	var entrance: int = ConstantsData.xy_to_pos(10, 10)
	var exit_pos: int = ConstantsData.xy_to_pos(11, 10)
	level.entrance = entrance
	level.exit_pos = exit_pos
	for y: int in range(9, 12):
		for x: int in range(9, 13):
			level.map[ConstantsData.xy_to_pos(x, y)] = ConstantsData.Terrain.EMPTY
	level.map[entrance] = ConstantsData.Terrain.ENTRANCE
	level.map[exit_pos] = ConstantsData.Terrain.EXIT
	level.build_flag_maps()
	return level

func _prepare_clean_runtime() -> void:
	if TurnManager != null and TurnManager.has_method("clear_actors"):
		TurnManager.clear_actors()
	if GameManager != null and GameManager.has_method("_cleanup_previous_run"):
		GameManager._cleanup_previous_run()
	QuestHandler.reset()
	if SaveManager != null:
		SaveManager.delete_save()

func _backup_existing_save() -> void:
	_had_original_save = FileAccess.file_exists(SAVE_PATH)
	if not _had_original_save:
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_had_original_save = false
		return
	_original_save_bytes = file.get_buffer(file.get_length())
	file.close()

func _restore_existing_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if not _had_original_save:
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Autosave test could not restore original save file.")
		return
	file.store_buffer(_original_save_bytes)
	file.close()
