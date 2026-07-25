extends RefCounted
## Battlemage Mystical Charge (upstream MagesStaff.proc head): every staff
## melee hit calls ArtifactRecharge.chargeArtifacts(hero, points/2f), which
## instantly grants points/2 turns' worth of passive charging to all equipped
## non-cursed artifacts. Port adaptation: Artifact.charge_turns applies
## charge_rate * turns through the uniform _recharge model.

func run(t: Object) -> void:
	_test_registry(t)
	_test_staff_hit_charges_artifact(t)
	_test_point_scaling_partial(t)
	_test_no_talent_no_charge(t)
	_test_non_staff_weapon_no_charge(t)
	_test_cursed_artifact_no_charge(t)
	_test_misc_slot_artifact_charges(t)
	_test_charge_capped_at_max(t)

func _make_battlemage(points: int, with_staff: bool = true) -> Hero:
	var hero := Hero.new()
	hero.pos = 0
	hero.init_class(ConstantsData.HeroClass.MAGE)
	hero.hero_subclass = ConstantsData.HeroSubclass.BATTLEMAGE
	if points > 0:
		hero.talent_levels["battlemage_mystical_charge"] = points
	if with_staff:
		var staff := Generator.create_item("mages_staff") as MagesStaff
		hero.belongings.equip_weapon(staff)
	return hero

func _make_artifact(rate: float = 1.0) -> Artifact:
	var art := Artifact.new()
	art.item_id = "test_artifact"
	art.item_name = "Test Artifact"
	art.charge_rate = rate
	art.charge = 0
	art.charge_max = 10
	return art

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.MAGE, "battlemage_mystical_charge",
		ConstantsData.HeroSubclass.BATTLEMAGE)
	t.check(info != null, "battlemage_mystical_charge is registered for the Battlemage")
	t.check(info != null and info.implemented,
		"battlemage_mystical_charge is marked implemented (no longer inert)")

func _test_staff_hit_charges_artifact(t: Object) -> void:
	var hero := _make_battlemage(2)
	var art := _make_artifact()
	hero.belongings.equip_artifact(art)
	var mob := Mob.new()
	hero.attack_proc(mob, 10)
	t.check(art.charge == 1,
		"+2: a staff hit grants 1 turn of charging (rate 1.0 -> +1), got %d" % art.charge)
	mob.queue_free()

func _test_point_scaling_partial(t: Object) -> void:
	var hero := _make_battlemage(1)
	var art := _make_artifact()
	hero.belongings.equip_artifact(art)
	var mob := Mob.new()
	hero.attack_proc(mob, 10)
	t.check(art.charge == 0 and is_equal_approx(art._partial_charge, 0.5),
		"+1: a staff hit banks 0.5 turns as partial charge")
	hero.attack_proc(mob, 10)
	t.check(art.charge == 1 and is_equal_approx(art._partial_charge, 0.0),
		"+1: a second hit completes the whole charge")
	mob.queue_free()

func _test_no_talent_no_charge(t: Object) -> void:
	var hero := _make_battlemage(0)
	var art := _make_artifact()
	hero.belongings.equip_artifact(art)
	var mob := Mob.new()
	hero.attack_proc(mob, 10)
	t.check(art.charge == 0 and is_equal_approx(art._partial_charge, 0.0),
		"no talent points -> staff hits grant no artifact charge")
	mob.queue_free()

func _test_non_staff_weapon_no_charge(t: Object) -> void:
	var hero := _make_battlemage(3, false)
	var art := _make_artifact()
	hero.belongings.equip_artifact(art)
	var mob := Mob.new()
	hero.attack_proc(mob, 10)
	t.check(art.charge == 0 and is_equal_approx(art._partial_charge, 0.0),
		"hits without the staff equipped grant no artifact charge")
	mob.queue_free()

func _test_cursed_artifact_no_charge(t: Object) -> void:
	var hero := _make_battlemage(3)
	var art := _make_artifact()
	art.cursed = true
	hero.belongings.equip_artifact(art)
	var mob := Mob.new()
	hero.attack_proc(mob, 10)
	t.check(art.charge == 0 and is_equal_approx(art._partial_charge, 0.0),
		"cursed artifacts do not benefit from Mystical Charge")
	mob.queue_free()

func _test_misc_slot_artifact_charges(t: Object) -> void:
	var hero := _make_battlemage(2)
	var art := _make_artifact()
	hero.belongings.equip_misc(art)
	var mob := Mob.new()
	hero.attack_proc(mob, 10)
	t.check(art.charge == 1,
		"an artifact in the misc slot also charges, got %d" % art.charge)
	mob.queue_free()

func _test_charge_capped_at_max(t: Object) -> void:
	var hero := _make_battlemage(3)
	var art := _make_artifact(20.0)
	art.charge = 9
	hero.belongings.equip_artifact(art)
	var mob := Mob.new()
	hero.attack_proc(mob, 10)
	t.check(art.charge == art.charge_max,
		"instant charging caps at charge_max, got %d/%d" % [art.charge, art.charge_max])
	mob.queue_free()
