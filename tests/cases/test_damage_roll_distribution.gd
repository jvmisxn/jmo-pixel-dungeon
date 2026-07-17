extends RefCounted
## Verifies Char.damage_roll() uses a triangular (NormalIntRange-approx) bell
## curve rather than a flat uniform roll, matching SPD's Mob.damageRoll() and the
## shape already used by dr_roll() and Weapon.damage_roll().

func run(t: Object) -> void:
	# --- Hard invariants (hold for ANY RNG seed) ---
	var c: Char = Char.new()
	c.damage_roll_min = 3
	c.damage_roll_max = 9
	var out_of_range: int = 0
	for i in 500:
		var d: int = c.damage_roll()
		if d < 3 or d > 9:
			out_of_range += 1
	t.check(out_of_range == 0, "damage_roll stays within [min, max] over 500 rolls")

	# Degenerate range always returns the single value.
	c.damage_roll_min = 7
	c.damage_roll_max = 7
	var degenerate_ok: bool = true
	for i in 50:
		if c.damage_roll() != 7:
			degenerate_ok = false
	t.check(degenerate_ok, "damage_roll with min==max returns that value")
	c.free()

	# --- Distribution shape (deterministic via fixed seed, not flaky) ---
	seed(0xC0FFEE)
	var d2: Char = Char.new()
	d2.damage_roll_min = 0
	d2.damage_roll_max = 100
	var samples: int = 4000
	var middle: int = 0  # count of rolls in the middle third [34, 66]
	var total: int = 0
	for i in samples:
		var d: int = d2.damage_roll()
		total += d
		if d >= 34 and d <= 66:
			middle += 1
	d2.free()

	# Bell curve centers near the midpoint (50). Mean alone can't distinguish it
	# from uniform, but it must not drift far from center.
	var mean: float = float(total) / float(samples)
	t.check(abs(mean - 50.0) < 3.0, "damage_roll mean sits near the range midpoint (%.2f)" % mean)

	# A uniform roll over [0,100] puts ~33% of mass in the middle third [34,66];
	# the triangular bell curve concentrates it well above that (~54% expected).
	var middle_frac: float = float(middle) / float(samples)
	t.check(middle_frac > 0.45,
		"damage_roll concentrates mass in the middle (%.1f%% in [34,66] vs ~33%% uniform)" % (middle_frac * 100.0))
