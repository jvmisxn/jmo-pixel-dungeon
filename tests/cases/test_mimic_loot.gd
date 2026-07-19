extends RefCounted
## Mimics should keep the generated prize item they replace and drop it on death.
## This matches SPD's risk/reward chest behavior instead of silently deleting loot.


func run(t: Object) -> void:
	var level := RegularLevel.new()
	level.depth = 12
	var pos: int = ConstantsData.xy_to_pos(12, 12)
	var prize: Item = Generator.create_item("healing")

	var mimic: Mimic = level._spawn_mimic_with_item(pos, prize, level.depth)

	t.check(mimic != null, "regular level can spawn a mimic from a generated prize")
	t.check(level.mobs.has(mimic), "spawned mimic is added to the level mob list")
	t.check(mimic != null and mimic.pos == pos, "spawned mimic keeps the heap position")
	t.check(
		mimic != null and mimic.hp_max > 25,
		"spawned mimic scales its stats to the floor depth"
	)
	t.check(
		mimic != null
				and mimic.stored_items.size() == 1
				and mimic.stored_items[0] == prize,
		"spawned mimic stores the generated prize item"
	)

	if mimic != null:
		mimic._on_death(null)
		var dropped_prize: bool = false
		for heap: Dictionary in level.heaps:
			var item: Item = heap.get("item") as Item
			if item == prize:
				dropped_prize = true
		t.check(dropped_prize, "mimic drops its stored prize item on death")
		if is_instance_valid(mimic):
			mimic.free()
