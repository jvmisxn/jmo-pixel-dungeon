class_name Heap
extends RefCounted
## Represents a pile of items on the ground at a particular dungeon cell.
## Different heap types correspond to different containers (chests, skeletons, etc.).

## The type of container this heap represents.
enum HeapType {
	HEAP,            ## Standard item drop on the floor.
	FOR_SALE,        ## Item in a shop with a price tag.
	CRYSTAL_CHEST,   ## Crystal chest — item is visible but requires a crystal key.
	LOCKED_CHEST,    ## Locked chest — requires a golden key.
	SKELETON,        ## Skeleton remains — may crumble and deal damage.
	TOMB,            ## Tomb — disturbing it may summon a wraith.
	REMAINS,         ## Hero remains from a previous run.
}

## Flat-array position of this heap in the dungeon level.
var pos: int = -1
## Items contained in this heap.
var items: Array[Item] = []
## What kind of container this heap is.
var heap_type: HeapType = HeapType.HEAP

# ---------------------------------------------------------------------------
# Item Management
# ---------------------------------------------------------------------------

## Add an item to this heap. Stacks with existing items when possible.
func add_item(item: Item) -> void:
	if item == null:
		return
	# Attempt stacking
	if item.is_stackable():
		for existing: Item in items:
			if existing.can_stack_with(item):
				existing.merge_stack(item)
				return
	items.append(item)

## Remove a specific item from the heap. Returns true if found and removed.
func remove_item(item: Item) -> bool:
	var idx: int = items.find(item)
	if idx >= 0:
		items.remove_at(idx)
		return true
	return false

## Return the top item without removing it, or null if empty.
func peek() -> Item:
	if items.is_empty():
		return null
	return items[items.size() - 1]

## Pick up and remove the top item. Returns the item or null.
func pick_up() -> Item:
	if items.is_empty():
		return null
	return items.pop_back()

## Returns true if there are no items in this heap.
func is_empty() -> bool:
	return items.is_empty()

## Returns the number of items in the heap.
func size() -> int:
	return items.size()

## Returns a display name for the heap based on its type.
func get_display_name() -> String:
	match heap_type:
		HeapType.HEAP:
			if items.size() == 1:
				return items[0].get_display_name()
			return "Items"
		HeapType.FOR_SALE:
			if items.size() == 1:
				return "%s (for sale)" % items[0].get_display_name()
			return "Items for sale"
		HeapType.CRYSTAL_CHEST:
			return "Crystal chest"
		HeapType.LOCKED_CHEST:
			return "Locked chest"
		HeapType.SKELETON:
			return "Skeleton"
		HeapType.TOMB:
			return "Tomb"
		HeapType.REMAINS:
			return "Remains"
	return "Items"

## Returns the sell price if this is a FOR_SALE heap. Uses the top item's value.
func sale_price() -> int:
	if heap_type != HeapType.FOR_SALE:
		return 0
	var top: Item = peek()
	if top == null:
		return 0
	# Shop items sell at 5x their base value
	return top.value() * 5

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

## Serialize the heap to a dictionary.
func serialize() -> Dictionary:
	var items_data: Array[Dictionary] = []
	for item: Item in items:
		items_data.append(item.serialize())
	return {
		"pos": pos,
		"heap_type": heap_type,
		"items": items_data,
	}

## Restore the heap from a saved dictionary.
## Note: item deserialization requires the Generator.create_item() factory
## to reconstruct proper subclass instances. Falls back to base Item if
## the generator is not available.
func deserialize(data: Dictionary) -> void:
	pos = data.get("pos", -1)
	heap_type = data.get("heap_type", HeapType.HEAP) as HeapType
	items.clear()
	var items_data: Variant = data.get("items", [])
	if items_data is Array:
		for item_data: Variant in items_data:
			if item_data is Dictionary:
				var item_dict: Dictionary = item_data as Dictionary
				var item_id: String = item_dict.get("item_id", "")
				var item: Item = Generator.create_item(item_id) if item_id != "" else Item.new()
				item.deserialize(item_dict)
				items.append(item)
