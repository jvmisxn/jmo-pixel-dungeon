extends RefCounted
## Duelist weapon abilities: Greataxe Retribution (upstream
## Greataxe.duelistAbility). Only usable while the hero is below half HP,
## guaranteed hit with +(15 + 2*lvl) flat damage, instantaneous if it kills,
## attack delay on a surviving target, no free-recast window.

func run(t: Object) -> void:
	_test_ability_data(t)
	_test_refused_above_half_hp(t)
	_test_strike_below_half_hp(t)
	_test_kill_is_instant_and_opens_no_window(t)

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

func _make_duelist(level: Level, hero_pos: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.level = level
	hero.pos = hero_pos
	hero.str_val = 22
	var weapon := MeleeWeapon.create("greataxe")
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
	var axe := MeleeWeapon.create("greataxe")
	t.check(axe.has_duelist_ability(), "Greataxe has a duelist ability")
	t.check(axe.ability_name() == "Retribution", "Greataxe ability is Retribution")
	t.check(axe.ability_kind() == "retribution", "Greataxe ability kind is retribution")
	t.check(axe.ability_damage_boost() == 15, "Retribution boost is 15 at +0")
	axe.level = 3
	t.check(axe.ability_damage_boost() == 21, "Retribution boost scales +2 per level (15+6)")

func _test_refused_above_half_hp(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5))
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	# Exactly half HP still refuses (upstream HP/HT >= 0.5 check).
	hero.hp = int(ceilf(hero.hp_max / 2.0))
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(enemy.hp == 500, "Retribution refused at or above half HP, no damage dealt")
	t.check(charger.charges == 2, "Refused retribution spends no charge")
	t.check(hero._ability_spend == 0.0, "Refused retribution costs no time")
	hero.free()

func _test_strike_below_half_hp(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5))
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 5000)
	hero.hp = maxi(1, hero.hp_max / 2 - 1)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(charger.charges == 1, "Retribution spent one charge")
	var dealt: int = 5000 - enemy.hp
	t.check(dealt >= 15, "Retribution landed with at least the +15 boost, dealt %d" % dealt)
	t.check(hero._ability_spend > 0.0, "Surviving target costs attack-delay time")
	hero.free()

func _test_kill_is_instant_and_opens_no_window(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5))
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 1)
	hero.hp = maxi(1, hero.hp_max / 2 - 1)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(not enemy.is_alive, "Retribution killed the 1 HP enemy")
	t.check(hero._ability_spend == 0.0, "Killing retribution strike is instantaneous")
	t.check(hero.get_buff("CleaveTracker") == null, "Retribution kill opens no cleave window")
	hero.free()
