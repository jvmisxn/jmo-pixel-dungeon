extends RefCounted
## Duelist weapon abilities: Flail Spin (upstream Flail.duelistAbility +
## SpinAbilityTracker). Winding up stacks up to 3 spins on a 3-turn
## tracker (first spin costs a charge, re-spins are free, each cast
## spends one turn); a fourth spin refuses for free. The next flail
## attack releases the spins as a guaranteed hit with +spins*(8+2*lvl)
## bonus damage, consuming the tracker.

func run(t: Object) -> void:
	_test_ability_data(t)
	_test_spin_stacks_and_charge(t)
	_test_fourth_spin_refused(t)
	_test_release_consumes_tracker(t)
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

func _make_duelist(level: Level, hero_pos: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.DUELIST)
	hero.level = level
	hero.pos = hero_pos
	hero.str_val = 20
	var weapon := MeleeWeapon.create("flail")
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
	var flail := MeleeWeapon.create("flail")
	t.check(flail.has_duelist_ability(), "Flail has a duelist ability")
	t.check(flail.ability_name() == "Spin", "Flail ability is Spin")
	t.check(flail.ability_kind() == "spin", "Flail ability kind is spin")
	t.check(flail.spin_boost_per_spin() == 8, "Spin release boost is 8 per spin at +0")
	flail.level = 2
	t.check(flail.spin_boost_per_spin() == 12,
			"Spin release boost is 8 + 2*lvl per spin (12 at +2)")

func _test_spin_stacks_and_charge(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5))
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	var spin := hero.get_buff("SpinAbilityTracker") as SpinAbilityTracker
	t.check(spin != null and spin.spins == 1, "First cast stacks one spin")
	t.check(charger.charges == 1, "First spin spent one charge")
	t.check(hero._ability_spend == 1.0, "Spinning up spends one turn")
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	spin = hero.get_buff("SpinAbilityTracker") as SpinAbilityTracker
	t.check(spin != null and spin.spins == 3, "Three casts stack three spins")
	t.check(charger.charges == 1, "Re-spins while the tracker is active are free")
	t.check(spin.get_time_left() >= 3.0, "Each cast re-prolongs the 3-turn tracker")
	hero.free()

func _test_fourth_spin_refused(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5))
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	for i: int in 3:
		hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	hero._ability_spend = 0.0
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	var spin := hero.get_buff("SpinAbilityTracker") as SpinAbilityTracker
	t.check(spin != null and spin.spins == 3, "A fourth spin does not stack")
	t.check(hero._ability_spend == 0.0, "A refused fourth spin costs no time")
	t.check(charger.charges == 1, "A refused fourth spin costs no charge")
	hero.free()

func _test_release_consumes_tracker(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5))
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	# Awake, aware, and highly evasive: only the spin release's guaranteed
	# accuracy (not a surprise attack) can land this hit reliably.
	enemy.state = Mob.AIState.HUNTING
	enemy.defense_skill = 1000
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 2
	for i: int in 3:
		hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	var hit: bool = hero.attack(enemy)
	t.check(hit, "The spin release is a guaranteed hit despite high evasion")
	t.check(500 - enemy.hp >= 24,
			"Three spins add at least 3*8 bonus damage (dealt %d)" % [500 - enemy.hp])
	t.check(hero.get_buff("SpinAbilityTracker") == null,
			"The release consumes the spin tracker")
	hero.free()

func _test_no_charge_refused(t: Object) -> void:
	var level := _make_level()
	var hero := _make_duelist(level, ConstantsData.xy_to_pos(5, 5))
	var charger := hero.get_buff("WeaponCharger") as WeaponCharger
	charger.charges = 0
	charger.partial_charge = 0.0
	hero._do_weapon_ability(hero.belongings.weapon, hero.pos)
	t.check(hero.get_buff("SpinAbilityTracker") == null,
			"No-charge spin attaches no tracker")
	t.check(hero._ability_spend == 0.0, "No-charge refusal costs no time")
	hero.free()
