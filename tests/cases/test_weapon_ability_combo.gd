extends RefCounted
## Duelist Combo Strike family (upstream Sai.comboStrikeAbility +
## Sai.ComboStrikeTracker): every Duelist hit on an enemy feeds a 5-turn
## recent-hit tracker; the Gloves/Sai ability consumes the tracker for a
## guaranteed strike with +boost damage per recent hit, always costing the
## attack delay. Zero recent hits still strikes but adds no bonus.

func run(t: Object) -> void:
	_test_ability_data(t)
	_test_hits_feed_tracker(t)
	_test_tracker_expires(t)
	_test_combo_strike_consumes_tracker(t)
	_test_zero_hit_strike_has_no_boost(t)
	_test_non_duelist_feeds_no_tracker(t)

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
	var gloves := MeleeWeapon.create("gloves")
	t.check(gloves.has_duelist_ability(), "Gloves have a duelist ability")
	t.check(gloves.ability_name() == "Combo Strike", "Gloves ability is Combo Strike")
	t.check(gloves.ability_damage_boost() == 3, "Gloves per-hit boost is 3 at +0")
	gloves.level = 2
	t.check(gloves.ability_damage_boost() == 5, "Gloves per-hit boost scales with level (3+2)")
	var sai := MeleeWeapon.create("sai")
	t.check(sai.ability_name() == "Combo Strike", "Sai ability is Combo Strike")
	t.check(sai.ability_damage_boost() == 4, "Sai per-hit boost is 4 at +0")

func _test_hits_feed_tracker(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "gloves")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	hero.attack(enemy, 1.0, 0.0, 1.0e9)
	hero.attack(enemy, 1.0, 0.0, 1.0e9)
	var combo := hero.get_buff("ComboStrikeTracker") as ComboStrikeTracker
	t.check(combo != null and combo.hits == 2, "Two Duelist hits feed 2 tracker hits")
	t.check(absf(combo.time_left - ComboStrikeTracker.WINDOW) < 0.001,
			"Each hit resets the 5-turn window")
	hero.free()

func _test_tracker_expires(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "gloves")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	hero.attack(enemy, 1.0, 0.0, 1.0e9)
	var combo := hero.get_buff("ComboStrikeTracker") as ComboStrikeTracker
	t.check(combo != null, "Hit attached the tracker")
	for _i in range(5):
		combo.act()
	t.check(combo.is_expired(), "Tracker expires after 5 turns without a hit")
	hero.free()

func _test_combo_strike_consumes_tracker(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "sai")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	# Build 3 recent hits, then measure the ability strike's bonus.
	hero.attack(enemy, 1.0, 0.0, 1.0e9)
	hero.attack(enemy, 1.0, 0.0, 1.0e9)
	hero.attack(enemy, 1.0, 0.0, 1.0e9)
	var hp_before: int = enemy.hp
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(charger.charges == 1, "Combo strike spent one charge")
	var dealt: int = hp_before - enemy.hp
	t.check(dealt >= 12, "3-hit combo strike dealt at least the +12 bonus (3 hits x 4), dealt %d" % dealt)
	t.check(hero._ability_spend > 0.0, "Combo strike costs attack-delay time")
	var combo := hero.get_buff("ComboStrikeTracker") as ComboStrikeTracker
	t.check(combo != null and combo.hits == 1,
			"Ability consumed the tracker; its own hit starts a fresh 1-hit combo")
	hero.free()

func _test_zero_hit_strike_has_no_boost(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5), "gloves")
	# With no recent hits the ability adds nothing, so damage stays within
	# the weapon's base roll range (str pinned to the requirement so no
	# excess-STR bonus muddies the bound).
	var weapon: MeleeWeapon = hero.belongings.weapon as MeleeWeapon
	hero.str_val = weapon.get_str_requirement()
	var base_max: int = weapon.get_damage_range()[1]
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	var dealt: int = 500 - enemy.hp
	t.check(dealt <= base_max,
			"Zero-hit combo strike has no bonus (dealt %d <= %d base max)" % [dealt, base_max])
	t.check(charger.charges == 1, "Zero-hit strike still spends the charge")
	hero.free()

func _test_non_duelist_feeds_no_tracker(t: Object) -> void:
	var level := _make_level()
	var warrior := Hero.new()
	warrior.init_class(ConstantsData.HeroClass.WARRIOR)
	warrior.level = level
	warrior.pos = ConstantsData.xy_to_pos(5, 5)
	warrior.str_val = 20
	warrior.belongings.weapon = MeleeWeapon.create("gloves")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	warrior.attack(enemy, 1.0, 0.0, 1.0e9)
	t.check(warrior.get_buff("ComboStrikeTracker") == null,
			"Non-Duelist hits feed no combo tracker")
	warrior.free()
