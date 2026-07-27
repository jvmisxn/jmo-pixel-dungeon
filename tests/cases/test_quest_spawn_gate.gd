extends RefCounted
## QuestHandler depth gate + spawn dispatch share one source of truth
## (QUEST_WINDOWS + _roll_quest_for_depth inside spawn_quest_npc), replacing
## the old duplicated is_quest_depth/spawn_quest_npc depth tables that could
## silently diverge. Original odds: Random.Int(guaranteed_by - depth) == 0
## within each window (33%/50%/100%), guaranteed on the last eligible depth.

func run(t: Object) -> void:
	_test_window_table_shape(t)
	_test_guaranteed_depths_spawn(t)
	_test_off_window_depths_never_spawn(t)
	_test_unavailable_quest_never_spawns(t)
	_test_probabilistic_depth_matches_odds(t)
	_test_one_spawn_marks_active(t)

func _test_window_table_shape(t: Object) -> void:
	t.check(QuestHandler.QUEST_WINDOWS.size() == 4,
		"four quest windows (ghost/wandmaker/blacksmith/imp)")
	var expected: Dictionary = {
		"ghost_quest": [2, 4, 5],
		"wandmaker_quest": [7, 9, 10],
		"blacksmith_quest": [12, 14, 15],
		"imp_quest": [17, 19, 20],
	}
	for window: Dictionary in QuestHandler.QUEST_WINDOWS:
		var id: String = str(window["id"])
		t.check(expected.has(id), "window id %s is a known quest" % id)
		if expected.has(id):
			var vals: Array = expected[id]
			t.check(int(window["min_depth"]) == vals[0]
				and int(window["max_depth"]) == vals[1]
				and int(window["guaranteed_by"]) == vals[2],
				"%s window matches upstream depths %s" % [id, str(vals)])
	# Guaranteed depth = max_depth: randi() % (guaranteed_by - max_depth) is
	# randi() % 1 == 0, always true.
	for window: Dictionary in QuestHandler.QUEST_WINDOWS:
		t.check(int(window["guaranteed_by"]) - int(window["max_depth"]) == 1,
			"%s is guaranteed on its last eligible depth" % str(window["id"]))

func _test_guaranteed_depths_spawn(t: Object) -> void:
	QuestHandler.reset()
	var ghost: Variant = QuestHandler.spawn_quest_npc(null, 4)
	t.check(ghost != null and ghost is SadGhost,
		"depth 4 guarantees the Sad Ghost")
	t.check(QuestHandler.get_quest_status("ghost_quest") == "active",
		"ghost quest active after spawn")
	var wm: Variant = QuestHandler.spawn_quest_npc(null, 9)
	t.check(wm != null and wm is Wandmaker,
		"depth 9 guarantees the Wandmaker")
	var smith: Variant = QuestHandler.spawn_quest_npc(null, 14)
	t.check(smith != null and smith is Blacksmith,
		"depth 14 guarantees the Blacksmith")
	var imp: Variant = QuestHandler.spawn_quest_npc(null, 19)
	t.check(imp != null and imp is AmbImp,
		"depth 19 guarantees the Imp")

func _test_off_window_depths_never_spawn(t: Object) -> void:
	QuestHandler.reset()
	for depth: int in [0, 1, 5, 6, 10, 11, 15, 16, 20, 21, 25]:
		t.check(QuestHandler.spawn_quest_npc(null, depth) == null,
			"depth %d is outside every quest window" % depth)
	t.check(QuestHandler.get_quest_status("ghost_quest") == "inactive",
		"off-window rolls leave quests inactive")

func _test_unavailable_quest_never_spawns(t: Object) -> void:
	QuestHandler.reset()
	QuestHandler.quest_states["ghost_quest"] = "active"
	var spawned := false
	for _i: int in range(30):
		if QuestHandler.spawn_quest_npc(null, 4) != null:
			spawned = true
	t.check(not spawned, "active ghost quest blocks respawn even at depth 4")
	QuestHandler.reset()
	QuestHandler.quest_states["imp_quest"] = "complete"
	t.check(QuestHandler.spawn_quest_npc(null, 19) == null,
		"complete imp quest blocks respawn at its guaranteed depth")

func _test_probabilistic_depth_matches_odds(t: Object) -> void:
	# Depth 2 ghost roll is randi() % 3 == 0 (~33%). Sample the gate roll
	# directly so no NPC state accumulates between samples.
	seed(424242)
	var hits := 0
	var samples := 600
	for _i: int in range(samples):
		QuestHandler.reset()
		if QuestHandler._roll_quest_for_depth(2) == "ghost_quest":
			hits += 1
	t.check(hits > samples / 6 and hits < samples / 2,
		"depth-2 ghost gate lands near 1/3 (%d/%d)" % [hits, samples])

func _test_one_spawn_marks_active(t: Object) -> void:
	QuestHandler.reset()
	var first: Variant = QuestHandler.spawn_quest_npc(null, 4)
	var second: Variant = QuestHandler.spawn_quest_npc(null, 4)
	t.check(first != null and second == null,
		"a spawned quest cannot spawn twice in one run")
