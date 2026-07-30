extends RefCounted
## Monk Flurry ability (upstream MonkEnergy.MonkAbility.Flurry). Two unarmed
## strikes at 1.5x damage with infinite accuracy, instant, once per turn via
## FlurryCooldownTracker, costing 1 energy. Unarmed strikes ignore the
## equipped weapon (UnarmedAbilityTracker damage-roll bypass) and kill gains
## mid-ability defer the energy cap.

func run(t: Object) -> void:
	_test_flurry_hits_twice_and_spends_energy(t)
	_test_flurry_is_instant_and_once_per_turn(t)
	_test_refusals(t)
	_test_unarmed_damage_bypasses_weapon(t)
	_test_cap_deferral_mid_ability(t)

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

func _make_monk(level: Level, hero_pos: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.hero_subclass = ConstantsData.HeroSubclass.MONK
	hero.level = level
	hero.pos = hero_pos
	hero.str_val = 20
	return hero

func _make_enemy(level: Level, mob_pos: int, hp: int) -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = maxi(hp, 1)
	mob.hp = hp
	mob.pos = mob_pos
	mob.level = level
	level.add_mob(mob)
	return mob

func _test_flurry_hits_twice_and_spends_energy(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 3.0
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	hero._do_monk_ability("flurry", enemy.pos)
	t.check(absf(energy.energy - 2.0) < 0.001, "Flurry spent 1 energy")
	var dealt: int = 500 - enemy.hp
	t.check(dealt >= 2, "Both guaranteed unarmed strikes landed, dealt %d" % dealt)
	t.check(hero.get_buff("UnarmedAbilityTracker") == null,
			"Unarmed tracker is cleaned up after the ability")
	hero.free()

func _test_flurry_is_instant_and_once_per_turn(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 5.0
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	hero._do_monk_ability("flurry", enemy.pos)
	t.check(hero._ability_spend == 0.0, "Flurry is instant (no time spent)")
	t.check(hero.get_buff("FlurryCooldownTracker") != null, "Flurry leaves its cooldown tracker")
	var hp_after_first: int = enemy.hp
	hero._do_monk_ability("flurry", enemy.pos)
	t.check(enemy.hp == hp_after_first, "Second flurry in the same turn is refused")
	t.check(absf(energy.energy - 4.0) < 0.001, "Refused flurry costs no energy")
	hero.free()

func _test_refusals(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 0.5
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 50)
	hero._do_monk_ability("flurry", enemy.pos)
	t.check(enemy.hp == 50, "Below 1 energy: flurry refused")
	energy.energy = 5.0
	var far := _make_enemy(level, ConstantsData.xy_to_pos(9, 5), 50)
	hero._do_monk_ability("flurry", far.pos)
	t.check(far.hp == 50 and absf(energy.energy - 5.0) < 0.001,
			"Out-of-reach target refused before spending")
	hero.hero_subclass = ConstantsData.HeroSubclass.CHAMPION
	hero._do_monk_ability("flurry", enemy.pos)
	t.check(enemy.hp == 50, "Non-Monk gets no flurry")
	hero.free()

func _test_unarmed_damage_bypasses_weapon(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	hero.belongings.weapon = MeleeWeapon.create("greatsword")
	hero.str_val = 9  # unarmed max = max(1, 9-8) = 1
	hero.add_buff(UnarmedAbilityTracker.new())
	for i in range(20):
		var dmg: int = hero.damage_roll()
		t.check(dmg == 1, "Unarmed roll ignores the greatsword (got %d)" % dmg)
		if dmg != 1:
			break
	hero.free()

func _test_cap_deferral_mid_ability(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 10.0
	var rat: Mob = MobFactory.create_mob("rat")
	rat.level = level
	rat.pos = ConstantsData.xy_to_pos(7, 5)
	hero.add_buff(UnarmedAbilityTracker.new())
	energy.gain_energy(rat)
	t.check(absf(energy.energy - 11.0) < 0.001,
			"Kill mid unarmed ability overfills past the cap")
	energy.ability_used(1.0)
	t.check(absf(energy.energy - 10.0) < 0.001,
			"ability_used clamps back to the cap after spending")
	rat.free()
	hero.free()
