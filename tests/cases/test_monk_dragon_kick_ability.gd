extends RefCounted
## Monk Dragon Kick ability (upstream MonkEnergy.MonkAbility.DragonKick).
## 4 energy for one guaranteed unarmed strike at 6x (9x empowered). A target
## that didn't move from the hit is knocked back 6 cells and paralyzed for
## min(6, cells moved); empowered kicks also knock back every other adjacent
## enemy. Costs the attack delay; refusals are free.

func run(t: Object) -> void:
	_test_kick_damages_knocks_back_and_paralyzes(t)
	_test_knockback_stops_at_wall(t)
	_test_refusals(t)
	_test_empowered_kick_hits_harder_and_sweeps_adjacent(t)

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

func _test_kick_damages_knocks_back_and_paralyzes(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 6.0
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	hero._do_monk_ability("dragon_kick", enemy.pos)
	t.check(absf(energy.energy - 2.0) < 0.001, "Dragon Kick spent 4 energy")
	t.check(enemy.hp < 500, "Guaranteed kick strike landed")
	t.check(enemy.pos == ConstantsData.xy_to_pos(12, 5),
			"Enemy knocked back 6 cells in the open")
	var para: Node = enemy.get_buff("Paralysis")
	t.check(para != null, "Knocked-back enemy is paralyzed")
	if para is Paralysis:
		t.check(absf((para as Paralysis).duration - 6.0) < 0.001,
				"Full 6-cell knockback paralyzes for 6 turns")
	t.check(hero.get_buff("UnarmedAbilityTracker") == null,
			"Unarmed tracker is cleaned up after the ability")
	t.check(hero._ability_spend > 0.0, "Dragon Kick costs the attack delay")
	hero.free()

func _test_knockback_stops_at_wall(t: Object) -> void:
	var level := _make_level()
	# Wall two cells behind the enemy: it can only be pushed 2 cells.
	level.map[ConstantsData.xy_to_pos(9, 5)] = ConstantsData.Terrain.WALL
	level.build_flag_maps()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	energy.energy = 6.0
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	hero._do_monk_ability("dragon_kick", enemy.pos)
	t.check(enemy.pos == ConstantsData.xy_to_pos(8, 5),
			"Knockback stops in front of the wall")
	var para: Node = enemy.get_buff("Paralysis")
	t.check(para is Paralysis and absf((para as Paralysis).duration - 2.0) < 0.001,
			"Paralysis lasts only the 2 cells actually moved")
	hero.free()

func _test_refusals(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)

	# Not enough energy: refused for free.
	energy.energy = 3.0
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 500)
	hero._do_monk_ability("dragon_kick", enemy.pos)
	t.check(enemy.hp == 500, "Short on energy: no strike")
	t.check(absf(energy.energy - 3.0) < 0.001, "Short-energy refusal is free")
	t.check(hero._ability_spend == 0.0, "Short-energy refusal costs no time")

	# Out of reach: refused for free.
	energy.energy = 6.0
	var far := _make_enemy(level, ConstantsData.xy_to_pos(8, 5), 500)
	hero._do_monk_ability("dragon_kick", far.pos)
	t.check(far.hp == 500, "Out-of-reach target: no strike")
	t.check(absf(energy.energy - 6.0) < 0.001, "Out-of-reach refusal is free")

	# Empty cell: refused for free.
	hero._do_monk_ability("dragon_kick", ConstantsData.xy_to_pos(4, 5))
	t.check(absf(energy.energy - 6.0) < 0.001, "Empty-cell refusal is free")
	hero.free()

func _test_empowered_kick_hits_harder_and_sweeps_adjacent(t: Object) -> void:
	var level := _make_level()
	var hero := _make_monk(level, ConstantsData.xy_to_pos(5, 5))
	var energy := MonkEnergy.new()
	hero.add_buff(energy)
	# Overfilled past 1.2x of the level-1 cap (10): empowered without talent.
	energy.energy = 12.0
	t.check(energy.abilities_empowered(), "Overfilled energy empowers abilities")
	var enemy := _make_enemy(level, ConstantsData.xy_to_pos(6, 5), 2000)
	var bystander := _make_enemy(level, ConstantsData.xy_to_pos(5, 4), 500)
	hero._do_monk_ability("dragon_kick", enemy.pos)
	t.check(enemy.hp < 2000, "Empowered kick strike landed")
	t.check(enemy.pos == ConstantsData.xy_to_pos(12, 5),
			"Primary target knocked back 6 cells")
	t.check(bystander.pos == ConstantsData.xy_to_pos(5, 0)
			or ConstantsData.pos_to_y(bystander.pos) < 4,
			"Adjacent bystander also knocked away while empowered")
	t.check(bystander.hp == 500, "Bystander takes no damage, only knockback")
	t.check(bystander.get_buff("Paralysis") != null,
			"Swept bystander is paralyzed for the cells moved")
	hero.free()
