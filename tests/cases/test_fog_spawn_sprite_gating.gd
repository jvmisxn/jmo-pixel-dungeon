extends RefCounted
## Regression tests for [audit:S25] — newly spawned ground sprites (items,
## plants, armed bombs) must not flash through unexplored fog. Two guards:
## 1. Spawn sites gate `visible` by the same rule update_entity_visibility
##    uses (currently visible or previously seen).
## 2. refresh_after_turn spawns ground sprites BEFORE the entity-visibility
##    pass, so fresh sprites are fog-gated in the same refresh.


class StubSprite:
	extends RefCounted
	var visible: bool = true
	var cell_pos: int = -1

	func setup_from_item(_item: Variant) -> void:
		pass

	func setup_manual(_category: int, _color: Color) -> void:
		pass

	func setup_for_plant(_plant_id: String) -> void:
		pass

	func place_at(pos: int) -> void:
		cell_pos = pos

	func play_drop() -> void:
		pass

	func play_pickup(_duration: float = 0.2) -> void:
		pass


class StubEntityLayer:
	extends RefCounted
	func add_child(_node: Variant) -> void:
		pass


class StubLevel:
	extends RefCounted
	var visible: Array[bool] = []
	var visited: Array[bool] = []
	var heaps: Array = []
	var pending_bombs: Array = []
	var plants: Dictionary = {}

	func _init(size: int = 100) -> void:
		visible.resize(size)
		visible.fill(false)
		visited.resize(size)
		visited.fill(false)

	func update_fov(_pos: int, _view_distance: int) -> void:
		pass


class StubHero:
	extends RefCounted
	var pos: int = 0

	func get_view_distance() -> int:
		return 8


class StubTileMap:
	extends RefCounted
	func render_changed() -> void:
		pass

	func update_tile_visibility() -> void:
		pass

	func cell_to_world(_pos: int) -> Vector2:
		return Vector2.ZERO


class StubFog:
	extends RefCounted
	func update_visibility() -> void:
		pass


class StubCamera:
	extends RefCounted
	func set_target(_pos: Vector2) -> void:
		pass


class StubScene:
	extends RefCounted
	var _current_level: Variant = null
	var _item_sprites: Dictionary = {}
	var _plant_sprites: Dictionary = {}
	var _armed_bomb_sprites: Dictionary = {}
	var _mob_sprites: Dictionary = {}
	var _entity_layer: Variant = StubEntityLayer.new()
	var effect_manager: Variant = null
	var hero: Variant = null
	var fog_of_war: Variant = StubFog.new()
	var tile_map: Variant = StubTileMap.new()
	var game_camera: Variant = StubCamera.new()
	var call_order: Array[String] = []

	func _get_focused_hero() -> Variant:
		return hero

	func _instantiate_script(_path: String) -> Variant:
		return StubSprite.new()

	func _ensure_mob_sprites() -> void:
		pass

	func _refresh_item_sprites() -> void:
		call_order.append("items")
		SceneVisualCoordinator.refresh_item_sprites(self)

	func _refresh_plant_sprites() -> void:
		call_order.append("plants")
		SceneVisualCoordinator.refresh_plant_sprites(self)

	func _refresh_armed_bomb_sprites() -> void:
		call_order.append("bombs")
		SceneVisualCoordinator.refresh_armed_bomb_sprites(self)

	func _update_entity_visibility() -> void:
		call_order.append("visibility")

	func _cleanup_dead_mobs() -> void:
		pass

	func _interrupt_rest_if_needed() -> void:
		pass

	func _sync_online_snapshot() -> void:
		pass

	func _queue_online_snapshot_sync(_force: bool = false) -> void:
		pass


func run(t: Object) -> void:
	var scene := StubScene.new()
	var level := StubLevel.new()
	scene._current_level = level
	scene.hero = StubHero.new()

	var pos_fogged: int = 5
	var pos_visible: int = 6
	var pos_visited: int = 7
	level.visible[pos_visible] = true
	level.visited[pos_visited] = true

	t.check(not SceneVisualCoordinator.spawned_sprite_visible(scene, pos_fogged),
		"unexplored fogged cell spawns hidden")
	t.check(SceneVisualCoordinator.spawned_sprite_visible(scene, pos_visible),
		"currently visible cell spawns shown")
	t.check(SceneVisualCoordinator.spawned_sprite_visible(scene, pos_visited),
		"previously seen cell spawns shown")
	t.check(not SceneVisualCoordinator.spawned_sprite_visible(scene, -1),
		"out-of-range cell spawns hidden")

	# Item sprites spawned by refresh_item_sprites are fog-gated at spawn.
	level.heaps = [{"pos": pos_fogged, "item": null}, {"pos": pos_visible, "item": null}]
	SceneVisualCoordinator.refresh_item_sprites(scene)
	t.check(scene._item_sprites.has(pos_fogged) and not scene._item_sprites[pos_fogged].visible,
		"item sprite in fogged cell spawns hidden")
	t.check(scene._item_sprites.has(pos_visible) and scene._item_sprites[pos_visible].visible,
		"item sprite in visible cell spawns shown")

	# Plant sprites are fog-gated at spawn.
	level.plants = {pos_fogged: {"plant_id": "firebloom"}, pos_visited: {"plant_id": "sungrass"}}
	SceneVisualCoordinator.refresh_plant_sprites(scene)
	t.check(scene._plant_sprites.has(pos_fogged) and not scene._plant_sprites[pos_fogged].visible,
		"plant sprite in fogged cell spawns hidden")
	t.check(scene._plant_sprites.has(pos_visited) and scene._plant_sprites[pos_visited].visible,
		"plant sprite in previously seen cell spawns shown")

	# Armed bomb sprites are fog-gated at spawn.
	level.pending_bombs = [{"pos": pos_fogged, "bomb": null}]
	SceneVisualCoordinator.refresh_armed_bomb_sprites(scene)
	t.check(scene._armed_bomb_sprites.has(pos_fogged) and not scene._armed_bomb_sprites[pos_fogged].visible,
		"armed bomb sprite in fogged cell spawns hidden")

	# refresh_after_turn must spawn ground sprites before the visibility pass.
	scene.call_order.clear()
	SceneFeedbackCoordinator.refresh_after_turn(scene)
	var vis_idx: int = scene.call_order.find("visibility")
	t.check(vis_idx >= 0, "refresh_after_turn runs the entity-visibility pass")
	for stage: String in ["items", "plants", "bombs"]:
		var stage_idx: int = scene.call_order.find(stage)
		t.check(stage_idx >= 0 and stage_idx < vis_idx,
			"refresh_after_turn spawns %s before the visibility pass" % stage)
