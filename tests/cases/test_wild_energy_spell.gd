extends RefCounted
## Wild Energy spell parity: recharges wands + artifact, applies an 8-turn Recharging
## buff, and must NOT upgrade/transmute any item (upstream WildEnergy has no such effect).

func run(t: Object) -> void:
	_check_recharges_wands(t)
	_check_applies_recharging_buff(t)
	_check_no_random_upgrade(t)
	_check_recharges_artifact(t)

func _make_spell() -> Spell:
	return Spell.create("wild_energy")

func _check_recharges_wands(t: Object) -> void:
	var hero := Hero.new()
	var wand := Wand.new()
	wand.charges_max = 3
	wand.charges = 0
	t.check(hero.belongings.add_item(wand), "wand added to backpack")
	_make_spell().execute(hero)
	t.check(wand.charges == Spell.WILD_ENERGY_WAND_CHARGE, "Wild Energy grants an immediate wand charge")

func _check_applies_recharging_buff(t: Object) -> void:
	var hero := Hero.new()
	_make_spell().execute(hero)
	var buff: Variant = hero.get_buff("Recharging")
	t.check(buff != null, "Wild Energy applies the Recharging buff")
	if buff != null:
		t.check(is_equal_approx(float(buff.time_left), Spell.WILD_ENERGY_RECHARGE_DURATION), "Recharging buff lasts 8 turns")

func _check_no_random_upgrade(t: Object) -> void:
	# Run many casts on a fully-charged wand; its level must never rise (old exploit was a 30% upgrade).
	var hero := Hero.new()
	var wand := Wand.new()
	wand.charges_max = 3
	wand.charges = 3
	var start_level: int = wand.level
	hero.belongings.add_item(wand)
	for _i: int in range(60):
		_make_spell().execute(hero)
	t.check(wand.level == start_level, "Wild Energy never upgrades a carried item")

func _check_recharges_artifact(t: Object) -> void:
	var hero := Hero.new()
	var artifact := Artifact.new()
	artifact.charge = 0
	artifact.charge_max = 100
	hero.belongings.artifact = artifact
	_make_spell().execute(hero)
	t.check(artifact.charge == Spell.WILD_ENERGY_ARTIFACT_CHARGE, "Wild Energy recharges the equipped artifact")
