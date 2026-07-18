extends RefCounted
## Blacksmith quest reachability: the Troll Blacksmith wants 15 dark gold ore,
## and this port sources it from Caves bats. This proves the chain end to end —
## the ore is a real stackable item, bats carry it in their loot table and drop
## it via the mob loot pipeline, Belongings pools it, and the blacksmith can
## count and consume the required amount.


func run(t: Object) -> void:
	_test_ore_is_real_stackable_item(t)
	_test_belongings_pool_and_consume(t)
	_test_bat_loot_table_carries_ore(t)
	_test_bat_drops_ore_on_death(t)
	_test_blacksmith_counts_and_takes_ore(t)


## Minimal Level stand-in that records dropped items at their cell.
class StubLevel:
	extends RefCounted
	var drops: Array = []  # [{pos, item}]
	func drop_item(pos: int, item: Variant, _heap_type: String = "heap") -> Dictionary:
		drops.append({"pos": pos, "item": item})
		return {}


## Minimal hero stand-in exposing the fields the blacksmith reads via get().
class StubHero:
	extends RefCounted
	var is_hero: bool = true
	var belongings: Belongings = Belongings.new()


func _test_ore_is_real_stackable_item(t: Object) -> void:
	var ore: Item = Generator.create_item("dark_gold_ore")
	t.check(ore != null, "generator produces a dark gold ore item")
	t.check(ore.item_id == "dark_gold_ore", "ore keeps its canonical id")
	t.check(ore.stackable, "ore is stackable so multiple drops pool")
	t.check(ore.identified, "ore is pre-identified — no random appearance")
	t.check(ore.category == ConstantsData.ItemCategory.MISC, "ore is a MISC material")


func _test_belongings_pool_and_consume(t: Object) -> void:
	var b: Belongings = Belongings.new()
	for _i: int in range(15):
		b.add_item(Generator.create_item("dark_gold_ore"))
	t.check(b.count_item("dark_gold_ore") == 15, "15 dropped ores pool to a count of 15")

	var backpack_ore_slots: int = 0
	for item: Item in b.backpack:
		if item.item_id == "dark_gold_ore":
			backpack_ore_slots += 1
	t.check(backpack_ore_slots == 1, "ore merges into a single stacked slot")

	var removed: int = b.remove_item_quantity("dark_gold_ore", 15)
	t.check(removed == 15, "the full quota can be removed at once")
	t.check(b.count_item("dark_gold_ore") == 0, "no ore remains after handoff")


func _test_bat_loot_table_carries_ore(t: Object) -> void:
	var bat: Bat = Bat.new()
	var has_ore_entry: bool = false
	for entry: Dictionary in bat.loot_table:
		if entry.get("item_id", "") == "dark_gold_ore" and entry.get("chance", 0.0) > 0.0:
			has_ore_entry = true
	t.check(has_ore_entry, "bats list dark gold ore with a positive drop chance")


func _test_bat_drops_ore_on_death(t: Object) -> void:
	# Drive the real mob loot pipeline deterministically: force the ore chance to
	# 1.0 so _drop_loot must place ore into the level.
	var bat: Bat = Bat.new()
	var level: StubLevel = StubLevel.new()
	bat.level = level
	bat.pos = ConstantsData.xy_to_pos(16, 16)
	bat.loot_table = [{"item_id": "dark_gold_ore", "chance": 1.0}]
	bat._drop_loot()

	t.check(level.drops.size() == 1, "a guaranteed roll drops exactly one heap")
	if level.drops.size() == 1:
		var dropped: Item = level.drops[0]["item"] as Item
		t.check(dropped != null and dropped.item_id == "dark_gold_ore", "the dropped item is dark gold ore")
		t.check(level.drops[0]["pos"] == bat.pos, "ore drops at the bat's position")


func _test_blacksmith_counts_and_takes_ore(t: Object) -> void:
	var smith: Blacksmith = Blacksmith.new()
	var hero: StubHero = StubHero.new()
	for _i: int in range(Blacksmith.REQUIRED_ORE):
		hero.belongings.add_item(Generator.create_item("dark_gold_ore"))

	t.check(smith._count_ore(hero) == Blacksmith.REQUIRED_ORE, "blacksmith counts the delivered ore")

	smith._take_ore(hero)
	t.check(hero.belongings.count_item("dark_gold_ore") == 0, "blacksmith consumes the required ore")
	t.check(smith._count_ore(hero) == 0, "no ore remains for a second turn-in")
