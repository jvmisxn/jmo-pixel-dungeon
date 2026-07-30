extends RefCounted
## Mimic upstream parity (Mimic.java): setLevel-driven stats, EXP 0, DEMONIC,
## spawnAt keeps the heap item AND adds a generate_prize reward, and death
## drops every stored item (no invented extra gold).


func run(t: Object) -> void:
	var level := RegularLevel.new()
	level.depth = 12
	var pos: int = ConstantsData.xy_to_pos(12, 12)
	var prize: Item = Generator.create_item("healing")

	var mimic: Mimic = level._spawn_mimic_with_item(pos, prize, level.depth)

	t.check(mimic != null, "regular level can spawn a mimic from a generated prize")
	t.check(level.mobs.has(mimic), "spawned mimic is added to the level mob list")
	t.check(mimic != null and mimic.pos == pos, "spawned mimic keeps the heap position")

	# Upstream adjustStats(12): HP/HT (1+12)*6, def 2+12/2, atk 6+12,
	# damage 13..26, dr bonus armor 1+12/2, EXP 0.
	t.check(mimic != null and mimic.mimic_level == 12, "mimic level tracks the spawn depth")
	t.check(mimic != null and mimic.hp_max == 78, "mimic HT is (1+level)*6")
	t.check(mimic != null and mimic.hp == 78, "mimic spawns at full HP")
	t.check(mimic != null and mimic.defense_skill == 8, "mimic defense skill is 2 + level/2")
	t.check(mimic != null and mimic.attack_skill == 18, "mimic attack skill is 6 + level")
	t.check(
		mimic != null and mimic.damage_roll_min == 13 and mimic.damage_roll_max == 26,
		"mimic damage roll is 1+level .. 2+2*level"
	)
	t.check(mimic != null and mimic.armor_value == 7, "mimic dr bonus is 0..1+level/2")
	t.check(mimic != null and mimic.xp_value == 0, "mimic grants no experience (upstream EXP 0)")
	t.check(
		mimic != null and mimic._properties.has("DEMONIC"),
		"mimic carries the DEMONIC property"
	)

	# spawnAt parity: heap item preserved plus one generated prize reward.
	t.check(
		mimic != null
				and mimic.stored_items.size() == 2
				and mimic.stored_items[0] == prize,
		"spawned mimic stores the heap item plus a generated prize reward"
	)

	# Serialization round-trips the level so dr/damage stay correct after load.
	if mimic != null:
		var data: Dictionary = mimic.serialize()
		var loaded: Mimic = Mimic.new()
		loaded.deserialize(data)
		t.check(loaded.mimic_level == 12, "mimic_level survives serialize/deserialize")
		t.check(loaded.disguised == mimic.disguised, "disguised flag round-trips")

	if mimic != null:
		var stored_count: int = mimic.stored_items.size()
		mimic._on_death(null)
		var dropped_prize: bool = false
		t.check(
			level.heaps.size() >= stored_count,
			"mimic drops every stored item on death"
		)
		for heap: Dictionary in level.heaps:
			var item: Item = heap.get("item") as Item
			if item == prize:
				dropped_prize = true
		t.check(dropped_prize, "mimic drops its stored heap item on death")
		if is_instance_valid(mimic):
			mimic.free()
