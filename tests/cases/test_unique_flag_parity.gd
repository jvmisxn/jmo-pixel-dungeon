extends RefCounted
## Upstream flags Scroll of Upgrade and Potion of Strength `unique = true`
## (ScrollOfUpgrade.java:51, PotionOfStrength.java:37). With the flag real:
## - Heap.burn_at/freeze_at no longer need item_id special cases (covered by
##   test_heap_burn_freeze.gd).
## - Frozen.freeze_carried_item can no longer shatter a carried Potion of
##   Strength (upstream Frost.attachTo filters `!i.unique`).
## - Transmutation still allows unique potions/scrolls (upstream usableOnItem
##   only blocks unique artifacts; the port's mastery potion stands in for
##   the non-Potion TengusMask and stays blocked).
## - Unblessed-ankh revival drops unique consumables (test_ankh_revival.gd).

class FakeItem:
	extends RefCounted

	var item_id: String = ""
	var item_name: String = ""
	var category: int = ConstantsData.ItemCategory.MISC
	var unique: bool = false

	func _init(new_id: String, new_name: String, new_category: int, new_unique: bool) -> void:
		item_id = new_id
		item_name = new_name
		category = new_category
		unique = new_unique

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
	_test_flags(t)
	_test_frozen_skips_unique_potion(t)
	_test_transmute_unique_rules(t)

func _test_flags(t: Object) -> void:
	var sou: Scroll = Scroll.create("upgrade")
	var pos_potion: Potion = Potion.create("strength")
	var plain_scroll: Scroll = Scroll.create("identify")
	var plain_potion: Potion = Potion.create("healing")
	t.check(sou != null and sou.unique, "Scroll of Upgrade is unique")
	t.check(pos_potion != null and pos_potion.unique, "Potion of Strength is unique")
	t.check(plain_scroll != null and not plain_scroll.unique, "Scroll of Identify is not unique")
	t.check(plain_potion != null and not plain_potion.unique, "Potion of Healing is not unique")

func _test_frozen_skips_unique_potion(t: Object) -> void:
	var script: Variant = load("res://src/actors/buffs/frozen.gd")
	t.check(script != null and script is GDScript, "frozen.gd compiles")
	if script == null:
		return

	var hero: FakeHero = FakeHero.new()
	hero.belongings.items = [
		FakeItem.new("strength", "potion of strength", ConstantsData.ItemCategory.POTION, true),
		FakeItem.new("ration", "ration", ConstantsData.ItemCategory.FOOD, false),
	]

	var frozen: Node = script.new()
	frozen.attach(hero)

	t.check(
		hero.belongings.removed.is_empty(),
		"Frozen never shatters a carried unique potion (Potion of Strength)"
	)
	t.check(hero.belongings.items.size() == 2, "backpack is untouched")

	frozen.detach()
	frozen.free()
	hero.free()

func _test_transmute_unique_rules(t: Object) -> void:
	var wnd_script: Variant = load("res://src/ui/windows/wnd_transmute.gd")
	t.check(wnd_script != null and wnd_script is GDScript, "wnd_transmute.gd compiles")
	if wnd_script == null:
		return

	var sou: Scroll = Scroll.create("upgrade")
	var pos_potion: Potion = Potion.create("strength")
	var mastery: Potion = Potion.create("mastery")
	t.check(
		not wnd_script.call("_unique_blocked", sou, ConstantsData.ItemCategory.SCROLL),
		"unique Scroll of Upgrade stays transmutable (upstream usableOnItem)"
	)
	t.check(
		not wnd_script.call("_unique_blocked", pos_potion, ConstantsData.ItemCategory.POTION),
		"unique Potion of Strength stays transmutable"
	)
	t.check(
		wnd_script.call("_unique_blocked", mastery, ConstantsData.ItemCategory.POTION),
		"mastery potion (TengusMask stand-in) is never transmutable"
	)
	var artifact_like: FakeItem = FakeItem.new(
		"fake_artifact", "fake artifact", ConstantsData.ItemCategory.ARTIFACT, true
	)
	t.check(
		wnd_script.call("_unique_blocked", artifact_like, ConstantsData.ItemCategory.ARTIFACT),
		"unique artifacts stay blocked from transmutation"
	)
