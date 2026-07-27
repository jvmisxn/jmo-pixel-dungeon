extends RefCounted
## Artifact uniqueness must survive save/load (audit:S12). The static
## Generator._generated_artifacts set was never serialized and
## reset_artifacts() was never called, so a mid-run save/load regenerated
## already-found artifacts as duplicates and uniqueness state leaked across
## runs within one app session. Upstream persists this in
## Generator.storeInBundle ("spawned_artifacts") and resets on Dungeon.init.

func run(t: Object) -> void:
	_test_serialize_round_trip(t)
	_test_restore_filters_unknown_ids(t)
	_test_random_artifact_respects_restored_set(t)
	_test_reset_clears(t)

func _test_serialize_round_trip(t: Object) -> void:
	Generator.reset_artifacts()
	Generator.restore_artifacts(["dried_rose", "horn_of_plenty"])
	var out: Array = Generator.serialize_artifacts()
	t.check(out.size() == 2 and "dried_rose" in out and "horn_of_plenty" in out,
		"serialize returns restored artifact ids")
	Generator.restore_artifacts(out)
	t.check(Generator.serialize_artifacts() == out,
		"serialize -> restore -> serialize is identity")

func _test_restore_filters_unknown_ids(t: Object) -> void:
	Generator.restore_artifacts(["dried_rose", "not_an_artifact", "dried_rose", 7])
	var out: Array = Generator.serialize_artifacts()
	t.check(out == ["dried_rose"],
		"restore drops unknown ids and duplicates")

func _test_random_artifact_respects_restored_set(t: Object) -> void:
	# Mark every artifact except one as already generated; random_artifact
	# must return the remaining one, then fall back to a ring.
	var all_but_one: Array = []
	for art_id: String in Generator.ARTIFACTS:
		if art_id != "unstable_spellbook":
			all_but_one.append(art_id)
	Generator.restore_artifacts(all_but_one)
	var item: Item = Generator.random_artifact()
	t.check(item != null and item.item_id == "unstable_spellbook",
		"random_artifact only generates the artifact missing from the restored set")
	var fallback: Item = Generator.random_artifact()
	t.check(fallback != null and fallback.item_id != "unstable_spellbook",
		"after all artifacts generated, random_artifact falls back (no duplicate)")

func _test_reset_clears(t: Object) -> void:
	Generator.restore_artifacts(["dried_rose"])
	Generator.reset_artifacts()
	t.check(Generator.serialize_artifacts().is_empty(),
		"reset_artifacts clears persisted state (new-run path)")
