extends RefCounted
## Monk Dash ability (upstream MonkEnergy.MonkAbility.Dash). Costs 3 energy
## and no turn (instant), moving the hero to an empty cell within range 4
## (8 while abilities are empowered) along a clear projectile line. Rooted
## heroes, out-of-range, occupied, or wall-blocked cells refuse for free.

func run(t: Object) -> void:
	_test_dash_moves_and_spends(t)
	_test_dash_refusals(t)
	_test_dash_blocked_by_wall(t)
	_test_empowered_dash_range(t)

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

func _test_dash_moves_and_spends(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 5.0
	var target := ConstantsData.xy_to_pos(9, 5)
	hero._do_monk_ability("dash", target)
	t.check(hero.pos == target, "Dash moves the hero to the target cell")
	t.check(absf(energy.energy - 2.0) < 0.001, "Dash spent 3 energy")
	t.check(hero._ability_spend == 0.0, "Dash is instant (no turn cost)")
	hero.free()

func _test_dash_refusals(t: Object) -> void:
	var level := _make_level()
	var start := ConstantsData.xy_to_pos(5, 5)
	var hero := _make_monk(level, start)
	var energy := MonkEnergy.new()
	hero.add_buff(energy)

	# Not enough energy: refused, no movement.
	energy.energy = 2.0
	hero._do_monk_ability("dash", ConstantsData.xy_to_pos(7, 5))
	t.check(hero.pos == start, "Dash refused without 3 energy")

	# Out of range (range 4 unempowered): refused for free.
	energy.energy = 5.0
	hero._do_monk_ability("dash", ConstantsData.xy_to_pos(10, 5))
	t.check(hero.pos == start, "Dash refused beyond range 4")
	t.check(absf(energy.energy - 5.0) < 0.001, "Out-of-range refusal is free")

	# Occupied cell: refused for free.
	var mob_pos := ConstantsData.xy_to_pos(8, 5)
	var _mob := _make_enemy(level, mob_pos, 10)
	hero._do_monk_ability("dash", mob_pos)
	t.check(hero.pos == start, "Dash refused into an occupied cell")
	t.check(absf(energy.energy - 5.0) < 0.001, "Occupied refusal is free")

	# Rooted hero: refused for free.
	hero.add_buff(Rooted.new())
	hero._do_monk_ability("dash", ConstantsData.xy_to_pos(7, 5))
	t.check(hero.pos == start, "Rooted hero can't dash")
	t.check(absf(energy.energy - 5.0) < 0.001, "Rooted refusal is free")
	hero.free()

func _test_dash_blocked_by_wall(t: Object) -> void:
	var level := _make_level()
	var start := ConstantsData.xy_to_pos(5, 5)
	# Wall between hero and target blocks the projectile line.
	level.map[ConstantsData.xy_to_pos(7, 5)] = ConstantsData.Terrain.WALL
	level.build_flag_maps()
	var hero := _make_monk(level, start)
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 5.0
	hero._do_monk_ability("dash", ConstantsData.xy_to_pos(9, 5))
	t.check(hero.pos == start, "Dash refused through a wall")
	t.check(absf(energy.energy - 5.0) < 0.001, "Wall-blocked refusal is free")

	# Dashing onto the wall cell itself also refuses.
	hero._do_monk_ability("dash", ConstantsData.xy_to_pos(7, 5))
	t.check(hero.pos == start, "Dash refused onto a wall cell")
	hero.free()

func _test_empowered_dash_range(t: Object) -> void:
	var level := _make_level()
	var start := ConstantsData.xy_to_pos(5, 5)
	var hero := _make_monk(level, start)
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	# Overfilled past 1.2x of the level-1 cap (10): empowered without talent.
	energy.energy = 12.0
	t.check(energy.abilities_empowered(), "Overfilled energy empowers abilities")
	var target := ConstantsData.xy_to_pos(12, 5)
	hero._do_monk_ability("dash", target)
	t.check(hero.pos == target, "Empowered dash reaches range 8")
	hero.free()
