extends RefCounted
## Rare mob variant parity (upstream MobSpawner.swapMobAlts + Albino.java):
## every rolled standard mob has a 1/50 chance to swap for its rare alt,
## and the Albino rat exists with upstream stats (HP 12, EXP 2, guaranteed
## mystery meat, bleed on hit).

func run(t: Object) -> void:
	_test_rare_alt_swap(t)
	_test_alts_not_in_tables(t)
	_test_albino_stats(t)
	_test_albino_bleed(t)
	_test_factory_creates_albino(t)


func _test_rare_alt_swap(t: Object) -> void:
	t.check(MobFactory.apply_rare_alt("rat", 0.0) == "albino",
		"Winning roll swaps rat -> albino")
	t.check(MobFactory.apply_rare_alt("thief", 0.019) == "bandit",
		"Roll just under 1/50 swaps thief -> bandit")
	t.check(MobFactory.apply_rare_alt("dm200", 0.0) == "dm201",
		"Winning roll swaps dm200 -> dm201")
	t.check(MobFactory.apply_rare_alt("rat", 0.02) == "rat",
		"Roll at 1/50 keeps the base mob")
	t.check(MobFactory.apply_rare_alt("rat", 0.5) == "rat",
		"Losing roll keeps the base mob")
	t.check(MobFactory.apply_rare_alt("gnoll", 0.0) == "gnoll",
		"Mobs without a ported alt are never swapped")


func _test_alts_not_in_tables(t: Object) -> void:
	# Upstream: Bandit and DM-201 spawn only via the 1/50 swap, never as
	# standard rotation entries.
	for depth: int in range(1, 25):
		for entry: Dictionary in MobFactory.get_mob_table(depth):
			t.check(entry["mob_id"] != "bandit" and entry["mob_id"] != "dm201",
				"Depth %d table has no direct rare-alt entry" % depth)


func _test_albino_stats(t: Object) -> void:
	var albino := Albino.new()
	t.check(albino.mob_id == "albino", "Albino mob_id")
	t.check(albino.hp == 12 and albino.ht == 12, "Albino HP/HT 12 (upstream)")
	t.check(albino.xp_value == 2, "Albino EXP 2 (upstream)")
	t.check(albino.loot_table.size() == 1
		and albino.loot_table[0]["item_id"] == "mystery_meat"
		and albino.loot_table[0]["chance"] == 1.0,
		"Albino always drops mystery meat")
	t.check(albino is Rat, "Albino extends Rat")


func _test_albino_bleed(t: Object) -> void:
	var albino := Albino.new()
	var victim := Rat.new()
	albino.apply_bleed(victim)
	var bleeding: Bleeding = victim.get_buff("Bleeding") as Bleeding
	t.check(bleeding != null, "apply_bleed attaches Bleeding")
	if bleeding != null:
		t.check(bleeding.bleed_level >= 2.0 and bleeding.bleed_level <= 3.0,
			"Bleed level in upstream NormalFloat(2, 3) range")
		var before: float = bleeding.bleed_level
		albino.apply_bleed(victim)
		t.check(victim.get_buff("Bleeding") == bleeding,
			"Re-proc reuses the existing Bleeding buff")
		t.check(bleeding.bleed_level >= before or bleeding.bleed_level >= 2.0,
			"set_level keeps the higher bleed level")


func _test_factory_creates_albino(t: Object) -> void:
	var mob: Mob = MobFactory.create_mob("albino")
	t.check(mob != null and mob is Albino, "MobFactory builds albino by id")
