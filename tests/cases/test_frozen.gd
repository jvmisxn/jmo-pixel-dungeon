extends RefCounted
## Frozen should shatter at most one freezable backpack item when applied.

class FakeItem:
	extends RefCounted

	var item_id: String = ""
	var item_name: String = ""
	var category: int = ConstantsData.ItemCategory.MISC

	func _init(new_id: String, new_name: String, new_category: int) -> void:
		item_id = new_id
		item_name = new_name
		category = new_category

class FakeBelongings:
	extends RefCounted

	var items: Array = []
	var removed: Array = []

	func get_backpack_items() -> Array:
		return items

	func remove_item(item: Variant) -> void:
		removed.append(item)
		items.erase(item)

class FakeHero:
	extends Node

	var is_hero: bool = true
	var paralysed: int = 0
	var belongings: FakeBelongings = FakeBelongings.new()

	func _init() -> void:
		name = "Test Hero"

	func get_buff(_buff_id: String) -> Node:
		return null

	func remove_buff(_buff: Node) -> void:
		pass

func run(t: Object) -> void:
	var script: Variant = load("res://src/actors/buffs/frozen.gd")
	t.check(script != null and script is GDScript, "frozen.gd compiles")
	if script == null:
		return

	var hero: FakeHero = FakeHero.new()
	hero.belongings.items = [
		FakeItem.new("healing", "potion of healing", ConstantsData.ItemCategory.POTION),
		FakeItem.new("invisibility", "potion of invisibility", ConstantsData.ItemCategory.POTION),
		FakeItem.new("mystery_meat", "mystery meat", ConstantsData.ItemCategory.FOOD),
		FakeItem.new("ration", "ration", ConstantsData.ItemCategory.FOOD),
	]

	var frozen: Node = script.new()
	frozen.attach(hero)

	t.check(hero.paralysed == 1, "Frozen increments the paralysis counter")
	t.check(hero.belongings.removed.size() == 1, "Frozen shatters exactly one freezable item")
	t.check(hero.belongings.items.size() == 3, "Frozen leaves the rest of the backpack intact")

	frozen.detach()
	t.check(hero.paralysed == 0, "Frozen decrements the paralysis counter on detach")

	frozen.free()
	hero.free()
