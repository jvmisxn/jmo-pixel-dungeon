extends RefCounted
## Generator category-deck parity against Shattered Pixel Dungeon's
## Generator.Category: the random-drop table matches upstream's two 35-item
## decks averaged (GOLD 10, POTION 8, SCROLL 8, WEAPON 2 + MISSILE 1.5,
## ARMOR 1.5, WAND 1, SEED 1, STONE 1, RING 0.5, ARTIFACT 0.5, FOOD 0),
## and RegularLevel.item_count rolls 3/4/5 items at 60/30/10 (+2 on LARGE).


func run(t: Object) -> void:
	# --- Table shape: FOOD and MISC are no longer random categories ---
	t.check(not Generator.CATEGORY_WEIGHTS.has(ConstantsData.ItemCategory.FOOD),
		"FOOD has weight 0 upstream so it is absent from the random table")
	t.check(not Generator.CATEGORY_WEIGHTS.has(ConstantsData.ItemCategory.MISC),
		"port-only MISC fallback is absent from the random table")

	# --- Weights match upstream averaged decks doubled (total 70) ---
	var expected: Dictionary = {
		ConstantsData.ItemCategory.GOLD: 20,
		ConstantsData.ItemCategory.POTION: 16,
		ConstantsData.ItemCategory.SCROLL: 16,
		ConstantsData.ItemCategory.WEAPON: 7,
		ConstantsData.ItemCategory.ARMOR: 3,
		ConstantsData.ItemCategory.WAND: 2,
		ConstantsData.ItemCategory.SEED: 2,
		ConstantsData.ItemCategory.STONE: 2,
		ConstantsData.ItemCategory.RING: 1,
		ConstantsData.ItemCategory.ARTIFACT: 1,
	}
	t.check(Generator.CATEGORY_WEIGHTS.size() == expected.size(),
		"random table has exactly the upstream categories")
	var total: int = 0
	for cat: ConstantsData.ItemCategory in expected:
		var w: int = Generator.CATEGORY_WEIGHTS.get(cat, -1)
		t.check(w == expected[cat],
			"category %d weight %d matches upstream ratio" % [cat, expected[cat]])
		total += w
	t.check(total == 70, "weights sum to the doubled 35-item deck size")

	# --- random_item never yields food from the weighted table ---
	seed(12345)
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
	t.check(got_gold, "gold still drops from the random table (upstream 10/35)")

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
