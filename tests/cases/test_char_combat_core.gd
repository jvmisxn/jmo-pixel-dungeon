extends RefCounted
## Core Char combat-math contracts (backlog audit:S03): hit() 1e6 bounds,
## Vulnerable's post-armor 1.33x ordering, Doom stacking on top of Vulnerable,
## shield-before-HP damage ordering, and dr_roll averaging.


## Deterministic-armor defender: fixed dr_roll so ordering vs. multipliers
## is observable without RNG.
class FixedDRChar:
	extends Char
	var fixed_dr: int = 0

	func dr_roll() -> int:
		return fixed_dr


func run(t: Object) -> void:
	_test_hit_infinite_bounds(t)
	_test_vulnerable_applies_after_armor(t)
	_test_doom_stacks_on_vulnerable(t)
	_test_shield_absorbs_before_hp(t)
	_test_dr_roll_distribution(t)


func _make_char(atk: int, def: int, dmg: int) -> Char:
	var c: Char = Char.new()
	c.hp = 100
	c.hp_max = 100
	c.ht = 100
	c.attack_skill = atk
	c.defense_skill = def
	c.damage_roll_min = dmg
	c.damage_roll_max = dmg
	c.armor_value = 0
	return c


func _test_hit_infinite_bounds(t: Object) -> void:
	# SPD Char.hit: INFINITE_EVASION beats INFINITE_ACCURACY — the defender
	# check comes first, so 1e6+ evasion always dodges even a 1e6+ attacker.
	var attacker: Char = _make_char(2000000, 0, 5)
	var evader: Char = _make_char(10, 1000000, 5)
	var all_missed: bool = true
	for _i: int in range(20):
		if Char.hit(attacker, evader, 1.0):
			all_missed = false
	t.check(all_missed, "1e6 evasion always dodges, even vs 1e6 accuracy")

	# 1e6+ accuracy always hits any finite evasion.
	var dodger: Char = _make_char(10, 500, 5)
	var all_hit: bool = true
	for _i: int in range(20):
		if not Char.hit(attacker, dodger, 1.0):
			all_hit = false
	t.check(all_hit, "1e6 accuracy always hits finite evasion")

	attacker.free()
	evader.free()
	dodger.free()


func _test_vulnerable_applies_after_armor(t: Object) -> void:
	# SPD Char.attack: armor DR is subtracted first, THEN Vulnerable's 1.33x
	# (int-truncated). 10 dmg, fixed DR 5 -> int((10-5)*1.33) = 6 lost HP.
	# Pre-armor ordering would instead give int(10*1.33)-5 = 8.
	var attacker: Char = _make_char(1000000, 0, 10)
	var defender: FixedDRChar = FixedDRChar.new()
	defender.hp = 100
	defender.hp_max = 100
	defender.ht = 100
	defender.defense_skill = 0
	defender.fixed_dr = 5
	defender.add_buff(Vulnerable.new())

	t.check(attacker.attack(defender), "vulnerable attack lands deterministically")
	t.check(defender.hp == 94, "Vulnerable 1.33x applies after armor DR (10 dmg, DR 5 -> 6)")

	attacker.free()
	defender.free()


func _test_doom_stacks_on_vulnerable(t: Object) -> void:
	# Vulnerable multiplies in attack() (post-armor, int-truncated); Doom
	# multiplies in take_damage(). 10 dmg -> int(10*1.33)=13 -> 13*1.67 -> 22.
	var attacker: Char = _make_char(1000000, 0, 10)
	var defender: Char = _make_char(10, 0, 1)
	defender.add_buff(Vulnerable.new())
	defender.add_buff(Doom.new())

	t.check(attacker.attack(defender), "doomed attack lands deterministically")
	t.check(defender.hp == 78, "Doom 1.67x stacks on Vulnerable's post-armor 13 (-> 22)")

	attacker.free()
	defender.free()


func _test_shield_absorbs_before_hp(t: Object) -> void:
	# ShieldBuff absorption runs before HP loss (SPD ShieldBuff.processDamage),
	# and take_damage returns only the HP actually lost.
	var shielded: Char = _make_char(10, 0, 1)
	var barrier: Barrier = Barrier.new()
	barrier.set_shield(6)
	shielded.add_buff(barrier)

	var lost: int = shielded.take_damage(10, "test")
	t.check(lost == 4, "take_damage returns HP lost after shield absorption")
	t.check(shielded.hp == 96, "Barrier 6 absorbs first: 10 dmg costs only 4 HP")
	t.check(shielded.get_buff("Barrier") == null, "depleted Barrier detaches itself")

	# Depleting hits never overflow: shield >= damage means 0 HP lost.
	var fully_shielded: Char = _make_char(10, 0, 1)
	var big_barrier: Barrier = Barrier.new()
	big_barrier.set_shield(20)
	fully_shielded.add_buff(big_barrier)
	var none_lost: int = fully_shielded.take_damage(10, "test")
	t.check(none_lost == 0, "fully shielded hit loses no HP")
	t.check(fully_shielded.hp == 100, "HP untouched while Barrier covers the hit")
	t.check(big_barrier.get_shielding() == 10, "Barrier keeps its remaining shield")

	# Legacy flat `shielding` drains after ShieldBuffs, still before HP.
	var flat: Char = _make_char(10, 0, 1)
	flat.shielding = 3
	var flat_lost: int = flat.take_damage(10, "test")
	t.check(flat_lost == 7, "flat shielding absorbs before HP")
	t.check(flat.shielding == 0 and flat.hp == 93, "flat shield drains fully, HP takes the rest")

	shielded.free()
	fully_shielded.free()
	flat.free()


func _test_dr_roll_distribution(t: Object) -> void:
	# dr_roll uses NormalIntRange(0, armor): bounded 0..armor with a mean
	# near armor/2 (triangular distribution).
	var armored: Char = _make_char(10, 0, 1)
	armored.armor_value = 10

	var total: int = 0
	var in_bounds: bool = true
	const SAMPLES: int = 2000
	for _i: int in range(SAMPLES):
		var dr: int = armored.dr_roll()
		if dr < 0 or dr > 10:
			in_bounds = false
		total += dr

	var mean: float = float(total) / float(SAMPLES)
	t.check(in_bounds, "dr_roll stays within 0..armor")
	t.check(mean > 4.0 and mean < 6.0, "dr_roll mean near armor/2 (got %.2f)" % mean)

	armored.free()
