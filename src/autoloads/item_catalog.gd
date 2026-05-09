class_name ItemCatalogNode
extends Node
## Persistent cross-run item knowledge and lightweight journal catalog support.
## This is a first step toward SPD-style global identification behavior:
## once a potion/scroll/ring type is identified, future instances of that type
## are treated as known for display and journal purposes.

const SAVE_PATH: String = "user://item_catalog.dat"

## item_id -> true for globally identified item types.
var _identified_items: Dictionary[String, bool] = {}

func _ready() -> void:
	_load()

## Mark an item type as globally identified and persist it.
func identify_item(item: Variant) -> void:
	if item == null:
		return
	var item_id: String = ConstantsData.get_prop(item, "item_id", "")
	if item_id.is_empty():
		return

	_identified_items[item_id] = true

	# Apply per-class-type knowledge flags so future display names resolve correctly.
	if item is Potion:
		(item as Potion).known = true
		if Badges:
			Badges.notify_potion_identified(item_id)
	elif item is Scroll:
		(item as Scroll).known = true
		if Badges:
			Badges.notify_scroll_identified(item_id)
	elif item is Ring:
		(item as Ring).ring_known = true

	_save()

## Apply any global item knowledge to a freshly created item instance.
func apply_knowledge(item: Variant) -> void:
	if item == null:
		return
	var item_id: String = ConstantsData.get_prop(item, "item_id", "")
	if item_id.is_empty():
		return
	if not _identified_items.has(item_id):
		return

	if item is Potion:
		(item as Potion).known = true
	elif item is Scroll:
		(item as Scroll).known = true
	elif item is Ring:
		(item as Ring).ring_known = true

## Return true if this item type is globally identified.
func is_item_known(item_id: String) -> bool:
	return _identified_items.has(item_id)

## Build compact catalog data for the Journal window.
func get_catalog_data() -> Dictionary:
	var data: Dictionary = {}
	for item_id: String in _identified_items.keys():
		var item: Item = Generator.create_item(item_id)
		if item == null:
			continue
		apply_knowledge(item)
		item.identified = true
		item.level_known = true
		item.cursed_known = true
		var category: int = ConstantsData.get_prop(item, "category", ConstantsData.ItemCategory.MISC)
		if not data.has(category):
			data[category] = []
		data[category].append({
			"item_id": item_id,
			"name": item.get_display_name(),
			"identified": true,
		})

	# Stable ordering makes the journal less noisy.
	for cat: Variant in data.keys():
		var arr: Array = data[cat]
		arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.get("name", "") < b.get("name", "")
		)
		data[cat] = arr
	return data

func _save() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ItemCatalog: Failed to open save file for writing.")
		return
	file.store_var({
		"identified_items": _identified_items,
	}, true)
	file.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("ItemCatalog: Failed to open save file for reading.")
		return
	var data: Variant = file.get_var(true)
	file.close()
	if data is Dictionary:
		_identified_items = data.get("identified_items", {})
