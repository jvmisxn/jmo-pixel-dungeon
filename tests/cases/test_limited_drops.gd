extends RefCounted
## Guaranteed strength-potion / scroll-of-upgrade region quotas against
## Shattered Pixel Dungeon's Dungeon.posNeeded()/souNeeded(): 2 PoS and
## 3 SoU per 5-floor set, tracked by persisted LimitedDrops counters and
## spawned by Level.create() during regular level generation.


func run(t: Object) -> void:
	var prev_depth: int = GameManager.depth
	var prev_limited: Dictionary = GameManager.limited_drops.duplicate(true)
	GameManager.limited_drops.clear()

	# --- Last floor of region 1 with nothing dropped: both guaranteed ---
	GameManager.depth = 4
	for i: int in range(20):
		t.check(GameManager.pos_needed(),
			"depth 4 with 0 PoS dropped always needs a strength potion")
		t.check(GameManager.sou_needed(),
			"depth 4 with 0 SoU dropped always needs an upgrade scroll")

	# --- Region-1 quotas met: never drops more this region ---
	GameManager.limited_drops["strength_potions"] = 2
	GameManager.limited_drops["upgrade_scrolls"] = 3
	for depth: int in range(1, 5):
		GameManager.depth = depth
		for i: int in range(20):
			t.check(not GameManager.pos_needed(),
				"depth %d with region quota met drops no extra PoS" % depth)
			t.check(not GameManager.sou_needed(),
				"depth %d with region quota met drops no extra SoU" % depth)

	# --- Region 2 resets the quota: depth 9 with only region-1 drops ---
	GameManager.depth = 9
	for i: int in range(20):
		t.check(GameManager.pos_needed(),
			"depth 9 with region-2 quota untouched needs a strength potion")
		t.check(GameManager.sou_needed(),
			"depth 9 with region-2 quota untouched needs an upgrade scroll")

	# --- Overfull counters (both regions satisfied) block region 2 too ---
	GameManager.limited_drops["strength_potions"] = 4
	GameManager.limited_drops["upgrade_scrolls"] = 6
	for i: int in range(20):
		t.check(not GameManager.pos_needed(),
			"depth 9 with both region quotas met drops no extra PoS")
		t.check(not GameManager.sou_needed(),
			"depth 9 with both region quotas met drops no extra SoU")

	# --- Depth 1 is probabilistic: PoS 50% early roll, SoU 3-in-4 ---
	GameManager.limited_drops.clear()
	GameManager.depth = 1
	seed(13579)
	var pos_hits: int = 0
	var sou_hits: int = 0
	for i: int in range(200):
		if GameManager.pos_needed():
			pos_hits += 1
		if GameManager.sou_needed():
			sou_hits += 1
	t.check(pos_hits > 40 and pos_hits < 160,
		"depth-1 PoS matches the upstream 50%% early-floor roll (%d/200)" % pos_hits)
	t.check(sou_hits > 100 and sou_hits < 200,
		"depth-1 SoU matches the upstream 3-in-4 chance (%d/200)" % sou_hits)

	# --- count_limited_drop + run-state persistence round trip ---
	GameManager.limited_drops.clear()
	GameManager.count_limited_drop("strength_potions")
	GameManager.count_limited_drop("upgrade_scrolls")
	GameManager.count_limited_drop("upgrade_scrolls")
	t.check(GameManager.get_limited_drop_count("strength_potions") == 1,
		"count_limited_drop increments the PoS counter")
	t.check(GameManager.get_limited_drop_count("upgrade_scrolls") == 2,
		"count_limited_drop increments the SoU counter")
	var state: Dictionary = GameManager.serialize_run_state()
	GameManager.limited_drops.clear()
	GameManager.apply_run_state(state)
	t.check(GameManager.get_limited_drop_count("strength_potions") == 1,
		"limited_drops PoS count survives a run-state round trip")
	t.check(GameManager.get_limited_drop_count("upgrade_scrolls") == 2,
		"limited_drops SoU count survives a run-state round trip")
	t.check(GameManager.get_limited_drop_count("unknown") == 0,
		"unknown limited-drop keys default to zero")

	# --- Missing key (pre-v5 save) defaults to empty counters ---
	var legacy_state: Dictionary = state.duplicate(true)
	legacy_state.erase("limited_drops")
	GameManager.apply_run_state(legacy_state)
	t.check(GameManager.limited_drops.is_empty(),
		"run state without limited_drops loads as zero counts")

	# --- Restore prior state ---
	GameManager.depth = prev_depth
	GameManager.limited_drops.clear()
	for key: Variant in prev_limited:
		GameManager.limited_drops[str(key)] = int(prev_limited[key])
