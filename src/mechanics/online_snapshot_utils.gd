class_name OnlineSnapshotUtils
extends RefCounted

static func serialize_online_snapshot(heroes: Array, input_hero: Variant, current_level: Variant) -> Dictionary:
	var heroes_data: Array[Dictionary] = []
	for hero_node: Variant in heroes:
		if hero_node != null and is_instance_valid(hero_node) and hero_node.has_method("serialize"):
			heroes_data.append(hero_node.serialize())
	var current_input_slot: int = -1
	if input_hero != null and input_hero.get("hero_slot_index") != null:
		current_input_slot = int(input_hero.get("hero_slot_index"))
	return {
		"depth": GameManager.depth,
		"heroes": heroes_data,
		"level": current_level.serialize() if current_level != null and current_level.has_method("serialize") else {},
		"current_input_slot": current_input_slot,
	}

static func capture_hero_snapshot_state(heroes: Array) -> Dictionary:
	var snapshot_state: Dictionary = {}
	for hero_node: Variant in heroes:
		if hero_node == null or not is_instance_valid(hero_node):
			continue
		var hero_key: int = int(hero_node.get("actor_id")) if hero_node.get("actor_id") != null else -1
		if hero_key < 0:
			continue
		snapshot_state[hero_key] = {
			"pos": int(ConstantsData.get_prop(hero_node, "pos", -1)),
			"hp": int(ConstantsData.get_prop(hero_node, "hp", 0)),
			"action": str(ConstantsData.get_prop(hero_node, "last_visible_action", "")),
			"target_pos": int(ConstantsData.get_prop(hero_node, "last_visible_target_pos", -1)),
		}
	return snapshot_state

static func capture_mob_snapshot_state(current_level: Variant) -> Dictionary:
	var snapshot_state: Dictionary = {}
	if current_level == null or current_level.get("mobs") == null:
		return snapshot_state
	for mob_node: Variant in current_level.mobs:
		if mob_node == null or not is_instance_valid(mob_node):
			continue
		var mob_key: int = int(mob_node.get("actor_id")) if mob_node.get("actor_id") != null else mob_node.get_instance_id()
		snapshot_state[mob_key] = {
			"pos": int(ConstantsData.get_prop(mob_node, "pos", -1)),
			"hp": int(ConstantsData.get_prop(mob_node, "hp", 0)),
			"action": str(ConstantsData.get_prop(mob_node, "last_visible_action", "")),
			"target_pos": int(ConstantsData.get_prop(mob_node, "last_visible_target_pos", -1)),
		}
	return snapshot_state

static func capture_level_snapshot_state(current_level: Variant) -> Dictionary:
	var snapshot_state: Dictionary = {
		"map": [],
		"heaps": {},
	}
	if current_level == null:
		return snapshot_state
	if current_level.get("map") is Array:
		snapshot_state["map"] = current_level.map.duplicate()
	var heaps_by_pos: Dictionary = {}
	for heap: Dictionary in current_level.heaps:
		var heap_pos: int = int(heap.get("pos", -1))
		if heap_pos < 0:
			continue
		var item: Variant = heap.get("item")
		var item_name: String = ""
		if item is Object:
			item_name = str(ConstantsData.get_prop(item, "item_name", ConstantsData.get_prop(item, "item_id", "item")))
		if item_name.is_empty():
			item_name = "item"
		heaps_by_pos[heap_pos] = item_name
	snapshot_state["heaps"] = heaps_by_pos
	return snapshot_state

static func find_hero_at_position(heroes: Array, target_pos: int) -> Variant:
	for hero_node: Variant in heroes:
		if hero_node == null or not is_instance_valid(hero_node):
			continue
		if int(ConstantsData.get_prop(hero_node, "pos", -1)) == target_pos:
			return hero_node
	return null

static func remove_heap_at_pos(current_level: Variant, target_pos: int) -> void:
	if current_level == null:
		return
	for idx: int in range(current_level.heaps.size() - 1, -1, -1):
		var heap: Dictionary = current_level.heaps[idx]
		if int(heap.get("pos", -1)) == target_pos:
			current_level.heaps.remove_at(idx)
			return

static func make_item_from_data(item_data: Dictionary) -> Variant:
	if item_data.is_empty():
		return null
	var item_id: String = str(item_data.get("item_id", ""))
	if item_id.is_empty():
		return null
	var item: Variant = Generator.create_item(item_id)
	if item != null and item.has_method("deserialize"):
		item.deserialize(item_data)
	return item

static func find_hero_by_actor_id(heroes: Array, actor_id: int) -> Variant:
	if actor_id < 0:
		return null
	for hero_node: Variant in heroes:
		if hero_node == null or not is_instance_valid(hero_node):
			continue
		if int(ConstantsData.get_prop(hero_node, "actor_id", -1)) == actor_id:
			return hero_node
	return null

static func find_mob_by_actor_id(current_level: Variant, actor_id: int) -> Variant:
	if current_level == null or actor_id < 0:
		return null
	for mob_node: Variant in current_level.mobs:
		if mob_node == null or not is_instance_valid(mob_node):
			continue
		if int(ConstantsData.get_prop(mob_node, "actor_id", -1)) == actor_id:
			return mob_node
	return null
