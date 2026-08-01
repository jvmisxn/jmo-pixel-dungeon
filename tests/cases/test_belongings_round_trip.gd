extends RefCounted
## Belongings round-trip tests: equip→serialize→deserialize identity,
## quickslot rebind, stack merge, and remove_quantity.
## Covers the highest data-loss surface in the hero system ([P2][audit:S02]).

func run(t: Object) -> void:
	_test_equip_serialize_deserialize(t)
	_test_quickslot_rebind(t)
	_test_stack_merge(t)
	_test_remove_quantity(t)

# ---------------------------------------------------------------------------
# equip → serialize → deserialize identity
# ---------------------------------------------------------------------------

func _test_equip_serialize_deserialize(t: Object) -> void:
	var b := Belongings.new()
	var sword: Item = Generator.create_item("sword")
	sword.level = 2
	var leather: Item = Generator.create_item("leather_armor")
	leather.level = 1
	var ring: Item = Generator.create_item("ring_of_accuracy")
	ring.level = 3
	b.equip_weapon(sword)
	b.equip_armor(leather)
	b.equip_ring(ring, true)

	var data: Dictionary = b.serialize()
	var r := Belongings.new()
	r.deserialize(data)

	t.check(r.weapon != null and r.weapon.item_id == "sword",
		"equip round-trip: primary weapon item_id restores")
	t.check(r.weapon != null and r.weapon.level == 2,
		"equip round-trip: primary weapon level restores")
	t.check(r.armor != null and r.armor.item_id == "leather_armor",
		"equip round-trip: armor item_id restores")
	t.check(r.armor != null and r.armor.level == 1,
		"equip round-trip: armor level restores")
	t.check(r.ring_left != null and r.ring_left.item_id == "ring_of_accuracy",
		"equip round-trip: ring_left item_id restores")
	t.check(r.ring_left != null and r.ring_left.level == 3,
		"equip round-trip: ring_left level restores")
	t.check(r.ring_right == null,
		"equip round-trip: ring_right is null when not equipped")
	t.check(r.armor == null or r.armor != r.weapon,
		"equip round-trip: armor and weapon are distinct instances after restore")

# ---------------------------------------------------------------------------
# quickslot rebind survives serialize → deserialize
# ---------------------------------------------------------------------------

func _test_quickslot_rebind(t: Object) -> void:
	var b := Belongings.new()
	var scroll: Item = Generator.create_item("scroll_of_identify")
	b.add_item(scroll)
	b.set_quickslot(1, scroll)

	t.check(b.get_quickslot(1) == scroll,
		"quickslot: item is in slot 1 before serialize")

	var data: Dictionary = b.serialize()
	var r := Belongings.new()
	r.deserialize(data)

	var qs: Item = r.get_quickslot(1)
	t.check(qs != null and qs.item_id == "scroll_of_identify",
		"quickslot: slot 1 resolves to scroll_of_identify after deserialize")
	t.check(r.get_quickslot(0) == null,
		"quickslot: slot 0 is empty when only slot 1 was assigned")

# ---------------------------------------------------------------------------
# stack merge: two separate stacks collapse into one backpack entry
# ---------------------------------------------------------------------------

func _test_stack_merge(t: Object) -> void:
	var b := Belongings.new()
	var darts_a: Item = Generator.create_item("dart")
	darts_a.quantity = 3
	var darts_b: Item = Generator.create_item("dart")
	darts_b.quantity = 4

	t.check(b.add_item(darts_a), "stack merge: first dart stack added successfully")
	t.check(b.add_item(darts_b), "stack merge: second dart stack added to backpack")

	t.check(b.backpack.size() == 1,
		"stack merge: both dart stacks collapsed into one backpack slot")
	t.check(b.backpack[0].quantity == 7,
		"stack merge: merged quantity equals 3 + 4 = 7")

# ---------------------------------------------------------------------------
# remove_quantity: partial removal leaves correct remainder
# ---------------------------------------------------------------------------

func _test_remove_quantity(t: Object) -> void:
	var b := Belongings.new()
	var darts: Item = Generator.create_item("dart")
	darts.quantity = 5
	b.add_item(darts)

	var removed: int = b.remove_item_quantity("dart", 3)

	t.check(removed == 3, "remove_quantity: reports 3 units removed from stack of 5")
	t.check(b.backpack.size() == 1,
		"remove_quantity: item still in backpack after partial removal")
	t.check(b.backpack[0].quantity == 2,
		"remove_quantity: 2 darts remain after removing 3 from 5")

	var removed2: int = b.remove_item_quantity("dart", 10)
	t.check(removed2 == 2,
		"remove_quantity: removing more than available returns actual removed count")
	t.check(b.backpack.size() == 0,
		"remove_quantity: backpack is empty after last dart removed")
