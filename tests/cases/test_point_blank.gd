extends RefCounted
## Huntress Point Blank (T3) + the underlying SPD missile adjacency accuracy
## split (upstream MissileWeapon.adjacentAccFactor): thrown weapons get 0.5x
## accuracy against adjacent targets and 1.5x at range. Point Blank raises the
## adjacent factor to 0.5 + 0.25*points -> 0.75x/1.0x/1.25x. SpiritBow arrows
## inherit the same split upstream (SpiritArrow extends MissileWeapon).

func run(t: Object) -> void:
	_test_registry(t)
	_test_missile_adjacency_split(t)
	_test_point_blank_scaling(t)
	_test_spirit_bow_inherits(t)
	_test_non_hero_owner(t)
	_test_row_wrap_not_adjacent(t)

func _make_huntress(points: int, hero_pos: int = 0) -> Hero:
	var hero := Hero.new()
	hero.pos = hero_pos
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	if points > 0:
		hero.talent_levels["huntress_point_blank"] = points
	return hero

func _make_target(target_pos: int) -> Char:
	var c := Char.new()
	c.pos = target_pos
	return c

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.HUNTRESS, "huntress_point_blank")
	t.check(info != null, "huntress_point_blank is registered")
	t.check(info != null and info.implemented,
		"huntress_point_blank is marked implemented")
	t.check(info != null and info.tier == 3 and info.max_points == 3,
		"huntress_point_blank is tier 3, max 3 points")

func _test_missile_adjacency_split(t: Object) -> void:
	var hero := _make_huntress(0)
	var missile: MissileWeapon = MissileWeapon.create("throwing_knife")
	var adjacent := _make_target(1)
	var distant := _make_target(5)
	t.check(is_equal_approx(missile.accuracy_factor(hero, adjacent), 0.5),
		"No talent: adjacent target -> 0.5x accuracy")
	t.check(is_equal_approx(missile.accuracy_factor(hero, distant), 1.5),
		"Ranged target -> 1.5x accuracy")
	t.check(is_equal_approx(missile.accuracy_factor(hero, null), 1.0),
		"No target -> neutral 1.0x factor")
	hero.free()
	adjacent.free()
	distant.free()

func _test_point_blank_scaling(t: Object) -> void:
	var expected: Array[float] = [0.5, 0.75, 1.0, 1.25]
	for points: int in range(4):
		var hero := _make_huntress(points)
		var missile: MissileWeapon = MissileWeapon.create("throwing_knife")
		var adjacent := _make_target(1)
		var distant := _make_target(5)
		t.check(
			is_equal_approx(
				missile.accuracy_factor(hero, adjacent), expected[points]),
			"%d point(s): adjacent factor is %sx" % [points, expected[points]])
		t.check(is_equal_approx(missile.accuracy_factor(hero, distant), 1.5),
			"%d point(s): ranged factor stays 1.5x" % points)
		hero.free()
		adjacent.free()
		distant.free()

func _test_spirit_bow_inherits(t: Object) -> void:
	var hero := _make_huntress(2)
	var bow := SpiritBow.new()
	var adjacent := _make_target(1)
	var distant := _make_target(5)
	t.check(is_equal_approx(bow.accuracy_factor(hero, adjacent), 1.0),
		"Spirit bow: +2 Point Blank -> adjacent factor 1.0x")
	t.check(is_equal_approx(bow.accuracy_factor(hero, distant), 1.5),
		"Spirit bow: ranged factor 1.5x")
	hero.free()
	adjacent.free()
	distant.free()

func _test_non_hero_owner(t: Object) -> void:
	var owner := _make_target(0)
	var adjacent := _make_target(1)
	t.check(
		is_equal_approx(
			MissileWeapon.adjacent_acc_factor_for(owner, adjacent), 0.5),
		"Non-hero owner: adjacent factor stays 0.5x")
	owner.free()
	adjacent.free()

func _test_row_wrap_not_adjacent(t: Object) -> void:
	var hero := _make_huntress(0, ConstantsData.WIDTH - 1)
	var wrapped := _make_target(ConstantsData.WIDTH)
	var missile: MissileWeapon = MissileWeapon.create("throwing_knife")
	t.check(is_equal_approx(missile.accuracy_factor(hero, wrapped), 1.5),
		"Row-wrap neighbor indices are not adjacent -> ranged 1.5x")
	hero.free()
	wrapped.free()
