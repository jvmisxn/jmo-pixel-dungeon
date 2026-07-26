extends RefCounted
## Warrior Strongman (upstream Talent.STRONGMAN, Warrior T3):
## Hero.STR() adds floor(baseSTR * (0.03 + 0.05 * points)) bonus strength
## (8%/13%/18%). The port bakes the bonus into str_val through a live,
## non-serialized StrongmanBuff (Ring of Might pattern) that is recomputed on
## talent upgrade, Potion of Strength, and load.

class FakeStrBuff extends Buff:
	var contribution: int = 0

	func _init() -> void:
		buff_id = "FakeStr"
		buff_name = "Fake Str"
		duration = -1

	func get_str_contribution() -> int:
		return contribution

func run(t: Object) -> void:
	_test_bonus_per_point(t)
	_test_zero_points_no_buff(t)
	_test_idempotent_recompute(t)
	_test_strength_potion_recompute(t)
	_test_other_str_buffs_excluded(t)
	_test_serialize_saves_clean_base(t)
	_test_load_rebuilds_bonus(t)

func _make_warrior(points: int, base_str: int = 10) -> Hero:
	var hero := Hero.new()
	hero.pos = ConstantsData.xy_to_pos(4, 4)
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.str_val = base_str
	if points > 0:
		hero.talent_levels["warrior_strongman"] = points
	hero.update_strongman_bonus()
	return hero

func _test_bonus_per_point(t: Object) -> void:
	# floor(18 * 0.08/0.13/0.18) = 1/2/3
	for expected: Array in [[1, 19], [2, 20], [3, 21]]:
		var points: int = int(expected[0])
		var hero := _make_warrior(points, 18)
		t.check(hero.str_val == int(expected[1]),
			"18 base str at +%d gives str %d, got %d" % [points, int(expected[1]), hero.str_val])
		hero.free()
	# floor(10 * 0.08) = 0: low base str gives no bonus at +1
	var low := _make_warrior(1, 10)
	t.check(low.str_val == 10, "10 base str at +1 stays 10, got %d" % low.str_val)
	t.check(low.get_buff("Strongman") != null, "Buff still attached at zero bonus")
	low.free()

func _test_zero_points_no_buff(t: Object) -> void:
	var hero := _make_warrior(0, 18)
	t.check(hero.get_buff("Strongman") == null, "No points attaches no buff")
	t.check(hero.str_val == 18, "No points leaves str unchanged, got %d" % hero.str_val)
	hero.free()

func _test_idempotent_recompute(t: Object) -> void:
	var hero := _make_warrior(3, 18)
	hero.update_strongman_bonus()
	hero.update_strongman_bonus()
	t.check(hero.str_val == 21,
		"Repeated recompute does not stack, got %d" % hero.str_val)
	hero.free()

func _test_strength_potion_recompute(t: Object) -> void:
	# Base 18 -> 19 at +3: floor(19 * 0.18) = 3, total 22.
	var hero := _make_warrior(3, 18)
	hero.str_val += 1  # what Potion of Strength does before recomputing
	hero.update_strongman_bonus()
	t.check(hero.str_val == 22,
		"Potion recompute uses new base (19+3), got %d" % hero.str_val)
	hero.free()

func _test_other_str_buffs_excluded(t: Object) -> void:
	# A ring-style live +str buff must not inflate the Strongman base.
	var hero := _make_warrior(3, 18)
	var fake := FakeStrBuff.new()
	fake.contribution = 5
	hero.add_buff(fake)
	hero.str_val += 5
	hero.update_strongman_bonus()
	# base stays 18 -> bonus 3; str = 18 + 5 (fake) + 3
	t.check(hero.str_val == 26,
		"Other str buff contributions excluded from base, got %d" % hero.str_val)
	hero.free()

func _test_serialize_saves_clean_base(t: Object) -> void:
	var hero := _make_warrior(3, 18)
	var data: Dictionary = hero.serialize()
	t.check(int(data.get("str_val", -1)) == 18,
		"Serialize persists base str without Strongman bonus, got %s" % str(data.get("str_val")))
	hero.free()

func _test_load_rebuilds_bonus(t: Object) -> void:
	var hero := _make_warrior(3, 18)
	var data: Dictionary = hero.serialize()
	var restored := Hero.new()
	restored.deserialize(data)
	t.check(restored.str_val == 21,
		"Deserialize rebuilds Strongman bonus (18+3), got %d" % restored.str_val)
	var buff: StrongmanBuff = restored.get_buff("Strongman") as StrongmanBuff
	t.check(buff != null and buff.get_str_contribution() == 3,
		"Rebuilt buff tracks its contribution")
	restored.free()
	hero.free()
