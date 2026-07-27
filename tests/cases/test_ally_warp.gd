extends RefCounted
## Ally interaction + Mage Ally Warp (upstream Char.canInteract/interact):
## adjacent allies swap places with the hero; with Ally Warp the hero can
## swap with allies from up to 2*points tiles away, and the swap is an
## instant teleport (free action) that only needs a passable route.

func run(t: Object) -> void:
	_test_can_interact_rules(t)
	_test_adjacent_swap(t)
	_test_swap_blocked_by_paralysis(t)
	_test_warp_range_swap(t)
	_test_warp_blocked_by_walls(t)
	_test_hero_interact_free_action(t)

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 3
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func _make_mage(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	if points > 0:
		hero.talent_levels["mage_ally_warp"] = points
	return hero

func _make_ally(level: Level, mob_pos: int) -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = 10
	mob.hp = 10
	mob.pos = mob_pos
	mob.level = level
	mob.is_ally = true
	level.add_mob(mob)
	return mob

func _test_can_interact_rules(t: Object) -> void:
	var level := _make_level()
	var hero := _make_mage(0)
	hero.level = level
	hero.pos = ConstantsData.xy_to_pos(5, 5)
	var ally := _make_ally(level, ConstantsData.xy_to_pos(6, 5))
	t.check(ally.can_interact(hero), "Adjacent ally is interactable without the talent")
	ally.pos = ConstantsData.xy_to_pos(8, 5)
	t.check(not ally.can_interact(hero), "Ally 3 tiles away is not interactable without the talent")
	hero.talent_levels["mage_ally_warp"] = 1
	ally.pos = ConstantsData.xy_to_pos(7, 5)
	t.check(ally.can_interact(hero), "+1: ally 2 tiles away is interactable")
	ally.pos = ConstantsData.xy_to_pos(8, 5)
	t.check(not ally.can_interact(hero), "+1: ally 3 tiles away is out of warp range")
	hero.talent_levels["mage_ally_warp"] = 3
	ally.pos = ConstantsData.xy_to_pos(11, 5)
	t.check(ally.can_interact(hero), "+3: ally 6 tiles away is interactable")
	ally.pos = ConstantsData.xy_to_pos(12, 5)
	t.check(not ally.can_interact(hero), "+3: ally 7 tiles away is out of warp range")
	ally.pos = ConstantsData.xy_to_pos(6, 5)
	ally.is_ally = false
	t.check(not ally.can_interact(hero), "Hostile mobs are never interactable")
	ally.is_ally = true
	ally.immovable = true
	t.check(not ally.can_interact(hero), "Immovable allies (wards) are never interactable")
	ally.free()
	hero.free()

func _test_adjacent_swap(t: Object) -> void:
	var level := _make_level()
	var hero := _make_mage(0)
	hero.level = level
	var hero_pos: int = ConstantsData.xy_to_pos(5, 5)
	var ally_pos: int = ConstantsData.xy_to_pos(6, 5)
	hero.pos = hero_pos
	var ally := _make_ally(level, ally_pos)
	ally.interact(hero)
	t.check(hero.pos == ally_pos and ally.pos == hero_pos,
		"Adjacent interaction swaps hero and ally positions")
	ally.free()
	hero.free()

func _test_swap_blocked_by_paralysis(t: Object) -> void:
	var level := _make_level()
	var hero := _make_mage(0)
	hero.level = level
	var hero_pos: int = ConstantsData.xy_to_pos(5, 5)
	var ally_pos: int = ConstantsData.xy_to_pos(6, 5)
	hero.pos = hero_pos
	var ally := _make_ally(level, ally_pos)
	ally.paralysed = 1
	ally.interact(hero)
	t.check(hero.pos == hero_pos and ally.pos == ally_pos,
		"Plain swap is blocked while the ally is paralysed")
	ally.free()
	hero.free()

func _test_warp_range_swap(t: Object) -> void:
	var level := _make_level()
	var hero := _make_mage(2)
	hero.level = level
	var hero_pos: int = ConstantsData.xy_to_pos(5, 5)
	var ally_pos: int = ConstantsData.xy_to_pos(9, 5)
	hero.pos = hero_pos
	var ally := _make_ally(level, ally_pos)
	ally.interact(hero)
	t.check(hero.pos == ally_pos and ally.pos == hero_pos,
		"+2: warp swaps with an ally 4 tiles away")
	ally.free()
	hero.free()

func _test_warp_blocked_by_walls(t: Object) -> void:
	var level := _make_level()
	# Wall off the ally's cell completely so no passable route exists.
	var ally_pos: int = ConstantsData.xy_to_pos(9, 5)
	for dir: int in ConstantsData.DIRS_8:
		level.map[ally_pos + dir] = ConstantsData.Terrain.WALL
	level.build_flag_maps()
	var hero := _make_mage(3)
	hero.level = level
	var hero_pos: int = ConstantsData.xy_to_pos(5, 5)
	hero.pos = hero_pos
	var ally := _make_ally(level, ally_pos)
	ally.interact(hero)
	t.check(hero.pos == hero_pos and ally.pos == ally_pos,
		"Warp is blocked when no passable route reaches the ally")
	ally.free()
	hero.free()

func _test_hero_interact_free_action(t: Object) -> void:
	var level := _make_level()
	var hero := _make_mage(1)
	hero.level = level
	var hero_pos: int = ConstantsData.xy_to_pos(5, 5)
	var ally_pos: int = ConstantsData.xy_to_pos(7, 5)
	hero.pos = hero_pos
	var ally := _make_ally(level, ally_pos)
	hero._do_interact(ally_pos)
	t.check(hero.pos == ally_pos and ally.pos == hero_pos,
		"Hero interact action performs the warp swap at range")
	t.check(hero._interact_was_free,
		"Ally Warp swap is flagged as a free (instant) action")
	hero._interact_was_free = false
	ally.free()
	hero.free()
