extends RefCounted
## Regression tests for [audit:S25] — a heap sprite must re-render when the
## top item at its cell changes (upstream Heap.updateImage()). Previously
## refresh_item_sprites keyed by pos only and skipped tracked cells, so the
## old icon persisted after e.g. picking one of several stacked drops.


class StubItem:
	extends RefCounted
	var category: int = 0
	var icon_color: Color = Color.WHITE
	var sprite_index: int = -1


class StubSprite:
	extends RefCounted
	var visible: bool = true
	var cell_pos: int = -1
	var last_item: Variant = null
	var setup_calls: int = 0

	func setup_from_item(item: Variant) -> void:
		last_item = item
		setup_calls += 1

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

	func _init(size: int = 100) -> void:
		visible.resize(size)
		visible.fill(true)
		visited.resize(size)
		visited.fill(true)


class StubScene:
	extends RefCounted
	var _current_level: Variant = null
	var _item_sprites: Dictionary = {}
	var _entity_layer: Variant = StubEntityLayer.new()

	func _instantiate_script(_path: String) -> Variant:
		return StubSprite.new()


func run(t: Variant) -> void:
	_test_sprite_rerenders_on_top_item_change(t)
	_test_unchanged_top_item_not_rerendered(t)
	_test_first_heap_wins_at_shared_pos(t)


func _test_sprite_rerenders_on_top_item_change(t: Variant) -> void:
	var scene: StubScene = StubScene.new()
	scene._current_level = StubLevel.new()
	var sword: StubItem = StubItem.new()
	scene._current_level.heaps = [{"pos": 12, "item": sword}]
	SceneVisualCoordinator.refresh_item_sprites(scene)
	var sprite: Variant = scene._item_sprites.get(12)
	t.check(sprite != null, "sprite created for heap pos")
	t.check(sprite.last_item == sword, "sprite rendered from initial top item")
	var potion: StubItem = StubItem.new()
	scene._current_level.heaps = [{"pos": 12, "item": potion}]
	SceneVisualCoordinator.refresh_item_sprites(scene)
	t.check(scene._item_sprites.get(12) == sprite, "same sprite instance reused after top-item change")
	t.check(sprite.last_item == potion, "sprite re-rendered from new top item")


func _test_unchanged_top_item_not_rerendered(t: Variant) -> void:
	var scene: StubScene = StubScene.new()
	scene._current_level = StubLevel.new()
	var sword: StubItem = StubItem.new()
	scene._current_level.heaps = [{"pos": 20, "item": sword}]
	SceneVisualCoordinator.refresh_item_sprites(scene)
	var sprite: Variant = scene._item_sprites.get(20)
	SceneVisualCoordinator.refresh_item_sprites(scene)
	SceneVisualCoordinator.refresh_item_sprites(scene)
	t.check(sprite.setup_calls == 1, "unchanged top item is not re-setup on later refreshes")


func _test_first_heap_wins_at_shared_pos(t: Variant) -> void:
	var scene: StubScene = StubScene.new()
	scene._current_level = StubLevel.new()
	var top: StubItem = StubItem.new()
	var buried: StubItem = StubItem.new()
	scene._current_level.heaps = [{"pos": 33, "item": top}, {"pos": 33, "item": buried}]
	SceneVisualCoordinator.refresh_item_sprites(scene)
	var sprite: Variant = scene._item_sprites.get(33)
	t.check(sprite.last_item == top, "first heap at a shared pos provides the rendered top item")
	scene._current_level.heaps = [{"pos": 33, "item": buried}]
	SceneVisualCoordinator.refresh_item_sprites(scene)
	t.check(sprite.last_item == buried, "removing the top heap re-renders the buried item")
	t.check(sprite.setup_calls == 2, "re-render happened exactly once for the uncover")
