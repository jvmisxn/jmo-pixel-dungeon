extends RefCounted
## Warrior Hold Fast (upstream Talent.HOLD_FAST, Warrior T3):
## Hero.rest attaches a HoldFast buff pinned to the hero's tile. While braced,
## drRoll gains NormalIntRange(points, 2*points) armor and combo/shielding
## buffs decay 50%/75%/100% slower (HoldFast.buffDecayFactor). Moving off the
## tile detaches the buff.

func run(t: Object) -> void:
	_test_wait_attaches_buff(t)
	_test_zero_points_no_buff(t)
	_test_armor_bonus_bounds(t)
	_test_armor_bonus_detaches_off_tile(t)
	_test_decay_factor_values(t)
	_test_barrier_decay_paused(t)
	_test_combo_decay_paused(t)
	_test_on_turn_detaches_after_move(t)
	_test_serialize_round_trip(t)

func _make_warrior(points: int) -> Hero:
	var hero := Hero.new()
	hero.pos = ConstantsData.xy_to_pos(4, 4)
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	if points > 0:
		hero.talent_levels["warrior_hold_fast"] = points
	return hero

func _braced_warrior(points: int) -> Hero:
	var hero := _make_warrior(points)
	hero._do_wait()
	return hero

func _test_wait_attaches_buff(t: Object) -> void:
	var hero := _braced_warrior(2)
	var buff: HoldFastBuff = hero.get_buff("HoldFast") as HoldFastBuff
	t.check(buff != null, "Waiting with the talent attaches HoldFast")
	if buff != null:
		t.check(buff.hold_pos == hero.pos, "HoldFast pins the current tile")
	hero._do_wait()
	var count: int = 0
	for b: Node in hero.get_buffs():
		if b is HoldFastBuff:
			count += 1
	t.check(count == 1, "Waiting again re-pins instead of stacking, got %d" % count)
	hero.free()

func _test_zero_points_no_buff(t: Object) -> void:
	var hero := _make_warrior(0)
	hero._do_wait()
	t.check(not hero.has_buff("HoldFast"),
		"Waiting without the talent attaches nothing")
	hero.free()

func _test_armor_bonus_bounds(t: Object) -> void:
	var hero := _braced_warrior(3)
	var buff: HoldFastBuff = hero.get_buff("HoldFast") as HoldFastBuff
	var lo: int = 99
	var hi: int = -1
	for i in range(400):
		var roll: int = buff.armor_bonus()
		lo = mini(lo, roll)
		hi = maxi(hi, roll)
	t.check(lo >= 3 and hi <= 6,
		"3-point armor bonus stays in 3..6, got %d..%d" % [lo, hi])
	t.check(hero.dr_roll() >= 3,
		"dr_roll includes the Hold Fast bonus while braced")
	hero.free()

func _test_armor_bonus_detaches_off_tile(t: Object) -> void:
	var hero := _braced_warrior(2)
	var buff: HoldFastBuff = hero.get_buff("HoldFast") as HoldFastBuff
	hero.pos += 1
	t.check(buff.armor_bonus() == 0, "Off-tile armor bonus is 0")
	t.check(not hero.has_buff("HoldFast"), "Off-tile armor query detaches the buff")
	hero.free()

func _test_decay_factor_values(t: Object) -> void:
	for expected: Array in [[1, 0.5], [2, 0.25], [3, 0.0]]:
		var hero := _braced_warrior(expected[0])
		t.check(is_equal_approx(HoldFastBuff.decay_factor(hero), expected[1]),
			"%d points: decay factor %f" % [expected[0], expected[1]])
		hero.free()
	var plain := _make_warrior(3)
	t.check(is_equal_approx(HoldFastBuff.decay_factor(plain), 1.0),
		"No HoldFast buff: decay factor 1.0")
	t.check(is_equal_approx(HoldFastBuff.decay_factor(null), 1.0),
		"Null target: decay factor 1.0")
	plain.free()

func _test_barrier_decay_paused(t: Object) -> void:
	var hero := _braced_warrior(3)
	var barrier: Barrier = hero.add_buff(Barrier.new()) as Barrier
	barrier.set_shield(5)
	for i in range(30):
		barrier.on_turn()
	t.check(barrier.get_shielding() == 5,
		"3-point brace: barrier never decays, got %d" % barrier.get_shielding())
	hero.pos += 1
	for i in range(30):
		barrier.on_turn()
	t.check(barrier.get_shielding() < 5,
		"After moving, barrier decay resumes, got %d" % barrier.get_shielding())
	hero.free()

func _test_combo_decay_paused(t: Object) -> void:
	var hero := _braced_warrior(3)
	var combo: GladiatorCombo = hero.add_buff(GladiatorCombo.new()) as GladiatorCombo
	combo.combo_count = 4
	for i in range(10):
		combo.on_turn()
	t.check(combo.combo_count == 4,
		"3-point brace: combo never decays, got %d" % combo.combo_count)
	hero.pos += 1
	for i in range(10):
		combo.on_turn()
	t.check(combo.combo_count == 0,
		"After moving, combo decay resumes, got %d" % combo.combo_count)
	hero.free()

func _test_on_turn_detaches_after_move(t: Object) -> void:
	var hero := _braced_warrior(1)
	var buff: HoldFastBuff = hero.get_buff("HoldFast") as HoldFastBuff
	buff.on_turn()
	t.check(hero.has_buff("HoldFast"), "on_turn keeps the buff while braced")
	hero.pos += 1
	buff.on_turn()
	t.check(not hero.has_buff("HoldFast"), "on_turn detaches after moving")
	hero.free()

func _test_serialize_round_trip(t: Object) -> void:
	var hero := _braced_warrior(2)
	var buff: HoldFastBuff = hero.get_buff("HoldFast") as HoldFastBuff
	var data: Dictionary = buff.serialize()
	var restored := HoldFastBuff.new()
	restored.deserialize(data)
	t.check(restored.hold_pos == buff.hold_pos,
		"hold_pos survives serialize round-trip")
	restored.free()
	hero.free()
