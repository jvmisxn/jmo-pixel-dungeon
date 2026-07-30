extends RefCounted
## Per-tier equipment decks (upstream Generator WEP_T*/MIS_T* defaultProbs).
## Covers:
##   - a wep_t1 deck cycle deals each tier-1 weapon exactly twice, never
##     the prob-0 Mage's Staff slot, across consecutive refills
##   - a wep_t4 deck cycle deals each tier-4 weapon exactly twice
##   - a mis_t1 deck cycle deals each tier-1 missile exactly 3 times and
##     never the prob-0 dart slot
##   - a mis_t5 deck cycle deals each tier-5 missile exactly 3 times
##   - tier deck state survives a serialize/restore round trip mid-deck
##   - random_weapon returns only known melee ids (deck-backed public path)


func run(t: Object) -> void:
	_test_wep_t1_cycle(t)
	_test_wep_t4_cycle(t)
	_test_mis_t1_cycle(t)
	_test_mis_t5_single(t)
	_test_serialize_round_trip(t)
	_test_random_weapon_public(t)


func _draw_counts(cat: String, n: int) -> Dictionary:
	var counts: Dictionary = {}
	for i: int in range(n):
		var id: String = Generator._deck_draw(cat)
		counts[id] = counts.get(id, 0) + 1
	return counts


func _is_uniform(counts: Dictionary, ids: Array, per: int) -> bool:
	if counts.size() != ids.size():
		return false
	for id: Variant in ids:
		if counts.get(id, 0) != per:
			return false
	return true


func _test_wep_t1_cycle(t: Object) -> void:
	Generator.full_reset()
	var expected: Array[String] = [
		"worn_shortsword", "cudgel", "gloves", "rapier", "dagger",
	]
	var first: Dictionary = _draw_counts("wep_t1", 10)
	t.check(_is_uniform(first, expected, 2),
		"wep_t1 deck deals each tier-1 weapon exactly twice per cycle")
	t.check(not first.has("mages_staff"),
		"wep_t1 deck never deals the prob-0 mages_staff slot")
	var second: Dictionary = _draw_counts("wep_t1", 10)
	t.check(_is_uniform(second, expected, 2) and not second.has("mages_staff"),
		"wep_t1 refill restores the same deck with mages_staff still at 0")


func _test_wep_t4_cycle(t: Object) -> void:
	Generator.full_reset()
	var counts: Dictionary = _draw_counts("wep_t4", 10)
	t.check(_is_uniform(counts, Generator.WEAPONS_T4, 2),
		"wep_t4 deck deals each tier-4 weapon exactly twice per cycle")


func _test_mis_t1_cycle(t: Object) -> void:
	Generator.full_reset()
	var expected: Array[String] = [
		"throwing_stone", "throwing_knife", "throwing_spike",
	]
	var counts: Dictionary = _draw_counts("mis_t1", 9)
	t.check(_is_uniform(counts, expected, 3),
		"mis_t1 deck deals each tier-1 missile exactly 3 times per cycle")
	t.check(not counts.has("dart"),
		"mis_t1 deck never deals the prob-0 dart slot")


func _test_mis_t5_single(t: Object) -> void:
	Generator.full_reset()
	var counts: Dictionary = _draw_counts("mis_t5", 9)
	t.check(_is_uniform(counts, Generator.MISSILES_T5, 3),
		"mis_t5 deck deals each tier-5 missile exactly 3 times per cycle")


func _test_serialize_round_trip(t: Object) -> void:
	Generator.full_reset()
	for i: int in range(3):
		Generator._deck_draw("wep_t3")
	var saved: Dictionary = Generator.serialize_decks()
	var drained_a: Dictionary = _draw_counts("wep_t3", 7)
	Generator.restore_decks(saved)
	var drained_b: Dictionary = _draw_counts("wep_t3", 7)
	var same: bool = drained_a.size() == drained_b.size()
	for id: Variant in drained_a:
		if drained_a[id] != drained_b.get(id, 0):
			same = false
	t.check(same,
		"restored wep_t3 deck drains the same remaining multiset as the saved one")


func _test_random_weapon_public(t: Object) -> void:
	Generator.full_reset()
	var all_known: bool = true
	for i: int in range(20):
		var w: Item = Generator.random_weapon(1)
		if w == null or not Generator._MELEE_IDS.has(w.item_id):
			all_known = false
	t.check(all_known,
		"random_weapon(depth 1) always returns a known melee weapon id")
