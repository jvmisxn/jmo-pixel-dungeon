extends RefCounted
## Rogue Mystical Meal (upstream Talent.onFoodEaten): eating food grants
## 1+2*points (3/5) turns of artifact recharging. Port adaptation: applied
## instantly via Hero._charge_artifacts (Artifact.charge_turns), like
## Battlemage Mystical Charge, instead of an over-time ArtifactRecharge buff.

func run(t: Object) -> void:
	_test_registry(t)
	_test_eating_charges_artifact(t)
	_test_no_talent_no_charge(t)
	_test_wrong_class_no_charge(t)
	_test_misc_slot_and_cursed(t)

func _make_rogue(points: int) -> Hero:
	var hero := Hero.new()
	hero.pos = 0
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	if points > 0:
		hero.talent_levels["rogue_mystical_meal"] = points
	return hero

func _make_artifact(rate: float = 1.0) -> Artifact:
	var art := Artifact.new()
	art.item_id = "test_artifact"
	art.item_name = "Test Artifact"
	art.charge_rate = rate
	art.charge = 0
	art.charge_max = 20
	return art

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.ROGUE, "rogue_mystical_meal")
	t.check(info != null, "rogue_mystical_meal is registered for the Rogue")
	t.check(info != null and info.implemented,
		"rogue_mystical_meal is marked implemented")
	t.check(info != null and info.tier == 2, "rogue_mystical_meal is tier 2")

func _test_eating_charges_artifact(t: Object) -> void:
	for points: int in [1, 2]:
		var hero := _make_rogue(points)
		var art := _make_artifact()
		hero.belongings.equip_artifact(art)
		hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
		var expected: int = 1 + 2 * points
		t.check(art.charge == expected,
			"+%d Mystical Meal grants %d charge, got %d" % [points, expected, art.charge])
		hero.free()

func _test_no_talent_no_charge(t: Object) -> void:
	var hero := _make_rogue(0)
	var art := _make_artifact()
	hero.belongings.equip_artifact(art)
	hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
	t.check(art.charge == 0, "No talent points -> eating does not charge artifacts")
	hero.free()

func _test_wrong_class_no_charge(t: Object) -> void:
	var hero := Hero.new()
	hero.pos = 0
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.talent_levels["rogue_mystical_meal"] = 2
	var art := _make_artifact()
	hero.belongings.equip_artifact(art)
	hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
	t.check(art.charge == 0, "Non-Rogue with the talent id gets no charge")
	hero.free()

func _test_misc_slot_and_cursed(t: Object) -> void:
	var hero := _make_rogue(2)
	var misc := _make_artifact()
	hero.belongings.equip_misc(misc)
	var cursed := _make_artifact()
	cursed.cursed = true
	hero.belongings.equip_artifact(cursed)
	hero.on_food_eaten(null, 0.0, hero.hp, hero.hp_max)
	t.check(misc.charge == 5, "Misc-slot artifact charges (5), got %d" % misc.charge)
	t.check(cursed.charge == 0, "Cursed artifact does not benefit")
	hero.free()
