extends RefCounted
## Bags must actually work in play: a bag held in the backpack should catch
## matching pickups so they land inside it instead of eating a top-level slot,
## and the rest of the inventory API (find/count/remove) must still see items
## that live inside a bag. Also covers the Magical Holster accepting missile
## weapons, which share the WEAPON category with melee weapons.


func run(t: Object) -> void:
	_check_pickup_routes_into_bag(t)
	_check_stacking_inside_bag(t)
	_check_full_bag_falls_back_to_backpack(t)
	_check_lookup_and_removal_reach_bag_contents(t)
	_check_holster_accepts_missiles(t)


func _check_pickup_routes_into_bag(t: Object) -> void:
	var b: Belongings = Belongings.new()
	var pouch: Bag = Bag.create("velvet_pouch")
	t.check(b.add_item(pouch), "pouch enters the backpack")
	t.check(b.item_count() == 1, "backpack holds only the pouch")

	var seed: Item = Generator.create_item("seed_of_firebloom")
	t.check(b.add_item(seed), "seed pickup succeeds")
	t.check(b.item_count() == 1, "seed did not consume a backpack slot")
	t.check(pouch.item_count() == 1, "seed landed inside the pouch")
	t.check(not (seed in b.backpack), "seed is not loose in the backpack")


func _check_stacking_inside_bag(t: Object) -> void:
	var b: Belongings = Belongings.new()
	b.add_item(Bag.create("velvet_pouch"))
	var pouch: Bag = b.backpack[0] as Bag

	b.add_item(Generator.create_item("seed_of_firebloom"))
	b.add_item(Generator.create_item("seed_of_firebloom"))
	t.check(pouch.item_count() == 1, "two identical seeds stack to one entry in the bag")
	t.check(b.count_item("seed_of_firebloom") == 2, "count sees the stacked quantity inside the bag")


func _check_full_bag_falls_back_to_backpack(t: Object) -> void:
	var b: Belongings = Belongings.new()
	var pouch: Bag = Bag.create("velvet_pouch")
	pouch.size = 1
	b.add_item(pouch)

	# Distinct non-stacking-with-each-other categories keep the single slot filled.
	b.add_item(Generator.create_item("blink"))  # a stone (STONE category)
	t.check(pouch.item_count() == 1, "pouch fills its one slot")

	var extra_stone: Item = Generator.create_item("shock")  # different stone id
	t.check(b.add_item(extra_stone), "overflow pickup still succeeds")
	t.check(pouch.item_count() == 1, "full pouch does not grow past its size")
	t.check(extra_stone in b.backpack, "overflow stone falls back to the backpack")


func _check_lookup_and_removal_reach_bag_contents(t: Object) -> void:
	var b: Belongings = Belongings.new()
	b.add_item(Bag.create("velvet_pouch"))
	var pouch: Bag = b.backpack[0] as Bag
	b.add_item(Generator.create_item("seed_of_firebloom"))
	b.add_item(Generator.create_item("seed_of_firebloom"))
	b.add_item(Generator.create_item("seed_of_firebloom"))

	t.check(b.find_item_by_id("seed_of_firebloom") != null, "find_item_by_id reaches into the bag")
	t.check(b.find_item("seed_of_firebloom") != null, "find_item reaches into the bag")
	t.check(b.count_item("seed_of_firebloom") == 3, "count totals bagged quantity")

	var removed: int = b.remove_item_quantity("seed_of_firebloom", 2)
	t.check(removed == 2, "remove_item_quantity pulls units from the bag")
	t.check(b.count_item("seed_of_firebloom") == 1, "one seed remains after partial removal")

	var last: Item = b.remove_item_by_id("seed_of_firebloom")
	t.check(last != null, "remove_item_by_id extracts the final bagged seed")
	t.check(pouch.item_count() == 0, "bag is empty after all seeds removed")
	t.check(b.count_item("seed_of_firebloom") == 0, "no seeds remain anywhere")


func _check_holster_accepts_missiles(t: Object) -> void:
	var holster: Bag = Bag.create("magical_holster")
	t.check(holster.accepts_missiles, "magical holster is flagged for missiles")

	var wand: Item = Generator.create_item("wand_of_frost")
	var dart: Item = Generator.create_item("dart")
	var sword: Item = Generator.create_item("dagger")

	t.check(holster.can_hold(wand), "holster accepts a wand")
	t.check(holster.can_hold(dart), "holster accepts a missile weapon")
	t.check(not holster.can_hold(sword), "holster rejects a melee weapon")
	t.check(holster.add_to_bag(dart), "missile weapon stores in the holster")

	# The missile flag survives a save/load round-trip.
	var restored: Bag = Bag.new()
	restored.deserialize(holster.serialize())
	t.check(restored.accepts_missiles, "missile acceptance survives serialization")
	t.check(restored.can_hold(Generator.create_item("javelin")), "restored holster still takes missiles")
