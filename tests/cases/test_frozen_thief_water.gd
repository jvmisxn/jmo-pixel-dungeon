extends RefCounted
## Frost (port Frozen) parity follow-ups from upstream Frost.java:
## - attachTo Thief branch: a frozen thief's stolen non-unique potion
##   shatters at the thief's cell (item lost), a stolen mystery meat becomes
##   a Frozen Carpaccio, and unique potions (Potion of Strength) survive.
##   The port duck-types on `stolen_item` so Bandit is covered too.
## - detach: thawing while standing in water applies Chill for
##   Chill.DURATION/2 turns.


class FakePotion:
	extends RefCounted

	var item_id: String = "potion_of_healing"
	var item_name: String = "Potion of Healing"
	var category: int = ConstantsData.ItemCategory.POTION
	var unique: bool = false
	var shattered_at: int = -1

	func shatter(spos: int, _lvl: Variant) -> void:
		shattered_at = spos


class FakeMeat:
	extends RefCounted

	var item_id: String = "mystery_meat"
	var item_name: String = "Mystery Meat"
	var category: int = ConstantsData.ItemCategory.FOOD
	var unique: bool = false


class FakeLevel:
	extends RefCounted

	var water_cells: Dictionary = {}

	func get_terrain(cell: int) -> int:
		if water_cells.has(cell):
			return ConstantsData.Terrain.WATER
		return ConstantsData.Terrain.EMPTY


func run(t: Object) -> void:
	_test_thief_potion_shatters(t)
	_test_thief_unique_potion_survives(t)
	_test_thief_meat_becomes_carpaccio(t)
	_test_water_detach_chills(t)
	_test_dry_detach_no_chill(t)


func _make_thief(level: Variant) -> Thief:
	var thief := Thief.new()
	thief.pos = ConstantsData.xy_to_pos(10, 10)
	thief.level = level
	return thief


func _test_thief_potion_shatters(t: Object) -> void:
	var level := FakeLevel.new()
	var thief := _make_thief(level)
	var potion := FakePotion.new()
	thief.stolen_item = potion

	thief.add_buff(Frozen.new())

	t.check(thief.stolen_item == null, "frozen thief loses its stolen potion")
	t.check(
		potion.shattered_at == thief.pos,
		"stolen potion shatters at the thief's cell"
	)
	thief.free()


func _test_thief_unique_potion_survives(t: Object) -> void:
	var level := FakeLevel.new()
	var thief := _make_thief(level)
	var potion := FakePotion.new()
	potion.item_id = "potion_of_strength"
	potion.item_name = "Potion of Strength"
	potion.unique = true
	thief.stolen_item = potion

	thief.add_buff(Frozen.new())

	t.check(
		thief.stolen_item == potion,
		"unique stolen potion (PoS) survives the freeze"
	)
	t.check(potion.shattered_at == -1, "unique stolen potion never shatters")
	thief.free()


func _test_thief_meat_becomes_carpaccio(t: Object) -> void:
	var level := FakeLevel.new()
	var thief := _make_thief(level)
	thief.stolen_item = FakeMeat.new()

	thief.add_buff(Frozen.new())

	t.check(
		thief.stolen_item != null
		and thief.stolen_item.get("item_id") == "frozen_carpaccio",
		"stolen mystery meat becomes a Frozen Carpaccio"
	)
	thief.free()


func _test_water_detach_chills(t: Object) -> void:
	var level := FakeLevel.new()
	var victim := Char.new()
	victim.name = "ThawTarget"
	victim.pos = ConstantsData.xy_to_pos(12, 12)
	victim.level = level
	level.water_cells[victim.pos] = true

	var frozen: Node = victim.add_buff(Frozen.new())
	t.check(victim.paralysed == 1, "frozen target is paralysed")
	victim.remove_buff(frozen)

	t.check(victim.paralysed == 0, "thawed target is no longer paralysed")
	var chill: Chill = victim.get_buff("Chill") as Chill
	t.check(chill != null, "thawing in water applies Chill")
	t.check(
		chill != null and is_equal_approx(chill.left, Chill.DURATION / 2.0),
		"water-thaw chill lasts Chill.DURATION/2 turns"
	)
	victim.free()


func _test_dry_detach_no_chill(t: Object) -> void:
	var level := FakeLevel.new()
	var victim := Char.new()
	victim.name = "DryThawTarget"
	victim.pos = ConstantsData.xy_to_pos(12, 12)
	victim.level = level

	var frozen: Node = victim.add_buff(Frozen.new())
	victim.remove_buff(frozen)

	t.check(
		victim.get_buff("Chill") == null,
		"thawing on dry land applies no Chill"
	)
	victim.free()
