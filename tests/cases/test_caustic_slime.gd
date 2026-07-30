extends RefCounted
## Caustic slime rare-alt parity (upstream CausticSlime.java + MobSpawner
## RARE_ALTS): 1/50 swap from slime, inherits slime stats, ACIDIC (immune to
## Ooze), 1/2 chance to coat the victim in caustic ooze on hit. Also guards
## the base Slime name fix (it was mislabeled "Caustic Slime").

func run(t: Object) -> void:
	_test_rare_alt_swap(t)
	_test_not_in_tables(t)
	_test_stats_and_names(t)
	_test_ooze_proc(t)
	_test_ooze_immunity(t)
	_test_factory_creates(t)


func _test_rare_alt_swap(t: Object) -> void:
	t.check(MobFactory.apply_rare_alt("slime", 0.0) == "caustic_slime",
		"Winning roll swaps slime -> caustic_slime")
	t.check(MobFactory.apply_rare_alt("slime", 0.5) == "slime",
		"Losing roll keeps the base slime")


func _test_not_in_tables(t: Object) -> void:
	# Upstream: caustic slime spawns only via the 1/50 swap.
	for depth: int in range(1, 25):
		for entry: Dictionary in MobFactory.get_mob_table(depth):
			t.check(entry["mob_id"] != "caustic_slime",
				"Depth %d table has no direct caustic_slime entry" % depth)


func _test_stats_and_names(t: Object) -> void:
	var caustic := CausticSlime.new()
	t.check(caustic is Slime, "CausticSlime extends Slime")
	t.check(caustic.mob_id == "caustic_slime", "CausticSlime mob_id")
	t.check(caustic.mob_name == "Caustic Slime", "CausticSlime display name")
	t.check(caustic.hp == 20 and caustic.hp_max == 20,
		"CausticSlime inherits slime HP 20 (upstream)")
	t.check((caustic.get("_properties") as Array).has("ACIDIC"),
		"CausticSlime is ACIDIC")
	t.check(caustic.description.contains("tainted by the dark magic"),
		"CausticSlime has its upstream description")
	var base := Slime.new()
	t.check(base.mob_name == "Slime",
		"Base slime is named Slime (was mislabeled Caustic Slime)")


func _test_ooze_proc(t: Object) -> void:
	var caustic := CausticSlime.new()
	var victim := Rat.new()
	caustic.apply_ooze(victim)
	var ooze: Ooze = victim.get_buff("Ooze") as Ooze
	t.check(ooze != null, "apply_ooze attaches Ooze to the victim")
	if ooze != null:
		t.check(ooze.left == Ooze.DURATION,
			"Ooze set to upstream DURATION (20)")


func _test_ooze_immunity(t: Object) -> void:
	var caustic := CausticSlime.new()
	t.check(caustic.is_immune("Ooze"), "CausticSlime is immune to Ooze")
	var ooze := Ooze.new()
	ooze.set_duration_value(Ooze.DURATION)
	caustic.add_buff(ooze)
	t.check(caustic.get_buff("Ooze") == null,
		"Ooze cannot attach to a caustic slime")


func _test_factory_creates(t: Object) -> void:
	var mob: Mob = MobFactory.create_mob("caustic_slime")
	t.check(mob != null and mob is CausticSlime,
		"MobFactory builds caustic_slime by id")
