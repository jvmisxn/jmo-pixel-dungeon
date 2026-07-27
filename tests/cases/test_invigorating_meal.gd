extends RefCounted
## Huntress Invigorating Meal (upstream Talent.onFoodEaten): eating food
## grants Buff.prolong(hero, Haste, 0.67 + points) — effectively 1/2 turns
## of haste. Port adaptation: same-buff merge keeps the longer remaining
## duration instead of upstream prolong's flat reset.
## Same slice: Huntress T1 roster fixed to upstream ordering (Followup
## Strike + Nature's Aid moved T2 -> T1) and the upstream T2 row added
## (Invigorating Meal real; Liquid Nature / Rejuvenating Steps /
## Heightened Senses / Durable Projectiles inert groundwork).

func run(t: Object) -> void:
	_test_registry(t)
	_test_roster_tiers(t)
	_test_eating_grants_haste(t)
	_test_no_talent_no_haste(t)
	_test_wrong_class_no_haste(t)
	_test_merge_keeps_longer(t)

func _make_huntress(points: int) -> Hero:
	var hero := Hero.new()
	hero.pos = 0
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	if points > 0:
		hero.talent_levels["huntress_invigorating_meal"] = points
	return hero

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.HUNTRESS, "huntress_invigorating_meal")
	t.check(info != null, "huntress_invigorating_meal is registered")
	t.check(info != null and info.implemented,
		"huntress_invigorating_meal is marked implemented")
	t.check(info != null and info.tier == 2, "huntress_invigorating_meal is tier 2")
	for inert_id: String in [
		"huntress_liquid_nature",
	]:
		var slot: TalentData.TalentInfo = TalentData.get_talent(
			ConstantsData.HeroClass.HUNTRESS, inert_id)
		t.check(slot != null and not slot.implemented and slot.tier == 2,
			"%s is an inert tier-2 groundwork slot" % inert_id)

func _test_roster_tiers(t: Object) -> void:
	for t1_id: String in ["huntress_followup_strike", "huntress_natures_aid"]:
		var info: TalentData.TalentInfo = TalentData.get_talent(
			ConstantsData.HeroClass.HUNTRESS, t1_id)
		t.check(info != null and info.tier == 1,
			"%s moved to tier 1 (upstream ordering)" % t1_id)

func _test_eating_grants_haste(t: Object) -> void:
	for points: int in [1, 2]:
		var hero := _make_huntress(points)
		hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
		var haste: Variant = hero.get_buff("Haste")
		t.check(haste != null, "+%d Invigorating Meal attaches Haste on eat" % points)
		if haste != null:
			var expected: float = 0.67 + float(points)
			t.check(absf(haste.get_time_left() - expected) < 0.001,
				"+%d grants %.2f turns of Haste, got %.2f"
				% [points, expected, haste.get_time_left()])
		hero.free()

func _test_no_talent_no_haste(t: Object) -> void:
	var hero := _make_huntress(0)
	hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
	t.check(hero.get_buff("Haste") == null,
		"No talent points -> eating does not grant Haste")
	hero.free()

func _test_wrong_class_no_haste(t: Object) -> void:
	var hero := Hero.new()
	hero.pos = 0
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.talent_levels["huntress_invigorating_meal"] = 2
	hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
	t.check(hero.get_buff("Haste") == null,
		"Non-Huntress with the points -> no Haste")
	hero.free()

func _test_merge_keeps_longer(t: Object) -> void:
	var hero := _make_huntress(1)
	var long_haste := Haste.new()
	long_haste.set_duration(10.0)
	hero.add_buff(long_haste)
	hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
	var haste: Variant = hero.get_buff("Haste")
	t.check(haste != null and absf(haste.get_time_left() - 10.0) < 0.001,
		"Eating under a longer Haste keeps the longer remaining duration")
	hero.free()
