class_name OnlineActionCodec
extends RefCounted

static func make_item_ref(hero_node: Variant, item: Variant, equip_slot_names: Array[String]) -> Dictionary:
	if hero_node == null or item == null:
		return {}
	var belongings: Variant = hero_node.get("belongings")
	if belongings == null:
		return {}
	var ref: Dictionary = {"item_id": str(ConstantsData.get_prop(item, "item_id", ""))}
	var backpack: Variant = belongings.get("backpack")
	if backpack is Array:
		for idx: int in range(backpack.size()):
			if backpack[idx] == item:
				ref["backpack_index"] = idx
				return ref
	for slot_name: String in equip_slot_names:
		if belongings.get(slot_name) == item:
			ref["equip_slot"] = slot_name
			return ref
	return ref

static func resolve_item_ref(hero_node: Variant, item_ref: Variant) -> Variant:
	if hero_node == null or not (item_ref is Dictionary):
		return null
	var ref: Dictionary = item_ref
	var belongings: Variant = hero_node.get("belongings")
	if belongings == null:
		return null
	var expected_item_id: String = str(ref.get("item_id", ""))
	if ref.has("backpack_index"):
		var backpack: Variant = belongings.get("backpack")
		var backpack_index: int = int(ref.get("backpack_index", -1))
		if backpack is Array and backpack_index >= 0 and backpack_index < backpack.size():
			var backpack_item: Variant = backpack[backpack_index]
			if backpack_item != null and (expected_item_id.is_empty() or str(ConstantsData.get_prop(backpack_item, "item_id", "")) == expected_item_id):
				return backpack_item
	if ref.has("equip_slot"):
		var equipped_item: Variant = belongings.get(str(ref.get("equip_slot", "")))
		if equipped_item != null and (expected_item_id.is_empty() or str(ConstantsData.get_prop(equipped_item, "item_id", "")) == expected_item_id):
			return equipped_item
	if expected_item_id.is_empty():
		return null
	return belongings.find_item(expected_item_id) if belongings.has_method("find_item") else null

static func encode_network_action(hero_node: Variant, action: Dictionary, equip_slot_names: Array[String]) -> Dictionary:
	var encoded: Dictionary = action.duplicate(true)
	if encoded.has("item"):
		var item_ref: Dictionary = make_item_ref(hero_node, encoded.get("item"), equip_slot_names)
		encoded.erase("item")
		encoded["item_ref"] = item_ref
	if encoded.has("item_a"):
		var item_a_ref: Dictionary = make_item_ref(hero_node, encoded.get("item_a"), equip_slot_names)
		encoded.erase("item_a")
		encoded["item_a_ref"] = item_a_ref
	if encoded.has("item_b"):
		var item_b_ref: Dictionary = make_item_ref(hero_node, encoded.get("item_b"), equip_slot_names)
		encoded.erase("item_b")
		encoded["item_b_ref"] = item_b_ref
	if encoded.has("source_item"):
		var source_item_ref: Dictionary = make_item_ref(hero_node, encoded.get("source_item"), equip_slot_names)
		encoded.erase("source_item")
		encoded["source_item_ref"] = source_item_ref
	if encoded.has("ingredient_items"):
		var ingredient_refs: Array[Dictionary] = []
		var source_ingredients: Variant = encoded.get("ingredient_items", [])
		if source_ingredients is Array:
			for ingredient_item: Variant in source_ingredients:
				ingredient_refs.append(make_item_ref(hero_node, ingredient_item, equip_slot_names))
		encoded.erase("ingredient_items")
		encoded["ingredient_refs"] = ingredient_refs
	if encoded.has("target"):
		encoded.erase("target")
	return encoded

static func normalize_action_for_hero(hero_node: Variant, action: Dictionary, current_level: Variant) -> Dictionary:
	var normalized: Dictionary = action.duplicate(true)
	if not normalized.has("item") and normalized.has("item_ref"):
		var resolved_item: Variant = resolve_item_ref(hero_node, normalized.get("item_ref"))
		if resolved_item != null:
			normalized["item"] = resolved_item
	if not normalized.has("item_a") and normalized.has("item_a_ref"):
		var resolved_item_a: Variant = resolve_item_ref(hero_node, normalized.get("item_a_ref"))
		if resolved_item_a != null:
			normalized["item_a"] = resolved_item_a
	if not normalized.has("item_b") and normalized.has("item_b_ref"):
		var resolved_item_b: Variant = resolve_item_ref(hero_node, normalized.get("item_b_ref"))
		if resolved_item_b != null:
			normalized["item_b"] = resolved_item_b
	if not normalized.has("source_item") and normalized.has("source_item_ref"):
		var resolved_source_item: Variant = resolve_item_ref(hero_node, normalized.get("source_item_ref"))
		if resolved_source_item != null:
			normalized["source_item"] = resolved_source_item
	if not normalized.has("ingredient_items") and normalized.has("ingredient_refs"):
		var resolved_ingredients: Array = []
		var ingredient_refs: Variant = normalized.get("ingredient_refs", [])
		if ingredient_refs is Array:
			for ingredient_ref: Variant in ingredient_refs:
				var resolved_ingredient: Variant = resolve_item_ref(hero_node, ingredient_ref)
				if resolved_ingredient != null:
					resolved_ingredients.append(resolved_ingredient)
		normalized["ingredient_items"] = resolved_ingredients
	if normalized.get("type", "") == "attack" and not normalized.has("target"):
		var target_pos: int = int(normalized.get("target_pos", -1))
		if current_level != null and target_pos >= 0 and current_level.has_method("find_char_at"):
			var target_char: Variant = current_level.find_char_at(target_pos)
			if target_char != null and target_char != hero_node:
				normalized["target"] = target_char
	return normalized
