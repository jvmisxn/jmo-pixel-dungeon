extends RefCounted
## Duelist weapon abilities: polearm-family Spike (upstream Spear.spikeAbility
## used by Spear/Glaive). Guaranteed hit with a flat damage boost that only
## works at reach (never adjacent), knocks a surviving target back one cell,
## always costs the attack delay, and kills open no free-recast window.

func run(t: Object) -> void:
	_test_ability_data(t)
	_test_adjacent_target_refused(t)
	_test_reach_hit_boosts_and_knocks_back(t)
	_test_kill_costs_time_and_opens_no_window(t)

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
	var spear := MeleeWeapon.create("spear")
	t.check(spear.has_duelist_ability(), "Spear has a duelist ability")
	t.check(spear.ability_name() == "Spike", "Spear ability is Spike")
	t.check(spear.ability_kind() == "spike", "Spear ability kind is spike")
	t.check(spear.ability_damage_boost() == 9, "Spear boost is 9 at +0")
	spear.level = 2
	t.check(spear.ability_damage_boost() == 13, "Spear boost is 9+2*lvl (13 at +2)")
	var glaive := MeleeWeapon.create("glaive")
	t.check(glaive.ability_damage_boost() == 12, "Glaive boost is 12 at +0")
	glaive.level = 2
	t.check(glaive.ability_damage_boost() == 17, "Glaive boost is 12+round(2.5*lvl) (17 at +2)")
	t.check(spear.ability_target_range() == 2, "Spike targets at weapon reach 2")
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.add_buff(CleaveTracker.new())
	t.check(spear.ability_charge_use(hero) == 1.0,
			"Spike still costs 1 charge inside a cleave window")
	hero.free()

func _test_adjacent_target_refused(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "spear")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 100)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(charger.charges == 2, "Adjacent spike refusal spends no charge")
	t.check(enemy.hp == 100, "Adjacent spike refusal deals no damage")
	t.check(hero._ability_spend == 0.0, "Adjacent spike refusal costs no time")
	hero.free()

func _test_reach_hit_boosts_and_knocks_back(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "spear")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(7, 5), 500)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(charger.charges == 1, "Spike spent one charge")
	var dealt: int = 500 - enemy.hp
	t.check(dealt >= 9, "Spike landed with at least the +9 boost, dealt %d" % dealt)
	t.check(enemy.pos == ConstantsData.xy_to_pos(8, 5),
			"Surviving target was knocked back one cell away from the hero")
	t.check(hero._ability_spend > 0.0, "Spike costs attack-delay time")
	t.check(hero.get_buff("CleaveTracker") == null, "Spike opens no cleave window")
	hero.free()

func _test_kill_costs_time_and_opens_no_window(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "glaive")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(7, 5), 1)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(not enemy.is_alive, "Spike killed the 1 HP enemy")
	t.check(enemy.pos == ConstantsData.xy_to_pos(7, 5), "Killed target is not knocked back")
	t.check(hero._ability_spend > 0.0, "Killing spike still costs attack-delay time")
	t.check(hero.get_buff("CleaveTracker") == null, "Spike kill opens no cleave window")
	hero.free()
