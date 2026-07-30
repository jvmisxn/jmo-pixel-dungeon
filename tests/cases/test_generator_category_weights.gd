extends RefCounted
## Generator category-deck parity against Shattered Pixel Dungeon's
## Generator.Category: two alternating 35-item category decks (deck 1 has a
## ring + extra armor, deck 2 has an artifact + extra thrown weapon; FOOD is
## 0 in both — each floor drops one guaranteed food item instead), and
## RegularLevel.item_count rolls 3/4/5 items at 60/30/10 (+2 on LARGE).


func run(t: Object) -> void:
	# --- Table shape: FOOD and the port-only MISC never drop randomly ---
	t.check(not Generator.CATEGORY_FIRST_PROBS.has("food"),
		"FOOD has prob 0 upstream so it is absent from both category decks")
	t.check(not Generator.CATEGORY_FIRST_PROBS.has("misc"),
		"port-only MISC fallback is absent from the category decks")

	# --- Deck contents match upstream firstProb/secondProb exactly ---
	var expected_first: Dictionary = {
		"weapon": 2, "armor": 2, "missile": 1, "wand": 1, "ring": 1,
		"artifact": 0, "potion": 8, "seed": 1, "scroll": 8, "stone": 1,
		"gold": 10,
	}
	var expected_second: Dictionary = {
		"weapon": 2, "armor": 1, "missile": 2, "wand": 1, "ring": 0,
		"artifact": 1, "potion": 8, "seed": 1, "scroll": 8, "stone": 1,
		"gold": 10,
	}
	var total_first: int = 0
	var total_second: int = 0
	for cat: String in expected_first:
		t.check(Generator.CATEGORY_FIRST_PROBS.get(cat, -1) == expected_first[cat],
			"deck 1 %s prob matches upstream firstProb" % cat)
		t.check(Generator.CATEGORY_SECOND_PROBS.get(cat, -1) == expected_second[cat],
			"deck 2 %s prob matches upstream secondProb" % cat)
		total_first += expected_first[cat]
		total_second += expected_second[cat]
	t.check(Generator.CATEGORY_FIRST_PROBS.size() == expected_first.size(),
		"deck 1 has exactly the upstream categories")
	t.check(Generator.CATEGORY_SECOND_PROBS.size() == expected_second.size(),
		"deck 2 has exactly the upstream categories")
	t.check(total_first == 35 and total_second == 35,
		"both category decks are 35-item decks")

	# --- random_item never yields food from the category decks ---
	seed(12345)
	Generator.full_reset()
	var got_gold: bool = false
	for i: int in range(200):
		var item: Item = Generator.random_item(3)
		t.check(item != null, "random_item returns an item")
		if item == null:
			continue
		t.check(not item is Food,
			"random_item roll %d is not food (guaranteed floor drop covers food)" % i)
		if item is Gold:
			got_gold = true
	t.check(got_gold, "gold still drops from the category decks (upstream 10/35)")

	# --- item_count distribution: 3/4/5 at 60/30/10, LARGE +2 ---
	var level := RegularLevel.new()
	level.feeling = Level.Feeling.NONE
	var counts: Dictionary = {}
	seed(67890)
	for i: int in range(1000):
		var n: int = level.item_count()
		counts[n] = counts.get(n, 0) + 1
	t.check(counts.keys().size() == 3 and counts.has(3) and counts.has(4) and counts.has(5),
		"item_count only rolls 3, 4, or 5 on normal levels")
	t.check(counts.get(3, 0) > counts.get(4, 0) and counts.get(4, 0) > counts.get(5, 0),
		"item_count frequencies rank 3 > 4 > 5 matching 60/30/10")

	level.feeling = Level.Feeling.LARGE
	seed(24680)
	for i: int in range(200):
		var n_large: int = level.item_count()
		t.check(n_large >= 5 and n_large <= 7, "LARGE levels roll 5-7 items (+2)")
