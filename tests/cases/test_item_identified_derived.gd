extends RefCounted
## Item.identified is a computed property deriving from level_known + cursed_known.
## Covers:
##   - identified never drifts from its two canonical flags
##   - setting identified=true via direct assignment syncs both flags
##   - identify() sets both flags and identified returns true
##   - deserialized items with old "identified" key are backward-compatible
##   - serialize() no longer stores a redundant "identified" key


func run(t: Object) -> void:
	_test_identified_derives_from_flags(t)
	_test_set_identified_true_syncs_flags(t)
	_test_identify_method(t)
	_test_flags_set_directly(t)
	_test_no_desync_possible(t)
	_test_serialize_no_identified_key(t)
	_test_deserialize_old_save_compat(t)
	_test_deserialize_level_known_cursed_known(t)


func _make_item(id: String = "test_item") -> Item:
	var it := Item.new()
	it.item_id = id
	it.item_name = "Test Item"
	return it


func _test_identified_derives_from_flags(t: Object) -> void:
	var it := _make_item()
	t.assert_true(not it.identified, "fresh item not identified")
	t.assert_true(not it.level_known, "fresh level_known=false")
	t.assert_true(not it.cursed_known, "fresh cursed_known=false")

	it.level_known = true
	t.assert_true(not it.identified, "identified false when only level_known true")

	it.cursed_known = true
	t.assert_true(it.identified, "identified true when both flags true")


func _test_set_identified_true_syncs_flags(t: Object) -> void:
	var it := _make_item()
	it.identified = true
	t.assert_true(it.level_known, "level_known synced after identified=true")
	t.assert_true(it.cursed_known, "cursed_known synced after identified=true")
	t.assert_true(it.identified, "identified reads true after assignment")


func _test_identify_method(t: Object) -> void:
	var it := _make_item()
	it.identify()
	t.assert_true(it.level_known, "identify() sets level_known")
	t.assert_true(it.cursed_known, "identify() sets cursed_known")
	t.assert_true(it.identified, "identified computed true after identify()")
	t.assert_true(it.is_identified(), "is_identified() true after identify()")


func _test_flags_set_directly(t: Object) -> void:
	var it := _make_item()
	it.level_known = true
	it.cursed_known = true
	# Both the property and the method should agree
	t.assert_true(it.identified == it.is_identified(), "identified == is_identified() always")
	t.assert_true(it.identified, "identified true when both flags set directly")


func _test_no_desync_possible(t: Object) -> void:
	# Historically the stored bool could diverge from the computed result.
	# With the computed property, this is impossible: same expression, single source.
	var it := _make_item()
	for _i in range(10):
		var want: bool = it.level_known and it.cursed_known
		t.assert_true(it.identified == want, "identified always equals level_known and cursed_known")
		it.level_known = not it.level_known
	t.assert_true(
		it.identified == it.is_identified(), "identified == is_identified() after toggle loop"
	)


func _test_serialize_no_identified_key(t: Object) -> void:
	var it := _make_item()
	it.identify()
	var d: Dictionary = it.serialize()
	t.assert_true(not d.has("identified"), "serialize() does not store redundant 'identified' key")
	t.assert_true(d.get("level_known", false), "serialize() stores level_known")
	t.assert_true(d.get("cursed_known", false), "serialize() stores cursed_known")


func _test_deserialize_old_save_compat(t: Object) -> void:
	# Old saves may have "identified":true but no "level_known" key.
	var it := _make_item()
	var old_save: Dictionary = {
		"item_id": "old_sword",
		"item_name": "Sword",
		"description": "",
		"category": 0,
		"level": 2,
		"identified": true,
		"quantity": 1,
		"stackable": false,
		"unique": false,
		"kept_lost": false,
	}
	it.deserialize(old_save)
	t.assert_true(it.level_known, "old save with identified=true sets level_known")
	t.assert_true(it.identified, "old save: identified computed true from level_known")


func _test_deserialize_level_known_cursed_known(t: Object) -> void:
	# Modern saves store level_known and cursed_known separately.
	var it := _make_item()
	var modern_save: Dictionary = {
		"item_id": "test_ring",
		"item_name": "Ring",
		"description": "",
		"category": 0,
		"level": 1,
		"level_known": true,
		"cursed": false,
		"cursed_known": true,
		"quantity": 1,
		"stackable": false,
		"unique": false,
		"kept_lost": false,
	}
	it.deserialize(modern_save)
	t.assert_true(it.level_known, "modern save: level_known restored")
	t.assert_true(it.cursed_known, "modern save: cursed_known restored")
	t.assert_true(it.identified, "modern save: identified computed true")
	t.assert_true(not it.cursed, "modern save: not cursed")
