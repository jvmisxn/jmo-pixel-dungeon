extends RefCounted
## Monk energy pool (upstream MonkEnergy + Mob.destroy hook). Enemy deaths
## grant the Monk energy: 5 for bosses, 0.5 for weak swarm enemies, 1
## otherwise, gated on regen and capped at max(10, 5 + lvl/2). Unencumbered
## Spirit multiplies gains for low-tier armor/weapon. Energy persists
## through save/load.

func run(t: Object) -> void:
	_test_talent_registered(t)
	_test_kill_grants_energy(t)
	_test_gain_tiers_and_cap(t)
	_test_unencumbered_spirit(t)
	_test_non_monk_gains_nothing(t)
	_test_serialize_roundtrip(t)

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 2
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	level.visible.resize(ConstantsData.LENGTH)
	level.visible.fill(true)
	return level

func _make_monk(level: Level) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.hero_subclass = ConstantsData.HeroSubclass.MONK
	hero.level = level
	hero.pos = ConstantsData.xy_to_pos(5, 5)
	return hero

func _make_mob(level: Level, mob_id: String) -> Mob:
	var mob: Mob = MobFactory.create_mob(mob_id)
	mob.level = level
	mob.pos = ConstantsData.xy_to_pos(7, 5)
	return mob

func _cleanup(hero: Hero) -> void:
	if GameManager:
		GameManager.hero = null
	hero.free()

func _test_talent_registered(t: Object) -> void:
	var talents: Array = TalentData.get_talents_for(
			ConstantsData.HeroClass.DUELIST, ConstantsData.HeroSubclass.MONK)
	var ids: Array[String] = []
	var unencumbered_implemented := false
	for talent: TalentData.TalentInfo in talents:
		ids.append(talent.id)
		if talent.id == "monk_unencumbered_spirit":
			unencumbered_implemented = talent.implemented
	t.check(ids.has("monk_unencumbered_spirit"), "Monk has Unencumbered Spirit talent")
	t.check(unencumbered_implemented, "Unencumbered Spirit is implemented, not inert")
	t.check(ids.has("monk_monastic_vigor"), "Monk has Monastic Vigor slot")
	t.check(ids.has("monk_combined_energy"), "Monk has Combined Energy slot")
	t.check(not ids.has("monk_flurry_mastery"), "Old Flurry Mastery slot is gone")
	t.check(not ids.has("monk_centered_breath"), "Old Centered Breath slot is gone")

func _test_kill_grants_energy(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level)
	GameManager.hero = hero
	var rat := _make_mob(level, "rat")
	t.check(hero.get_buff("MonkEnergy") == null, "No energy buff before the first kill (lazy path)")
	rat._monk_energy_on_kill()
	var energy := hero.get_buff("MonkEnergy") as MonkEnergy
	t.check(energy != null, "Kill hook lazily attaches MonkEnergy")
	t.check(absf(energy.energy - 1.0) < 0.001, "Ordinary enemy grants 1 energy")
	rat._monk_energy_on_kill()
	t.check(absf(energy.energy - 2.0) < 0.001, "Second kill stacks to 2 energy")
	rat.free()
	_cleanup(hero)

func _test_gain_tiers_and_cap(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level)
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	var goo := _make_mob(level, "goo")
	var wraith := _make_mob(level, "wraith")
	t.check(absf(energy.gain_energy(goo) - 5.0) < 0.001, "Boss kill grants 5 energy")
	t.check(absf(energy.gain_energy(wraith) - 0.5) < 0.001, "Wraith kill grants 0.5 energy")
	t.check(energy.energy_cap() == 10, "Energy cap is 10 at low level")
	hero.hero_level = 30
	t.check(energy.energy_cap() == 20, "Energy cap is 20 at level 30")
	hero.hero_level = 1
	energy.energy = 9.8
	var rat := _make_mob(level, "rat")
	energy.gain_energy(rat)
	t.check(absf(energy.energy - 10.0) < 0.001, "Energy is capped at energy_cap")
	energy.ability_used(3.0)
	t.check(absf(energy.energy - 7.0) < 0.001, "ability_used spends energy")
	goo.free()
	wraith.free()
	rat.free()
	_cleanup(hero)

func _test_unencumbered_spirit(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level)
	hero.talent_levels["monk_unencumbered_spirit"] = 3
	hero.belongings.weapon = MeleeWeapon.create("dagger")  # tier 1
	hero.belongings.armor = Armor.create("cloth_armor")  # tier 1
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	var rat := _make_mob(level, "rat")
	t.check(absf(energy.gain_energy(rat) - 3.0) < 0.001,
			"+3 with tier-1 weapon and armor triples energy gain")
	energy.energy = 0.0
	hero.talent_levels["monk_unencumbered_spirit"] = 1
	hero.belongings.armor = Armor.create("mail_armor")  # tier 3
	hero.belongings.weapon = null  # unarmed: no weapon bonus
	t.check(absf(energy.gain_energy(rat) - 1.5) < 0.001,
			"+1 with tier-3 armor and no weapon grants +50%")
	rat.free()
	_cleanup(hero)

func _test_non_monk_gains_nothing(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level)
	hero.hero_subclass = ConstantsData.HeroSubclass.CHAMPION
	GameManager.hero = hero
	var rat := _make_mob(level, "rat")
	rat._monk_energy_on_kill()
	t.check(hero.get_buff("MonkEnergy") == null, "Non-Monk heroes gain no energy buff")
	rat.free()
	_cleanup(hero)

func _test_serialize_roundtrip(t: Object) -> void:
	var energy := MonkEnergy.new()
	energy.energy = 7.5
	var data: Dictionary = energy.serialize()
	var restored := MonkEnergy.new()
	restored.deserialize(data)
	t.check(absf(restored.energy - 7.5) < 0.001, "Energy survives serialize/deserialize")
	energy.free()
	restored.free()
