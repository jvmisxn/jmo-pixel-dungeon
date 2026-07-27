extends RefCounted
## Sniper's Mark + special shot (upstream SnipersMark / SpiritBow sniperSpecial):
## a Sniper's thrown-missile hit marks the enemy for 4 turns (port adaptation:
## the mark attaches to the enemy, and tapping the marked enemy fires the
## special shot instead of an ActionIndicator). Shared Upgrades extends the
## mark by min(2*points, weapon level) turns and banks levelBonus/6 bonus
## damage. Special-shot modifiers: NONE augment x0.667 damage at 0 time,
## SPEED x0.5 at 1 turn (flurry not ported), DAMAGE x min(3, 1.2*1.125^(d-1))
## at 2 turns with guaranteed accuracy.

class FixedRollBow:
	extends SpiritBow
	func _roll_from_range(_dmg_range: Array[int], _owner: Variant) -> int:
		return 30

func run(t: Object) -> void:
	_test_registry(t)
	_test_mark_applied_on_missile_hit(t)
	_test_shared_upgrades_scaling(t)
	_test_non_sniper_no_mark(t)
	_test_remark_merges(t)
	_test_special_action_flag(t)
	_test_special_damage_modifiers(t)
	_test_special_speed_and_accuracy(t)
	_test_special_shot_consumes_mark(t)
	_test_bow_damage_uses_hero_level(t)

func _make_level() -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.build_flag_maps()
	return level

func _make_sniper(points: int = 0) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	hero.hero_subclass = ConstantsData.HeroSubclass.SNIPER
	if points > 0:
		hero.talent_levels["sniper_shared_upgrades"] = points
	return hero

func _make_target(pos: int = -1) -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = 100
	mob.hp = 100
	if pos >= 0:
		mob.pos = pos
	return mob

func _make_missile(level: int = 0) -> MissileWeapon:
	var missile := MissileWeapon.create("dart")
	missile.level = level
	return missile

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.HUNTRESS, "sniper_shared_upgrades",
		ConstantsData.HeroSubclass.SNIPER)
	t.check(info != null, "sniper_shared_upgrades is registered for the Sniper")
	t.check(info != null and info.implemented,
		"sniper_shared_upgrades is marked implemented (no longer inert)")

func _test_mark_applied_on_missile_hit(t: Object) -> void:
	var hero := _make_sniper(0)
	var target := _make_target()
	hero._apply_snipers_mark(_make_missile(3), target)
	var mark: SnipersMark = target.get_buff("SnipersMark") as SnipersMark
	t.check(mark != null, "Sniper thrown hit marks the enemy")
	if mark != null:
		t.check(is_equal_approx(mark.get_time_left(), 4.0),
			"Mark lasts 4 turns without Shared Upgrades")
		t.check(is_zero_approx(mark.percent_dmg_bonus),
			"No Shared Upgrades -> no bonus damage banked")
	hero.free()
	target.free()

func _test_shared_upgrades_scaling(t: Object) -> void:
	var hero := _make_sniper(2)
	var target := _make_target()
	hero._apply_snipers_mark(_make_missile(5), target)
	var mark: SnipersMark = target.get_buff("SnipersMark") as SnipersMark
	t.check(mark != null and is_equal_approx(mark.get_time_left(), 8.0),
		"Level bonus caps at 2*points: +2 -> min(4, weapon 5) = +4 turns")
	t.check(mark != null and is_equal_approx(mark.percent_dmg_bonus, 4.0 / 6.0),
		"Bonus damage is levelBonus/6 (66.7% at counted level 4)")
	hero.free()
	target.free()

	var hero2 := _make_sniper(3)
	var target2 := _make_target()
	hero2._apply_snipers_mark(_make_missile(2), target2)
	var mark2: SnipersMark = target2.get_buff("SnipersMark") as SnipersMark
	t.check(mark2 != null and is_equal_approx(mark2.get_time_left(), 6.0),
		"Level bonus caps at weapon level: +3 with +2 dart -> +2 turns")
	t.check(mark2 != null and is_equal_approx(mark2.percent_dmg_bonus, 2.0 / 6.0),
		"Bonus damage follows the counted weapon level (33.3%)")
	hero2.free()
	target2.free()

func _test_non_sniper_no_mark(t: Object) -> void:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	var target := _make_target()
	hero._apply_snipers_mark(_make_missile(0), target)
	t.check(not target.has_buff("SnipersMark"),
		"Non-Sniper huntress thrown hits do not mark")
	hero.free()
	target.free()

func _test_remark_merges(t: Object) -> void:
	var hero := _make_sniper(0)
	var target := _make_target()
	hero._apply_snipers_mark(_make_missile(0), target)
	var mark: SnipersMark = target.get_buff("SnipersMark") as SnipersMark
	if mark == null:
		t.check(false, "first mark attaches")
		return
	mark.time_left = 1.0
	mark.percent_dmg_bonus = 0.5
	hero._apply_snipers_mark(_make_missile(0), target)
	var merged: SnipersMark = target.get_buff("SnipersMark") as SnipersMark
	t.check(merged == mark, "Re-marking merges into the existing mark")
	t.check(is_equal_approx(mark.get_time_left(), 4.0),
		"Re-marking extends the mark back to full duration")
	t.check(is_zero_approx(mark.percent_dmg_bonus),
		"Newest mark's damage bonus replaces the old one")
	hero.free()
	target.free()

func _test_special_action_flag(t: Object) -> void:
	var level := _make_level()
	var hero := _make_sniper(0)
	hero.pos = ConstantsData.xy_to_pos(10, 10)
	hero.level = level
	hero.belongings.spirit_bow = SpiritBow.new()
	var target := _make_target(ConstantsData.xy_to_pos(13, 10))
	target.level = level
	level.add_mob(target)

	var plain: Dictionary = hero.get_auto_ranged_action(target.pos)
	t.check(plain.get("type", "") == "throw_item" and not plain.has("sniper_special"),
		"Unmarked enemy tap is a normal bow shot")

	target.add_buff(SnipersMark.new())
	var special: Dictionary = hero.get_auto_ranged_action(target.pos)
	t.check(special.get("sniper_special", false) == true,
		"Tapping a marked enemy flags a sniper special shot")

	hero.hero_subclass = ConstantsData.HeroSubclass.WARDEN
	var warden_action: Dictionary = hero.get_auto_ranged_action(target.pos)
	t.check(not warden_action.get("sniper_special", false),
		"Non-Sniper subclass never fires special shots")

	hero.free()
	level.free()

func _test_special_damage_modifiers(t: Object) -> void:
	var bow := FixedRollBow.new()
	t.check(bow.damage_roll(null) == 30, "Fixed test bow rolls 30 base")
	bow.sniper_special = true
	bow.sniper_special_bonus = 4.0 / 6.0
	t.check(bow.damage_roll(null) == 33,
		"NONE-augment special: round(30 * 1.667 * 0.667) = 33")
	bow.sniper_special_bonus = 0.0
	bow.augment = SpiritBow.Augment.SPEED
	t.check(bow.damage_roll(null) == 15, "SPEED-augment special halves damage")
	bow.augment = SpiritBow.Augment.DAMAGE
	bow.sniper_special_distance = 4
	t.check(bow.damage_roll(null) == 51,
		"DAMAGE-augment special: round(30 * 1.2 * 1.125^3) = 51")
	bow.sniper_special_distance = 20
	t.check(bow.damage_roll(null) == 90,
		"DAMAGE-augment distance multiplier caps at 3x")

func _test_special_speed_and_accuracy(t: Object) -> void:
	var bow := SpiritBow.new()
	t.check(is_equal_approx(bow.speed_factor(null), 1.0), "Normal bow shot costs 1 turn")
	bow.sniper_special = true
	t.check(is_zero_approx(bow.speed_factor(null)),
		"NONE-augment special shot is a free action")
	bow.augment = SpiritBow.Augment.SPEED
	t.check(is_equal_approx(bow.speed_factor(null), 1.0),
		"SPEED-augment special costs 1 turn")
	bow.augment = SpiritBow.Augment.DAMAGE
	t.check(is_equal_approx(bow.speed_factor(null), 2.0),
		"DAMAGE-augment special costs 2 turns")
	t.check(bow.accuracy_factor(null, null) >= 1000000.0,
		"DAMAGE-augment special shot cannot miss")
	bow.augment = SpiritBow.Augment.NONE
	t.check(bow.accuracy_factor(null, null) < 1000000.0,
		"Other augments keep normal special-shot accuracy")

func _test_special_shot_consumes_mark(t: Object) -> void:
	var level := _make_level()
	var hero := _make_sniper(0)
	hero.pos = ConstantsData.xy_to_pos(10, 10)
	hero.level = level
	var bow := SpiritBow.new()
	hero.belongings.spirit_bow = bow
	var target := _make_target(ConstantsData.xy_to_pos(12, 10))
	target.level = level
	level.add_mob(target)
	var mark := SnipersMark.new()
	mark.percent_dmg_bonus = 0.5
	target.add_buff(mark)

	hero._do_throw_item(bow, target.pos, true)
	t.check(not target.has_buff("SnipersMark"),
		"Special shot consumes the mark")
	t.check(bow.sniper_special and is_equal_approx(bow.sniper_special_bonus, 0.5),
		"Special shot arms the bow with the mark's banked bonus")
	t.check(bow.sniper_special_distance == 2,
		"Special shot records the target distance for the DAMAGE augment")

	hero.free()
	level.free()

func _test_bow_damage_uses_hero_level(t: Object) -> void:
	var bow := SpiritBow.new()
	var hero := _make_sniper(0)
	hero.hero_level = 12
	var dmg_range: Array[int] = bow.get_damage_range_for_level(12)
	var saw_above_level1_max: bool = false
	for i in 60:
		var dmg: int = bow.damage_roll(hero)
		t.check(dmg >= dmg_range[0] and dmg <= dmg_range[1] + hero.str_val,
			"Bow damage roll stays in the hero-level-12 range")
		if dmg > bow.get_damage_range_for_level(1)[1]:
			saw_above_level1_max = true
	t.check(saw_above_level1_max,
		"Bow damage now scales with hero level (fixes the level-1 fallback)")
	hero.free()
