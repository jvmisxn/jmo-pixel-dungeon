extends RefCounted
## Duelist weapon abilities: Rapier Lunge (upstream Rapier.lungeAbility).
## Dash to the open neighbor cell nearest a target exactly one cell beyond
## reach, then land a guaranteed boosted strike costing the attack delay.
## Adjacent/rooted refusals are free; lunging at an empty non-visible cell
## dashes anyway, spending the charge and a move turn without an attack.

func run(t: Object) -> void:
	_test_ability_data(t)
	_test_adjacent_target_refused(t)
	_test_rooted_refused(t)
	_test_lunge_dashes_and_strikes(t)
	_test_blind_lunge_wastes_charge(t)

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
	hero.str_val = 20
	var weapon := MeleeWeapon.create("rapier")
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
	var rapier := MeleeWeapon.create("rapier")
	t.check(rapier.has_duelist_ability(), "Rapier has a duelist ability")
	t.check(rapier.ability_name() == "Lunge", "Rapier ability is Lunge")
	t.check(rapier.ability_kind() == "lunge", "Rapier ability kind is lunge")
	t.check(rapier.ability_damage_boost() == 5, "Lunge boost is 5 at +0")
	rapier.level = 2
	t.check(rapier.ability_damage_boost() == 8, "Lunge boost is 5+round(1.5*lvl) (8 at +2)")
	t.check(rapier.ability_target_range() == 2, "Lunge targets one cell beyond reach")

func _test_adjacent_target_refused(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5))
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 100)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(charger.charges == 2, "Adjacent lunge refusal spends no charge")
	t.check(enemy.hp == 100, "Adjacent lunge refusal deals no damage")
	t.check(hero.pos == ConstantsData.xy_to_pos(5, 5), "Adjacent lunge refusal does not move the hero")
	t.check(hero._ability_spend == 0.0, "Adjacent lunge refusal costs no time")
	hero.free()

func _test_rooted_refused(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5))
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(7, 5), 100)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero.add_buff(Rooted.new())
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(charger.charges == 2, "Rooted lunge refusal spends no charge")
	t.check(enemy.hp == 100, "Rooted lunge refusal deals no damage")
	t.check(hero.pos == ConstantsData.xy_to_pos(5, 5), "Rooted hero did not dash")
	t.check(hero._ability_spend == 0.0, "Rooted lunge refusal costs no time")
	hero.free()

func _test_lunge_dashes_and_strikes(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5))
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(7, 5), 500)
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, enemy.pos)
	t.check(hero.pos == ConstantsData.xy_to_pos(6, 5),
			"Lunge dashed to the neighbor cell nearest the target")
	t.check(charger.charges == 1, "Lunge spent one charge")
	var dealt: int = 500 - enemy.hp
	t.check(dealt >= 5, "Lunge landed with at least the +5 boost, dealt %d" % dealt)
	t.check(hero._ability_spend > 0.0, "Lunge costs attack-delay time")
	t.check(hero.get_buff("CleaveTracker") == null, "Lunge opens no cleave window")
	hero.free()

func _test_blind_lunge_wastes_charge(t: Object) -> void:
	var level := _make_level()
	level.visible.fill(false)
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5))
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	var target: int = ConstantsData.xy_to_pos(7, 5)
	hero._do_weapon_ability(hero.belongings.weapon, target)
	t.check(hero.pos == ConstantsData.xy_to_pos(6, 5),
			"Blind lunge still dashes toward the target cell")
	t.check(charger.charges == 1, "Blind lunge with no target still spends the charge")
	t.check(hero._ability_spend > 0.0, "Blind lunge with no target costs a move turn")
	hero.free()
