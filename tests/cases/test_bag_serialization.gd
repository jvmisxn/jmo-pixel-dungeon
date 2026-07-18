extends RefCounted
## Bag contents must survive serialize -> deserialize. Previously Bag.serialize()
## wrote its stored items but Bag.deserialize() dropped them, silently emptying
## every bag on save/load.


func run(t: Object) -> void:
	_check_round_trip_preserves_contents(t)
	_check_round_trip_via_generator(t)
	_check_empty_bag_round_trip(t)


func _check_round_trip_preserves_contents(t: Object) -> void:
	var bag: Bag = Bag.create("velvet_pouch")
	var seed: Item = Generator.create_item("seed_of_firebloom")
	var stone: Item = Generator.create_item("blink")
	t.check(bag.add_to_bag(seed), "seed routes into velvet pouch")
	t.check(bag.add_to_bag(stone), "stone routes into velvet pouch")
	t.check(bag.item_count() == 2, "bag holds two items before save")

	var data: Dictionary = bag.serialize()

	var restored: Bag = Bag.new()
	restored.deserialize(data)
	t.check(restored.item_count() == 2, "bag keeps both items after deserialize")
	t.check(restored.find_item("seed_of_firebloom") != null, "seed survives round-trip")
	t.check(restored.find_item("blink") != null, "stone survives round-trip")
	var restored_seed: Item = restored.find_item("seed_of_firebloom")
	t.check(restored_seed.get_script() == seed.get_script(), "restored item keeps concrete script")


func _check_round_trip_via_generator(t: Object) -> void:
	# Mirrors how Belongings restores a bag from the backpack: create by id, then
	# deserialize the saved dictionary onto the fresh instance.
	var bag: Bag = Bag.create("scroll_holder")
	var scroll: Item = Generator.create_item("teleportation")
	t.check(bag.add_to_bag(scroll), "scroll routes into scroll holder")
	var data: Dictionary = bag.serialize()

	var reloaded: Item = Generator.create_item(data.get("item_id", "")) as Item
	t.check(reloaded is Bag, "generator rebuilds a Bag from saved id")
	reloaded.deserialize(data)
	var reloaded_bag: Bag = reloaded as Bag
	t.check(reloaded_bag.item_count() == 1, "generator-backed reload keeps bag contents")
	t.check(reloaded_bag.find_item("teleportation") != null, "scroll survives generator-backed reload")


func _check_empty_bag_round_trip(t: Object) -> void:
	var bag: Bag = Bag.create("potion_bandolier")
	var data: Dictionary = bag.serialize()
	var restored: Bag = Bag.new()
	restored.deserialize(data)
	t.check(restored.item_count() == 0, "empty bag stays empty after round-trip")
	t.check(restored.accepted_category == ConstantsData.ItemCategory.POTION, "bag category survives round-trip")
