extends RefCounted
## Balance.normal_int_range mirrors upstream watabou Random.NormalIntRange:
##   min + (int)((Float() + Float()) * (max - min + 1) / 2f)
## a triangular distribution over [min, max] peaked at the middle. Damage
## rolls (Char.damage_roll, Weapon._roll_from_range), DR rolls (Char.dr_roll),
## and wand bolts (Wand.roll_zap_damage) all route through it — wands
## previously used a flat uniform roll, which was a source-fidelity gap.

const SAMPLES: int = 20000


func run(t: Object) -> void:
	seed(1337)
	_test_degenerate_range(t)
	_test_bounds_and_coverage(t)
	_test_triangular_shape(t)
	_test_exact_distribution_three_values(t)
	_test_wand_zap_within_bounds(t)
	_test_char_damage_roll_within_bounds(t)


func _test_degenerate_range(t: Object) -> void:
	t.check(Balance.normal_int_range(5, 5) == 5, "Degenerate range returns min")
	t.check(Balance.normal_int_range(3, 1) == 3, "Inverted range returns min")


func _test_bounds_and_coverage(t: Object) -> void:
	var seen: Dictionary = {}
	var in_bounds := true
	for i in SAMPLES:
		var v: int = Balance.normal_int_range(2, 7)
		if v < 2 or v > 7:
			in_bounds = false
		seen[v] = true
	t.check(in_bounds, "All rolls within [2, 7]")
	t.check(seen.has(2) and seen.has(7), "Both endpoints reachable")
	t.check(seen.size() == 6, "All 6 values in [2, 7] observed")


func _test_triangular_shape(t: Object) -> void:
	# Over [0, 10] the middle value must be rolled far more often than the
	# endpoints, and the sample mean must sit near the range midpoint.
	var counts: Array[int] = []
	counts.resize(11)
	counts.fill(0)
	var total: int = 0
	for i in SAMPLES:
		var v: int = Balance.normal_int_range(0, 10)
		counts[v] += 1
		total += v
	var mean: float = float(total) / float(SAMPLES)
	t.check(absf(mean - 5.0) < 0.15, "Sample mean near midpoint (got %.3f)" % mean)
	t.check(counts[5] > counts[0] * 2, "Middle rolled well above low endpoint")
	t.check(counts[5] > counts[10] * 2, "Middle rolled well above high endpoint")


func _test_exact_distribution_three_values(t: Object) -> void:
	# For range [0, 2]: result = int((f1 + f2) * 3 / 2). Upstream pmf:
	# P(0) = P(f1+f2 < 2/3) = 2/9, P(2) = P(f1+f2 >= 4/3) = 2/9, P(1) = 5/9.
	var counts: Array[int] = [0, 0, 0]
	for i in SAMPLES:
		counts[Balance.normal_int_range(0, 2)] += 1
	var p0: float = float(counts[0]) / float(SAMPLES)
	var p1: float = float(counts[1]) / float(SAMPLES)
	var p2: float = float(counts[2]) / float(SAMPLES)
	t.check(absf(p0 - 2.0 / 9.0) < 0.02, "P(min) near 2/9 (got %.3f)" % p0)
	t.check(absf(p1 - 5.0 / 9.0) < 0.02, "P(mid) near 5/9 (got %.3f)" % p1)
	t.check(absf(p2 - 2.0 / 9.0) < 0.02, "P(max) near 2/9 (got %.3f)" % p2)


func _test_wand_zap_within_bounds(t: Object) -> void:
	var wand: Wand = Wand.new()
	wand.level = 3
	var dmg_range: Array[int] = wand.get_damage(wand.level)
	var ok := true
	var seen_mid := false
	for i in 2000:
		var dmg: int = wand.roll_zap_damage()
		if dmg < dmg_range[0] or dmg > dmg_range[1]:
			ok = false
		if dmg != dmg_range[0] and dmg != dmg_range[1]:
			seen_mid = true
	t.check(ok, "Wand zap damage stays within get_damage() bounds")
	t.check(seen_mid, "Wand zap damage rolls interior values")


func _test_char_damage_roll_within_bounds(t: Object) -> void:
	var c: Char = Char.new()
	c.damage_roll_min = 4
	c.damage_roll_max = 12
	var ok := true
	for i in 2000:
		var dmg: int = c.damage_roll()
		if dmg < 4 or dmg > 12:
			ok = false
	t.check(ok, "Char.damage_roll stays within [min, max]")
	c.free()
