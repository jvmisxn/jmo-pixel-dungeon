extends RefCounted
## Wandmaker rewards from the Generator wand deck + Generator.undo_drop
## (upstream Wandmaker.Quest.spawn / Generator.undoDrop).
## Covers:
##   - undo_drop restores a drawn wand's deck slot exactly (+1)
##   - undo_drop on a non-deck id is a no-op
##   - generate_quest deals two distinct deck wands, uncursed, upgraded once
##     on top of random(), identified (port reward-window adaptation)
##   - reward generation costs exactly 2 net draws from the wand deck even
##     when duplicate rerolls happen (rerolls shuffled back in)


func run(t: Object) -> void:
	_test_undo_drop_restores_slot(t)
	_test_undo_drop_unknown_id_noop(t)
	_test_reward_wands(t)
	_test_net_deck_cost(t)


func _deck_total(cat: String) -> float:
	var total: float = 0.0
	for p: Variant in Generator._item_probs[cat]:
		total += float(p)
	return total


func _test_undo_drop_restores_slot(t: Object) -> void:
	Generator.full_reset()
	var drawn: String = Generator._deck_draw("wand")
	var idx: int = Generator.WANDS.find(drawn)
	var after_draw: float = float(Generator._item_probs["wand"][idx])
	Generator.undo_drop(drawn)
	t.check(float(Generator._item_probs["wand"][idx]) == after_draw + 1.0,
		"undo_drop puts the drawn wand back into its deck slot")
	t.check(_deck_total("wand") == 39.0,
		"undo_drop restores the wand deck to its full 39 total")


func _test_undo_drop_unknown_id_noop(t: Object) -> void:
	Generator.full_reset()
	var before: float = _deck_total("wand")
	Generator.undo_drop("amulet_of_yendor")
	t.check(_deck_total("wand") == before,
		"undo_drop ignores ids that are not in any deck table")


func _make_wandmaker() -> Variant:
	var wm: Variant = load("res://src/actors/npcs/wandmaker.gd").new()
	return wm


func _test_reward_wands(t: Object) -> void:
	Generator.full_reset()
	var wm: Variant = _make_wandmaker()
	wm.generate_quest()
	var a: Variant = wm.wand_choice_a
	var b: Variant = wm.wand_choice_b
	t.check(a != null and b != null, "generate_quest creates both reward wands")
	if a == null or b == null:
		return
	t.check(a.item_id != b.item_id, "reward wands are distinct types")
	t.check(a.item_id in Generator.WANDS and b.item_id in Generator.WANDS,
		"reward wands come from the Generator wand table")
	t.check(not a.cursed and not b.cursed, "reward wands are never cursed")
	t.check(a.level >= 1 and b.level >= 1,
		"reward wands carry the upstream extra upgrade on top of random()")
	t.check(a.identified and b.identified,
		"reward wands are identified for the reward window (port adaptation)")


func _test_net_deck_cost(t: Object) -> void:
	# Whatever the duplicate-reroll count, net deck cost must be exactly 2
	# (every dupe draw gets shuffled back via undo_drop); repeat to catch
	# runs where rerolls actually fire.
	for i: int in range(20):
		Generator.full_reset()
		var wm: Variant = _make_wandmaker()
		wm.generate_quest()
		if _deck_total("wand") != 37.0:
			t.check(false,
				"reward generation costs exactly 2 net wand-deck draws (got %s)"
				% _deck_total("wand"))
			return
	t.check(true, "reward generation always costs exactly 2 net wand-deck draws")
