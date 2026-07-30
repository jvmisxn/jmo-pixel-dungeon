extends RefCounted
## Armored brute rare-alt parity (upstream ArmoredBrute.java + MobSpawner
## RARE_ALTS): 1/50 swap from brute, +4 flat DR on top of the brute roll
## (4-12 total), rage shield HT/2 + 1 (vs base HT/2 + 4), guaranteed armor
## drop (1/4 plate, else scale, both random()).

func run(t: Object) -> void:
	_test_rare_alt_swap(t)
	_test_not_in_tables(t)
	_test_stats_and_names(t)
	_test_dr_bonus(t)
	_test_rage_shield(t)
	_test_loot(t)
	_test_serialization(t)


func _test_rare_alt_swap(t: Object) -> void:
	t.check(MobFactory.apply_rare_alt("brute", 0.0) == "armored_brute",
		"Winning roll swaps brute -> armored_brute")
	t.check(MobFactory.apply_rare_alt("brute", 0.5) == "brute",
		"Losing roll keeps the base brute")
	t.check(MobFactory.create_mob("armored_brute") is ArmoredBrute,
		"Factory creates ArmoredBrute")


func _test_not_in_tables(t: Object) -> void:
	# Upstream: armored brutes spawn only via the 1/50 swap.
	for depth: int in range(1, 25):
		for entry: Dictionary in MobFactory.get_mob_table(depth):
			t.check(entry["mob_id"] != "armored_brute",
				"Depth %d table has no direct armored_brute entry" % depth)


func _test_stats_and_names(t: Object) -> void:
	var armored := ArmoredBrute.new()
	t.check(armored is Brute, "ArmoredBrute extends Brute")
	t.check(armored.mob_id == "armored_brute", "ArmoredBrute mob_id")
	t.check(armored.mob_name == "Armored Brute", "ArmoredBrute display name")
	t.check(armored.hp == 40 and armored.hp_max == 40,
		"ArmoredBrute inherits brute HP 40 (upstream)")
	t.check(armored.xp_value == 8 and armored.max_level == 16,
		"ArmoredBrute inherits brute EXP/maxLvl")
	t.check(armored.description.contains("powerful armor"),
		"ArmoredBrute has its upstream description")


func _test_dr_bonus(t: Object) -> void:
	# Upstream drRoll = brute roll + 4, so armored minimum over many rolls
	# must sit at least 4 above the brute minimum, and every armored roll
	# must clear the flat +4.
	var brute := Brute.new()
	var armored := ArmoredBrute.new()
	var brute_min: int = 1 << 30
	var armored_min: int = 1 << 30
	for _i: int in range(300):
		brute_min = mini(brute_min, brute.dr_roll())
		var roll: int = armored.dr_roll()
		armored_min = mini(armored_min, roll)
		t.check(roll >= 4, "Armored DR roll always >= +4 flat bonus")
	t.check(armored_min >= brute_min + 4,
		"Armored DR floor sits >= 4 above the brute floor")


func _test_rage_shield(t: Object) -> void:
	var brute := Brute.new()
	brute.hp = 0
	t.check(brute._try_prevent_death(null), "Base brute enrages at death")
	t.check(brute.total_shielding() == brute.ht / 2 + 4,
		"Base brute rage shield is HT/2 + 4 (upstream)")
	var armored := ArmoredBrute.new()
	armored.hp = 0
	t.check(armored._try_prevent_death(null), "Armored brute enrages at death")
	t.check(armored.total_shielding() == armored.ht / 2 + 1,
		"Armored rage shield is HT/2 + 1 (upstream ArmoredRage)")
	t.check(armored.has_buff("BruteRage"),
		"Armored rage reuses BruteRage (upstream ArmoredRage extends it)")
	t.check(armored.damage_roll() >= 15,
		"Enraged armored brute uses the boosted 15-40 damage roll")
	t.check(not armored._try_prevent_death(null),
		"Second death is not prevented")


func _test_loot(t: Object) -> void:
	var armored := ArmoredBrute.new()
	var saw_scale: bool = false
	var saw_plate: bool = false
	for _i: int in range(200):
		var item: Item = armored.create_loot()
		t.check(item is Armor, "create_loot always yields armor")
		if item != null:
			saw_scale = saw_scale or item.item_id == "scale_armor"
			saw_plate = saw_plate or item.item_id == "plate_armor"
	t.check(saw_scale, "Loot includes scale armor (3/4)")
	t.check(saw_plate, "Loot includes plate armor (1/4)")


func _test_serialization(t: Object) -> void:
	var armored := ArmoredBrute.new()
	armored.hp = 0
	armored._try_prevent_death(null)
	var data: Dictionary = armored.serialize()
	var restored := ArmoredBrute.new()
	restored.deserialize(data)
	t.check(restored.has_raged, "has_raged survives serialize round-trip")
