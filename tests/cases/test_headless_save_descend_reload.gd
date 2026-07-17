extends RefCounted
## Headless lifecycle smoke test: start a run, descend, save, reload, and verify
## broad run state survived without needing a rendered GameScene.

const SAVE_PATH: String = "user://save_game_full.dat"
const SMOKE_SEED: int = 172915

var _had_original_save: bool = false
var _original_save_bytes: PackedByteArray = PackedByteArray()

func run(t: Object) -> void:
	_backup_existing_save()
	_prepare_clean_runtime()

	var loaded_ok: bool = false
	var saved_depth: int = -1
	var saved_hp: int = -1
	var saved_inventory: Dictionary = {}

	var started_ok: bool = _start_smoke_run()
	t.check(started_ok, "smoke run starts on depth 1")
	t.check(GameManager.depth == 1, "new smoke run starts on depth 1")
	t.check(_current_level_depth() == 1, "depth 1 level exists")

	var first_hero: Variant = GameManager.get_primary_hero()
	t.check(first_hero != null, "smoke run has a primary hero")
	if first_hero != null:
		t.check(int(first_hero.get("hp")) > 0, "primary hero starts alive")
		t.check(_hero_has_inventory(first_hero), "primary hero starts with inventory")

	if first_hero != null:
		var descend_result: int = GameManager.descend()
		t.check(descend_result == 2, "GameManager descends to depth 2")
		t.check(_install_smoke_level(2), "smoke run installs depth 2")
		t.check(_current_level_depth() == 2, "depth 2 level exists")

		var depth_two_hero: Variant = GameManager.get_primary_hero()
		if depth_two_hero != null:
			saved_depth = GameManager.depth
			saved_hp = int(depth_two_hero.get("hp"))
			saved_inventory = _inventory_signature(depth_two_hero)

		t.check(SaveManager.save_full_game(), "smoke run save succeeds")
		_prepare_clean_runtime(false)
		loaded_ok = SaveManager.load_full_game()
		t.check(loaded_ok, "smoke run reload succeeds")

	if loaded_ok:
		var restored_hero: Variant = GameManager.get_primary_hero()
		t.check(GameManager.depth == saved_depth, "reload preserves depth")
		t.check(_current_level_depth() == saved_depth, "reload restores current level")
		t.check(restored_hero != null, "reload restores primary hero")
		if restored_hero != null:
			t.check(int(restored_hero.get("hp")) == saved_hp, "reload preserves hero HP")
			t.check(
				_inventory_signature(restored_hero) == saved_inventory,
				"reload preserves starter inventory signature"
			)
			t.check(
				ConstantsData.is_valid_pos(int(restored_hero.get("pos"))),
				"reload restores hero to a valid cell"
			)

	_prepare_clean_runtime(false)
	_restore_existing_save()

func _start_smoke_run() -> bool:
	GameManager.hero_class = ConstantsData.HeroClass.WARRIOR
	GameManager.hero_subclass = ConstantsData.HeroSubclass.NONE
	GameManager.depth = 1
	GameManager.gold = 0
	GameManager.score = 0
	GameManager.run_seed = SMOKE_SEED
	GameManager.run_active = true
	GameManager.set_party_classes([ConstantsData.HeroClass.WARRIOR])
	if GameManager.has_method("_reset_stats"):
		GameManager._reset_stats()

	var hero_script: GDScript = load("res://src/actors/hero/hero.gd") as GDScript
	var item_script: GDScript = load("res://src/items/item.gd") as GDScript
	if hero_script == null or item_script == null:
		return false
	var hero: Variant = hero_script.new()
	hero.hero_class = ConstantsData.HeroClass.WARRIOR
	hero.hero_name = "Smoke"
	hero.name = "Smoke"
	hero.hp = 20
	hero.hp_max = 20
	hero.ht = 20
	hero.str_val = 10
	hero.attack_skill = 10
	hero.defense_skill = 5
	var ration: Variant = item_script.new()
	ration.item_id = "ration"
	ration.item_name = "Ration"
	hero.belongings.add_item(ration)
	GameManager.add_hero(hero)
	if not _install_smoke_level(1):
		return false
	return GameManager.current_level != null and GameManager.get_primary_hero() != null

func _install_smoke_level(depth: int) -> bool:
	var level: Variant = _make_smoke_level(depth)
	if level == null:
		return false
	GameManager.current_level = level
	for hero_node: Variant in GameManager.get_active_heroes():
		hero_node.set("level", level)
		hero_node.set("pos", level.entrance)
	return true

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

func _current_level_depth() -> int:
	if GameManager.current_level == null:
		return -1
	return int(GameManager.current_level.get("depth"))

func _hero_has_inventory(hero: Variant) -> bool:
	return not _inventory_signature(hero).is_empty()

func _inventory_signature(hero: Variant) -> Dictionary:
	if hero == null:
		return {}
	var belongings: Variant = hero.get("belongings")
	if belongings == null:
		return {}
	return {
		"backpack": _item_ids(belongings.get("backpack")),
		"weapon": _item_id(belongings.get("weapon")),
		"armor": _item_id(belongings.get("armor")),
		"artifact": _item_id(belongings.get("artifact")),
		"misc": _item_id(belongings.get("misc")),
		"spirit_bow": _item_id(belongings.get("spirit_bow")),
		"ring_left": _item_id(belongings.get("ring_left")),
		"ring_right": _item_id(belongings.get("ring_right")),
	}

func _item_ids(items: Variant) -> Array[String]:
	var ids: Array[String] = []
	if not items is Array:
		return ids
	for item: Variant in items:
		ids.append(_item_id(item))
	ids.sort()
	return ids

func _item_id(item: Variant) -> String:
	if item == null:
		return ""
	return str(item.get("item_id"))

func _prepare_clean_runtime(delete_save_file: bool = true) -> void:
	if TurnManager != null and TurnManager.has_method("clear_actors"):
		TurnManager.clear_actors()
	if GameManager != null and GameManager.has_method("_cleanup_previous_run"):
		GameManager._cleanup_previous_run()
	QuestHandler.reset()
	if delete_save_file and SaveManager != null:
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
		push_error("Smoke test could not restore original save file.")
		return
	file.store_buffer(_original_save_bytes)
	file.close()
