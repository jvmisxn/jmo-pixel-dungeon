extends RefCounted
## Generator deck system (upstream Generator probs/defaultProbs/fullReset).
## Covers:
##   - a full potion deck cycle deals exactly one deck's contents
##   - the next potion cycle comes from the alternate deck (using2ndProbs flip)
##   - scroll decks never deal upgrade and deal exactly 3 identify per cycle
##   - the food deck deals exactly 4 rations + 1 pasty per 5 draws, no meat
##   - the wand deck deals every wand exactly 3 times per cycle
##   - the category deck deals exactly one 35-item deck then swaps
##   - random_seed_id never returns rotberry and respects default weights
##   - deck state survives a serialize/restore round trip
##   - restoring empty data falls back to fresh full decks

const POTION_DECK_1_COUNTS: Dictionary = {
	"healing": 3, "mind_vision": 2, "frost": 1, "liquid_flame": 2,
	"toxic_gas": 1, "haste": 1, "invisibility": 1, "levitation": 1,
	"paralytic_gas": 1, "purity": 1, "experience": 1,
}
const POTION_DECK_2_COUNTS: Dictionary = {
	"healing": 3, "mind_vision": 2, "frost": 2, "liquid_flame": 1,
	"toxic_gas": 2, "haste": 1, "invisibility": 1, "levitation": 1,
	"paralytic_gas": 1, "purity": 1,
}


func run(t: Object) -> void:
	_test_potion_deck_cycle(t)
	_test_scroll_deck_cycle(t)
	_test_food_deck(t)
	_test_wand_deck(t)
	_test_category_deck(t)
	_test_seed_defaults(t)
	_test_serialize_round_trip(t)
	_test_restore_empty_resets(t)


func _draw_potion_counts(n: int) -> Dictionary:
	var counts: Dictionary = {}
	for i: int in range(n):
		var item: Item = Generator.random_potion()
		counts[item.item_id] = counts.get(item.item_id, 0) + 1
	return counts


func _matches(counts: Dictionary, expected: Dictionary) -> bool:
	if counts.size() != expected.size():
		return false
	for id: Variant in expected:
		if counts.get(id, 0) != expected[id]:
			return false
	return true


func _test_potion_deck_cycle(t: Object) -> void:
	Generator.full_reset()
	var first: Dictionary = _draw_potion_counts(15)
	var first_is_deck1: bool = _matches(first, POTION_DECK_1_COUNTS)
	var first_is_deck2: bool = _matches(first, POTION_DECK_2_COUNTS)
	t.check(first_is_deck1 or first_is_deck2,
		"15 potion draws deal exactly one full potion deck")
	var second: Dictionary = _draw_potion_counts(15)
	if first_is_deck1:
		t.check(_matches(second, POTION_DECK_2_COUNTS),
			"second potion cycle comes from deck 2 after deck 1")
	elif first_is_deck2:
		t.check(_matches(second, POTION_DECK_1_COUNTS),
			"second potion cycle comes from deck 1 after deck 2")
	var third: Dictionary = _draw_potion_counts(15)
	t.check(_matches(third, first),
		"third potion cycle flips back to the first deck")


func _test_scroll_deck_cycle(t: Object) -> void:
	Generator.full_reset()
	var counts: Dictionary = {}
	for i: int in range(30):
		var item: Item = Generator.random_scroll()
		counts[item.item_id] = counts.get(item.item_id, 0) + 1
	t.check(not counts.has("upgrade"),
		"scroll decks never deal Scroll of Upgrade (quota-placed)")
	t.check(counts.get("identify", 0) == 6,
		"two scroll cycles deal exactly 3 identify each")
	t.check(counts.get("transmutation", 0) == 1,
		"two scroll cycles deal exactly 1 transmutation (deck 1 only)")


func _test_food_deck(t: Object) -> void:
	Generator.full_reset()
	var counts: Dictionary = {}
	for i: int in range(10):
		var item: Item = Generator.random_food()
		counts[item.item_id] = counts.get(item.item_id, 0) + 1
	t.check(counts.get("ration", 0) == 8 and counts.get("pasty", 0) == 2,
		"two food cycles deal exactly 4 rations + 1 pasty each")
	t.check(not counts.has("mystery_meat"),
		"the food deck never deals mystery meat (prob 0 upstream)")


func _test_wand_deck(t: Object) -> void:
	Generator.full_reset()
	var counts: Dictionary = {}
	for i: int in range(39):
		var item: Item = Generator.random_wand()
		counts[item.item_id] = counts.get(item.item_id, 0) + 1
	t.check(counts.size() == Generator.WANDS.size(),
		"a full wand cycle deals every wand type")
	var all_three: bool = true
	for wand_id: Variant in counts:
		if counts[wand_id] != 3:
			all_three = false
	t.check(all_three, "each wand appears exactly 3 times per 39-draw cycle")


func _test_category_deck(t: Object) -> void:
	Generator.full_reset()
	var counts: Dictionary = {}
	for i: int in range(35):
		var cat: String = Generator._pick_category()
		counts[cat] = counts.get(cat, 0) + 1
	var is_first: bool = _matches_nonzero(counts, Generator.CATEGORY_FIRST_PROBS)
	var is_second: bool = _matches_nonzero(counts, Generator.CATEGORY_SECOND_PROBS)
	t.check(is_first or is_second,
		"35 category picks deal exactly one full category deck")
	var second_counts: Dictionary = {}
	for i: int in range(35):
		var cat: String = Generator._pick_category()
		second_counts[cat] = second_counts.get(cat, 0) + 1
	if is_first:
		t.check(_matches_nonzero(second_counts, Generator.CATEGORY_SECOND_PROBS),
			"the category deck swaps to deck 2 when deck 1 empties")
	elif is_second:
		t.check(_matches_nonzero(second_counts, Generator.CATEGORY_FIRST_PROBS),
			"the category deck swaps to deck 1 when deck 2 empties")


func _matches_nonzero(counts: Dictionary, expected: Dictionary) -> bool:
	for cat: Variant in expected:
		var want: int = int(expected[cat])
		if counts.get(cat, 0) != want:
			return false
	return true


func _test_seed_defaults(t: Object) -> void:
	var counts: Dictionary = {}
	for i: int in range(300):
		var seed_id: String = Generator.random_seed_id()
		counts[seed_id] = counts.get(seed_id, 0) + 1
	t.check(not counts.has("seed_of_rotberry"),
		"rotberry (quest seed) never comes from random seed draws")
	t.check(counts.get("seed_of_sungrass", 0) > 0,
		"common seeds appear in random draws")


func _test_serialize_round_trip(t: Object) -> void:
	Generator.full_reset()
	for i: int in range(7):
		Generator.random_potion()
	for i: int in range(4):
		Generator.random_scroll()
	Generator._pick_category()
	Generator._pick_category()
	var snapshot: Dictionary = Generator.serialize_decks()
	# Mutate live state, then restore the snapshot.
	for i: int in range(5):
		Generator.random_potion()
		Generator.random_wand()
	Generator._pick_category()
	Generator.restore_decks(snapshot)
	var after: Dictionary = Generator.serialize_decks()
	t.check(str(after) == str(snapshot),
		"deck state survives a serialize/restore round trip")


func _test_restore_empty_resets(t: Object) -> void:
	Generator.full_reset()
	for i: int in range(10):
		Generator.random_potion()
	Generator.restore_decks({})
	var counts: Dictionary = _draw_potion_counts(15)
	t.check(_matches(counts, POTION_DECK_1_COUNTS)
		or _matches(counts, POTION_DECK_2_COUNTS),
		"restoring empty deck data falls back to fresh full decks")
