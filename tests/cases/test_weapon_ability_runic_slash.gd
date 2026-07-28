extends RefCounted
## Duelist weapon abilities: Runic Blade Runic Slash (upstream
## RunicBlade.duelistAbility). Guaranteed hit with no bonus damage that
## attaches RunicSlashTracker (boost 3 + 0.5*lvl); the enchant proc-chance
## roll consumes the tracker, adding the boost to the multiplier. Always
## costs the attack delay, kills open no free-recast window, and any
## unconsumed tracker is removed after the strike.

func run(t: Object) -> void:
	_test_ability_data(t)
	_test_proc_multiplier_consumes_tracker(t)
	_test_strike_costs_time_and_cleans_up(t)
	_test_kill_opens_no_window(t)
	_test_no_charge_refused(t)

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

func _make_duelist(level: Level, hero_pos: int, weapon_id: String) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.level = level
	hero.pos = hero_pos
	hero.str_val = 20
	var weapon := MeleeWeapon.create(weapon_id)
	hero.belongings.weapon = weapon
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

func _test_ability_data(t: Object) -> void:
	var blade := MeleeWeapon.create("runic_blade")
	t.check(blade.has_duelist_ability(), "Runic blade has a duelist ability")
	t.check(blade.ability_name() == "Runic Slash", "Runic blade ability is Runic Slash")
	t.check(blade.ability_kind() == "runic_slash", "Runic blade ability kind is runic_slash")
	t.check(blade.ability_damage_boost() == 0, "Runic slash has no flat damage boost")
	t.check(absf(blade.runic_slash_boost() - 3.0) < 0.001, "Runic slash boost is 3.0 at +0")
	blade.level = 2
	t.check(absf(blade.runic_slash_boost() - 4.0) < 0.001,
			"Runic slash boost is 3 + 0.5*lvl (4.0 at +2)")

func _test_proc_multiplier_consumes_tracker(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "runic_blade")
	var tracker := hero.add_buff(RunicSlashTracker.new()) as RunicSlashTracker
	tracker.boost = 3.0
	var multi: float = WeaponEnchantment.proc_chance_multiplier(hero)
	t.check(absf(multi - 4.0) < 0.001,
			"Proc-chance multiplier adds the tracker boost (1 + 3 = 4)")
	t.check(hero.get_buff("RunicSlashTracker") == null,
			"The proc-chance roll consumes the tracker")
	t.check(absf(WeaponEnchantment.proc_chance_multiplier(hero) - 1.0) < 0.001,
			"A second roll without the tracker is back to 1.0")
	hero.free()

func _test_strike_costs_time_and_cleans_up(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "runic_blade")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(charger.charges == 1, "Runic slash spent one charge")
	t.check(enemy.hp < 500, "Runic slash landed a guaranteed hit")
	t.check(hero._ability_spend > 0.0, "Runic slash costs attack-delay time")
	t.check(hero.get_buff("RunicSlashTracker") == null,
			"No tracker is left on the hero after the strike")
	t.check(hero.get_buff("CleaveTracker") == null, "Runic slash opens no cleave window")
	hero.free()

func _test_kill_opens_no_window(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "runic_blade")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 1)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(not enemy.is_alive, "Runic slash killed the 1 HP enemy")
	t.check(hero._ability_spend > 0.0, "A killing runic slash still costs the attack delay")
	t.check(hero.get_buff("CleaveTracker") == null, "A kill opens no free-recast window")
	t.check(hero.get_buff("RunicSlashTracker") == null,
			"No tracker is left after a killing strike")
	hero.free()

func _test_no_charge_refused(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "runic_blade")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 100)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 0
	charger.partial_charge = 0.0
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(enemy.hp == 100, "No-charge runic slash deals no damage")
	t.check(hero._ability_spend == 0.0, "No-charge refusal costs no time")
	hero.free()
