extends RefCounted
## Rogue Silent Steps (upstream Mob.act sleeping block): a hero with the
## talent cannot wake a sleeping mob from distance >= 4 - points, so +1
## means safe from 3+ tiles away and +2 means safe from any non-adjacent
## tile. Verified through Mob._silent_steps_blocks, the predicate that
## zeroes sleeping detection chance in _act_sleeping.

func run(t: Object) -> void:
	_test_no_points_never_blocks(t)
	_test_one_point_blocks_at_three_tiles(t)
	_test_two_points_blocks_when_not_adjacent(t)

func _make_rogue(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.ROGUE)
	if points > 0:
		hero.talent_levels["rogue_silent_steps"] = points
	return hero

func _test_no_points_never_blocks(t: Object) -> void:
	var hero := _make_rogue(0)
	var mob := Mob.new()
	t.check(not mob._silent_steps_blocks(hero, 1.0), "0 points: adjacent hero can wake mobs")
	t.check(not mob._silent_steps_blocks(hero, 4.0), "0 points: distant hero can wake mobs")
	t.check(not mob._silent_steps_blocks(null, 4.0), "Null hero never blocks detection")
	mob.free()
	hero.free()

func _test_one_point_blocks_at_three_tiles(t: Object) -> void:
	var hero := _make_rogue(1)
	var mob := Mob.new()
	t.check(not mob._silent_steps_blocks(hero, 1.0), "+1: adjacent hero can wake mobs")
	t.check(not mob._silent_steps_blocks(hero, 2.0), "+1: hero 2 tiles away can wake mobs")
	t.check(mob._silent_steps_blocks(hero, 3.0), "+1: hero 3 tiles away cannot wake mobs")
	t.check(mob._silent_steps_blocks(hero, 7.0), "+1: hero far away cannot wake mobs")
	mob.free()
	hero.free()

func _test_two_points_blocks_when_not_adjacent(t: Object) -> void:
	var hero := _make_rogue(2)
	var mob := Mob.new()
	t.check(not mob._silent_steps_blocks(hero, 1.0), "+2: adjacent hero can wake mobs")
	t.check(mob._silent_steps_blocks(hero, 2.0), "+2: hero 2 tiles away cannot wake mobs")
	t.check(mob._silent_steps_blocks(hero, 7.0), "+2: hero far away cannot wake mobs")
	mob.free()
	hero.free()
