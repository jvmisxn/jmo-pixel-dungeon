class_name SceneVisualCoordinator
extends RefCounted

static func refresh_hero_identifiers(scene: Variant) -> void:
	if scene == null or GameManager == null:
		return
	var party_size: int = GameManager.get_active_heroes().size() if GameManager.has_method("get_active_heroes") else GameManager.heroes.size()
	var focused_hero: Variant = scene._get_focused_hero()
	var local_owned_hero: Variant = GameManager.get_local_owned_hero() if GameManager.has_method("get_local_owned_hero") else null
	var input_hero: Variant = scene._get_input_hero()
	for hero_node: Variant in GameManager.heroes:
		if hero_node == null or not is_instance_valid(hero_node):
			continue
		var hero_key: int = int(hero_node.get("actor_id")) if hero_node.get("actor_id") != null else -1
		var hero_sprite: Variant = scene._hero_sprites.get(hero_key) if hero_key >= 0 else null
		if hero_sprite == null or not is_instance_valid(hero_sprite) or not hero_sprite.has_method("set_ally_label"):
			continue
		if party_size <= 1:
			hero_sprite.clear_ally_label()
			if hero_sprite.has_method("clear_ground_ring"):
				hero_sprite.clear_ground_ring()
			continue
		var label_text: String = _get_hero_identifier_text(hero_node)
		var label_color: Color = _get_hero_identifier_color(scene, hero_node, focused_hero, local_owned_hero)
		hero_sprite.set_ally_label(label_text, label_color)
		_apply_hero_identifier_ring(scene, hero_sprite, hero_node, focused_hero, local_owned_hero, input_hero)

static func cleanup_dead_mobs(scene: Variant) -> void:
	if scene == null:
		return
	var to_remove: Array[int] = []
	for key: int in scene._mob_sprites.keys():
		var sprite: Variant = scene._mob_sprites[key]
		if sprite == null:
			continue
		if not (sprite is Node2D) or not sprite.has_method("play_death"):
			continue
		if not is_instance_valid(sprite.character):
			to_remove.append(key)
		elif sprite.character is Object and sprite.character.get("is_alive") == false:
			sprite.play_death()
			to_remove.append(key)
	for key: Variant in to_remove:
		scene._mob_sprites.erase(key)

static func refresh_item_sprites(scene: Variant) -> void:
	if scene == null or scene._current_level == null:
		return
	var valid_positions: Dictionary[int, bool] = {}
	for heap: Dictionary in scene._current_level.heaps:
		valid_positions[heap.get("pos", -1)] = true
	var to_remove: Array[int] = []
	for pos: int in scene._item_sprites.keys():
		if valid_positions.has(pos):
			continue
		var sprite: Variant = scene._item_sprites[pos]
		if is_instance_valid(sprite):
			sprite.play_pickup()
		to_remove.append(pos)
	for pos: int in to_remove:
		scene._item_sprites.erase(pos)
	for heap: Dictionary in scene._current_level.heaps:
		var pos: int = heap.get("pos", -1)
		if pos < 0 or scene._item_sprites.has(pos):
			continue
		var sprite: Variant = scene._instantiate_script("res://src/sprites/item_sprite.gd")
		sprite.setup_from_item(heap.get("item"))
		sprite.place_at(pos)
		sprite.play_drop()
		scene._entity_layer.add_child(sprite)
		scene._item_sprites[pos] = sprite

static func refresh_armed_bomb_sprites(scene: Variant) -> void:
	if scene == null or scene._current_level == null:
		return
	var valid_positions: Dictionary[int, bool] = {}
	for bomb_entry: Dictionary in scene._current_level.pending_bombs:
		var bomb_pos: int = bomb_entry.get("pos", -1)
		valid_positions[bomb_pos] = true
	var to_remove: Array[int] = []
	for pos: int in scene._armed_bomb_sprites.keys():
		if valid_positions.has(pos):
			continue
		var stale_sprite: Variant = scene._armed_bomb_sprites[pos]
		if is_instance_valid(stale_sprite):
			stale_sprite.play_pickup(0.15)
		to_remove.append(pos)
	for pos: int in to_remove:
		scene._armed_bomb_sprites.erase(pos)
	for bomb_entry: Dictionary in scene._current_level.pending_bombs:
		var bomb_pos: int = bomb_entry.get("pos", -1)
		if bomb_pos < 0 or scene._armed_bomb_sprites.has(bomb_pos):
			continue
		var bomb: Variant = bomb_entry.get("bomb")
		var sprite: Variant = scene._instantiate_script("res://src/sprites/item_sprite.gd")
		if bomb is Object:
			sprite.setup_from_item(bomb)
		else:
			sprite.setup_manual(ConstantsData.ItemCategory.MISC, Color(0.8, 0.3, 0.2))
		sprite.place_at(bomb_pos)
		sprite.play_drop()
		scene._entity_layer.add_child(sprite)
		scene._armed_bomb_sprites[bomb_pos] = sprite
		if scene.effect_manager:
			scene.effect_manager.show_status(bomb_pos, "Fuse", Color(1.0, 0.7, 0.2))

static func refresh_plant_sprites(scene: Variant) -> void:
	if scene == null or scene._current_level == null:
		return
	var valid_positions: Dictionary[int, bool] = {}
	for plant_pos_variant: Variant in scene._current_level.plants.keys():
		var plant_pos: int = int(plant_pos_variant)
		valid_positions[plant_pos] = true
	var to_remove: Array[int] = []
	for pos: int in scene._plant_sprites.keys():
		if valid_positions.has(pos):
			continue
		var stale_sprite: Variant = scene._plant_sprites[pos]
		if is_instance_valid(stale_sprite):
			stale_sprite.queue_free()
		to_remove.append(pos)
	for pos: int in to_remove:
		scene._plant_sprites.erase(pos)
	for plant_pos_variant: Variant in scene._current_level.plants.keys():
		var plant_pos: int = int(plant_pos_variant)
		if plant_pos < 0 or scene._plant_sprites.has(plant_pos):
			continue
		var plant: Variant = scene._current_level.plants[plant_pos]
		var sprite: Variant = scene._instantiate_script("res://src/sprites/plant_sprite.gd")
		var plant_key: String = str(plant.get("plant_id")) if plant != null and plant.get("plant_id") != null else ""
		sprite.setup_for_plant(plant_key)
		sprite.place_at(plant_pos)
		scene._entity_layer.add_child(sprite)
		scene._plant_sprites[plant_pos] = sprite

static func refresh_blob_overlays(scene: Variant) -> void:
	if scene == null or scene._current_level == null or scene._blob_layer == null:
		return
	var cells_by_pos: Dictionary[int, Dictionary] = {}
	for blob_entry: Dictionary in scene._current_level.blobs:
		var blob: Variant = blob_entry.get("blob")
		if blob == null or not blob.has_method("get_density"):
			continue
		var blob_id: String = str(blob.get("blob_id"))
		var style: String = _blob_style_for_id(blob_id)
		var color: Color = _blob_color_for_id(blob_id)
		var active_cells: Variant = blob.get("active_cells")
		if not (active_cells is Array):
			continue
		for cell_variant: Variant in active_cells:
			var cell: int = int(cell_variant)
			if cell < 0 or cell >= Level.LEN:
				continue
			var density: float = float(blob.call("get_density", cell))
			if density <= 0.0:
				continue
			var alpha: float = _blob_alpha_for_cell(scene, cell, density)
			if alpha <= 0.0:
				continue
			if cells_by_pos.has(cell):
				var existing: Dictionary = cells_by_pos[cell]
				existing["alpha"] = maxf(float(existing.get("alpha", 0.0)), alpha)
				existing["color"] = (existing.get("color", color) as Color).lerp(color, 0.45)
				cells_by_pos[cell] = existing
			else:
				cells_by_pos[cell] = {
					"pos": cell,
					"color": color,
					"alpha": alpha,
					"style": style,
				}
	var render_cells: Array[Dictionary] = []
	for pos: int in cells_by_pos.keys():
		render_cells.append(cells_by_pos[pos])
	scene._blob_layer.set_cells(render_cells)

static func update_entity_visibility(scene: Variant) -> void:
	if scene == null or scene._current_level == null:
		return
	refresh_hero_identifiers(scene)
	for key: Variant in scene._mob_sprites.keys():
		var sprite: Variant = scene._mob_sprites[key]
		if sprite == null:
			continue
		if not (sprite is Node2D) or not sprite.has_method("set_visible_state"):
			continue
		if not is_instance_valid(sprite.character):
			sprite.set_visible_state(false)
		elif sprite.character is Object:
			var mob_pos: int = sprite.character.get("pos")
			if mob_pos >= 0 and mob_pos != sprite.cell_pos:
				sprite.move_to(mob_pos)
			if mob_pos >= 0 and mob_pos < scene._current_level.visible.size():
				sprite.set_visible_state(scene._current_level.visible[mob_pos])
			else:
				sprite.set_visible_state(false)
			if sprite.character.get("hp") != null and sprite.character.get("ht") != null:
				sprite.update_hp_bar(sprite.character.hp, sprite.character.ht)
	for pos: int in scene._item_sprites.keys():
		var sprite: Variant = scene._item_sprites[pos]
		if pos >= 0 and pos < scene._current_level.visible.size():
			sprite.visible = scene._current_level.visible[pos] or scene._current_level.visited[pos]
	for pos: int in scene._plant_sprites.keys():
		var plant_sprite: Variant = scene._plant_sprites[pos]
		if pos >= 0 and pos < scene._current_level.visible.size():
			plant_sprite.visible = scene._current_level.visible[pos] or scene._current_level.visited[pos]
	for pos: int in scene._armed_bomb_sprites.keys():
		var bomb_sprite: Variant = scene._armed_bomb_sprites[pos]
		if pos >= 0 and pos < scene._current_level.visible.size():
			bomb_sprite.visible = scene._current_level.visible[pos] or scene._current_level.visited[pos]
	refresh_blob_overlays(scene)

static func _apply_hero_identifier_ring(scene: Variant, hero_sprite: Variant, hero_node: Variant, focused_hero: Variant, local_owned_hero: Variant, input_hero: Variant) -> void:
	if scene == null or hero_sprite == null or not is_instance_valid(hero_sprite) or not hero_sprite.has_method("set_ground_ring"):
		return
	if hero_node == null:
		hero_sprite.clear_ground_ring()
		return
	if hero_node.get("is_alive") != true:
		hero_sprite.set_ground_ring(scene.FALLEN_RING_FILL, scene.FALLEN_RING_OUTLINE)
		return
	if hero_node == input_hero:
		hero_sprite.set_ground_ring(scene.INPUT_RING_FILL, scene.INPUT_RING_OUTLINE)
		return
	if hero_node == focused_hero:
		hero_sprite.set_ground_ring(scene.FOCUSED_RING_FILL, scene.FOCUSED_RING_OUTLINE)
		return
	if hero_node == local_owned_hero:
		hero_sprite.set_ground_ring(scene.LOCAL_RING_FILL, scene.LOCAL_RING_OUTLINE)
		return
	hero_sprite.set_ground_ring(scene.ALLY_RING_FILL, scene.ALLY_RING_OUTLINE)

static func _get_hero_identifier_text(hero_node: Variant) -> String:
	if hero_node == null:
		return ""
	var base_name: String = str(ConstantsData.get_prop(hero_node, "hero_name", "")).strip_edges()
	if base_name.is_empty():
		base_name = HeroClassData.get_class_name_str(int(ConstantsData.get_prop(hero_node, "hero_class", ConstantsData.HeroClass.WARRIOR)))
	var slot_index: int = int(ConstantsData.get_prop(hero_node, "hero_slot_index", GameManager.get_hero_index(hero_node) if GameManager and GameManager.has_method("get_hero_index") else 0))
	return "P%d %s" % [slot_index + 1, base_name.left(10)]

static func _get_hero_identifier_color(scene: Variant, hero_node: Variant, focused_hero: Variant, local_owned_hero: Variant) -> Color:
	if scene == null or hero_node == null:
		return Color.WHITE
	if hero_node.get("is_alive") != true:
		return scene.FALLEN_LABEL_COLOR
	if hero_node == focused_hero:
		return scene.FOCUSED_LABEL_COLOR
	if hero_node == local_owned_hero:
		return scene.LOCAL_LABEL_COLOR
	return scene.ALLY_LABEL_COLOR

static func _blob_alpha_for_cell(scene: Variant, cell: int, density: float) -> float:
	if scene == null or scene._current_level == null:
		return 0.0
	if cell < 0 or cell >= scene._current_level.visible.size():
		return 0.0
	if scene._current_level.visible[cell]:
		return clampf(0.18 + density * 0.22, 0.18, 0.68)
	return 0.0

static func _blob_color_for_id(blob_id: String) -> Color:
	match blob_id:
		"toxic_gas":
			return Color(0.33, 0.8, 0.33)
		"paralytic_gas":
			return Color(0.95, 0.84, 0.26)
		"confusion_gas":
			return Color(0.72, 0.45, 0.95)
		"fire":
			return Color(1.0, 0.42, 0.12)
		"web":
			return Color(0.88, 0.88, 0.96)
		"water_of_health":
			return Color(0.32, 0.86, 0.94)
		"smoke_screen":
			return Color(0.55, 0.55, 0.6)
		_:
			return Color(0.7, 0.7, 0.7)

static func _blob_style_for_id(blob_id: String) -> String:
	match blob_id:
		"fire":
			return "fire"
		"web":
			return "web"
		_:
			return "gas"
