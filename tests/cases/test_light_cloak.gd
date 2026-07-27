extends RefCounted
## Rogue Light Cloak (T3). Upstream: CloakOfShadows.cloakRecharge multiplies
## its charge gain by 0.75 * points / 3 when the cloak is not equipped, so a
## backpack cloak charges at 25%/50%/75% of its equipped rate. Port: the hero
## turn hook `_light_cloak_recharge()` recharges a backpack cloak at
## charge_rate * 0.25 * points per turn; equipped cloaks keep using on_turn.

func run(t: Object) -> void:
	_test_registry(t)
	_test_no_talent_no_charge(t)
	_test_backpack_charge_rates(t)
	_test_charge_cap(t)
	_test_cursed_cloak_excluded(t)
	_test_equipped_cloak_not_double_charged(t)

func _make_rogue(points: int) -> Hero:
	var hero := Hero.new()
	hero.pos = 0
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	if points > 0:
		hero.talent_levels["rogue_light_cloak"] = points
	return hero

func _make_cloak() -> Artifact:
	var cloak: Artifact = Generator.create_item("cloak_of_shadows")
	cloak.charge = 0
	cloak._partial_charge = 0.0
	return cloak

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.ROGUE, "rogue_light_cloak")
	t.check(info != null, "rogue_light_cloak is registered for the Rogue")
	t.check(info != null and info.implemented,
		"rogue_light_cloak is marked implemented")
	t.check(info != null and info.tier == 3, "rogue_light_cloak is tier 3")
	t.check(info != null and info.max_points == 3,
		"rogue_light_cloak has 3 max points")

func _test_no_talent_no_charge(t: Object) -> void:
	var hero := _make_rogue(0)
	var cloak := _make_cloak()
	hero.belongings.add_item(cloak)
	for i in 20:
		hero._light_cloak_recharge()
	t.check(cloak.charge == 0 and cloak._partial_charge == 0.0,
		"Backpack cloak gains no charge without Light Cloak")
	hero.free()

func _test_backpack_charge_rates(t: Object) -> void:
	# charge_rate 0.5 -> per-turn backpack gain is 0.125/0.25/0.375 at +1/+2/+3.
	var expected := {1: 8, 2: 4, 3: 3}
	for points: int in expected:
		var hero := _make_rogue(points)
		var cloak := _make_cloak()
		hero.belongings.add_item(cloak)
		var turns: int = expected[points]
		for i in turns - 1:
			hero._light_cloak_recharge()
		t.check(cloak.charge == 0,
			"+%d backpack cloak has no whole charge after %d turns" % [points, turns - 1])
		hero._light_cloak_recharge()
		t.check(cloak.charge == 1,
			"+%d backpack cloak gains its first charge on turn %d" % [points, turns])
		hero.free()

func _test_charge_cap(t: Object) -> void:
	var hero := _make_rogue(3)
	var cloak := _make_cloak()
	cloak.charge = cloak.charge_max
	hero.belongings.add_item(cloak)
	for i in 10:
		hero._light_cloak_recharge()
	t.check(cloak.charge == cloak.charge_max,
		"Backpack recharge respects charge_max")
	hero.free()

func _test_cursed_cloak_excluded(t: Object) -> void:
	var hero := _make_rogue(3)
	var cloak := _make_cloak()
	cloak.cursed = true
	hero.belongings.add_item(cloak)
	for i in 10:
		hero._light_cloak_recharge()
	t.check(cloak.charge == 0 and cloak._partial_charge == 0.0,
		"Cursed backpack cloak does not recharge")
	hero.free()

func _test_equipped_cloak_not_double_charged(t: Object) -> void:
	var hero := _make_rogue(3)
	var cloak := _make_cloak()
	hero.belongings.equip_artifact(cloak)
	for i in 10:
		hero._light_cloak_recharge()
	t.check(cloak.charge == 0 and cloak._partial_charge == 0.0,
		"Equipped cloak is not touched by the backpack recharge path")
	hero.free()
