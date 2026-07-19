extends RefCounted
## Coverage for FireTrap applying its real SPD burn effect.
##
## Regression: the live Prison fire trap dealt one direct hit and spread embers,
## but its Burning buff hook was a placeholder, so the trap did not actually set
## the victim on fire.

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 7
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func _make_hero(pos: int, level: Level) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.pos = pos
	hero.level = level
	hero.hp = 999
	hero.hp_max = 999
	hero.ht = 999
	return hero

func run(t: Object) -> void:
	seed(0xF17E)
	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(10, 10)
	var hero: Hero = _make_hero(hero_pos, level)
	var north_cell: int = hero_pos + ConstantsData.DIRS_4[0]
	level.set_terrain(north_cell, ConstantsData.Terrain.GRASS)

	var trap := FireTrap.new()
	trap.set_pos(hero_pos)
	trap.activate(hero, level)

	var burning: Burning = hero.get_buff("Burning") as Burning
	t.check(burning != null, "fire trap applies Burning to the triggerer")
	t.check(
		burning != null and is_equal_approx(burning.left, Burning.DURATION),
		"fire trap Burning starts with the SPD burn duration"
	)
	t.check(
		burning != null and burning.duration < 0.0 and burning.time_left < 0.0,
		"fire trap Burning stays on Burning's own left timer"
	)
	t.check(
		hero.hp == 988,
		"fire trap preserves the existing direct damage behavior"
	)
	t.check(
		level.terrain_at(north_cell) == ConstantsData.Terrain.EMBERS,
		"fire trap still spreads embers to adjacent grass"
	)
	t.check(not trap.active, "fire trap remains one-shot after activation")
	hero.process_buffs()
	burning = hero.get_buff("Burning") as Burning
	t.check(burning != null, "fire trap Burning survives the first burn tick")
	t.check(
		burning != null and burning.left < Burning.DURATION,
		"fire trap Burning decrements its real timer"
	)
	t.check(hero.hp < 988, "fire trap Burning deals lingering fire damage")
	for _tick: int in range(12):
		hero.process_buffs()
	t.check(hero.get_buff("Burning") == null, "fire trap Burning expires after its duration")

	hero.free()
