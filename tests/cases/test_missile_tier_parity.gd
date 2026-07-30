extends RefCounted
## Missile tier/roster + damage parity (upstream Generator MIS_T1-T5 and
## MissileWeapon.min/max/STRReq).
## Covers:
##   - per-tier rosters match upstream (spike/fishing spear/throwing spear/
##     throwing hammer added; force_cudgel fills the ForceCube T5 slot)
##   - upstream tiers on moved items (club 2, kunai/bolas 3, javelin/
##     tomahawk 4, trident 5)
##   - base missile damage formula 2t+lvl .. 5t+t*lvl plus per-item
##     min/max overrides (knife, shuriken/kunai/club/hammer, bolas,
##     tomahawk, heavy boomerang)
##   - missile STR requirement is one below same-tier melee
##   - plain boomerang is out of every deck but still creatable


func run(t: Object) -> void:
	_test_rosters(t)
	_test_tiers(t)
	_test_damage_ranges(t)
	_test_level_scaling(t)
	_test_str_req(t)
	_test_boomerang_retired(t)


func _test_rosters(t: Object) -> void:
	var t1: Array = ["throwing_stone", "throwing_knife", "throwing_spike", "dart"]
	t.check(Generator.MIS_T1_DECK_TABLE == t1, "MIS_T1 roster matches upstream")
	t.check(Generator.MISSILES_T2 == ["fishing_spear", "throwing_club", "shuriken"],
		"MIS_T2 roster matches upstream")
	t.check(Generator.MISSILES_T3 == ["throwing_spear", "kunai", "bolas"],
		"MIS_T3 roster matches upstream")
	t.check(Generator.MISSILES_T4 == ["javelin", "tomahawk", "heavy_boomerang"],
		"MIS_T4 roster matches upstream")
	t.check(Generator.MISSILES_T5 == ["trident", "throwing_hammer", "force_cudgel"],
		"MIS_T5 roster matches upstream (ForceCube slot = force_cudgel)")


func _test_tiers(t: Object) -> void:
	var expected: Dictionary = {
		"throwing_spike": 1, "fishing_spear": 2, "throwing_club": 2,
		"shuriken": 2, "throwing_spear": 3, "kunai": 3, "bolas": 3,
		"javelin": 4, "tomahawk": 4, "heavy_boomerang": 4,
		"trident": 5, "throwing_hammer": 5, "force_cudgel": 5,
	}
	var all_ok: bool = true
	for id: String in expected:
		var w: MissileWeapon = MissileWeapon.create(id)
		if w.tier != expected[id]:
			all_ok = false
			t.check(false, "%s has upstream tier %d (got %d)" % [id, expected[id], w.tier])
	t.check(all_ok, "all missiles carry their upstream tier")


func _test_damage_ranges(t: Object) -> void:
	# [id, min, max] at level 0, upstream MissileWeapon.min/max + overrides.
	var expected: Array = [
		["throwing_stone", 2, 5],
		["throwing_knife", 2, 6],
		["throwing_spike", 2, 5],
		["fishing_spear", 4, 10],
		["throwing_club", 4, 8],
		["shuriken", 4, 8],
		["throwing_spear", 6, 15],
		["kunai", 6, 12],
		["bolas", 4, 9],
		["javelin", 8, 20],
		["tomahawk", 6, 16],
		["heavy_boomerang", 8, 16],
		["trident", 10, 25],
		["throwing_hammer", 10, 20],
	]
	for row: Array in expected:
		var w: MissileWeapon = MissileWeapon.create(row[0])
		var r: Array[int] = w.get_damage_range()
		t.check(r[0] == row[1] and r[1] == row[2],
			"%s deals %d-%d at level 0 (got %d-%d)" % [row[0], row[1], row[2], r[0], r[1]])


func _test_level_scaling(t: Object) -> void:
	var kunai: MissileWeapon = MissileWeapon.create("kunai")
	kunai.level = 2
	var kr: Array[int] = kunai.get_damage_range()
	t.check(kr[0] == 8 and kr[1] == 18,
		"kunai +2 deals 8-18 (min 2t+lvl, max override 4t + t*lvl)")
	var knife: MissileWeapon = MissileWeapon.create("throwing_knife")
	knife.level = 1
	var nr: Array[int] = knife.get_damage_range()
	t.check(nr[0] == 3 and nr[1] == 8,
		"throwing knife +1 deals 3-8 (tier-1 max scales 2*lvl)")
	var bolas: MissileWeapon = MissileWeapon.create("bolas")
	bolas.level = 3
	var br: Array[int] = bolas.get_damage_range()
	t.check(br[0] == 4 and br[1] == 15,
		"bolas +3 keeps flat min 4, max 9 + 2*lvl")


func _test_str_req(t: Object) -> void:
	# Upstream MissileWeapon.STRReq = melee STRReq(tier, lvl) - 1.
	var expected: Dictionary = {
		"throwing_spike": 9, "fishing_spear": 11, "throwing_spear": 13,
		"javelin": 15, "trident": 17, "throwing_hammer": 17,
	}
	for id: String in expected:
		var w: MissileWeapon = MissileWeapon.create(id)
		t.check(w.get_str_requirement() == expected[id],
			"%s needs %d STR (one below same-tier melee)" % [id, expected[id]])


func _test_boomerang_retired(t: Object) -> void:
	var in_deck: bool = false
	for cat: String in ["mis_t1", "mis_t2", "mis_t3", "mis_t4", "mis_t5"]:
		var table: Array = Generator._deck_defs[cat]["table"]
		if table.has("boomerang"):
			in_deck = true
	t.check(not in_deck, "plain boomerang is in no missile deck")
	var b: MissileWeapon = MissileWeapon.create("boomerang")
	t.check(b != null and b.returns and b.item_name == "Boomerang",
		"boomerang still creatable for old saves")
