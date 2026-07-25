extends RefCounted
## Warlock Necromancer's Minions (upstream Mob.die): killing a soul marked
## mob has a 0.4*points/3 chance to raise a corrupted wraith at the corpse
## cell. Verified through Mob._necromancers_minions_on_kill with a forced
## roll so results stay deterministic.

func run(t: Object) -> void:
	_test_kill_raises_corrupted_wraith(t)
	_test_roll_at_or_above_chance_fails(t)
	_test_zero_points_never_triggers(t)
	_test_unmarked_mob_never_triggers(t)
	_test_non_warlock_never_triggers(t)
	_test_wraith_kills_never_chain(t)
	_test_occupied_corpse_cell_uses_neighbor(t)

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 3
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func _make_warlock(points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	hero.hero_subclass = ConstantsData.HeroSubclass.WARLOCK
	if points > 0:
		hero.talent_levels["warlock_necromancers_minions"] = points
	return hero

func _make_mob(marked: bool, level: Level, mob_pos: int) -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = 10
	mob.hp = 10
	mob.pos = mob_pos
	mob.level = level
	level.add_mob(mob)
	if marked:
		mob.add_buff(SoulMark.new())
	return mob

func _with_hero(hero: Hero, body: Callable) -> void:
	var prev: Variant = GameManager.hero
	GameManager.hero = hero
	body.call()
	GameManager.hero = prev

func _test_kill_raises_corrupted_wraith(t: Object) -> void:
	var level := _make_level()
	var hero := _make_warlock(3)
	var mob := _make_mob(true, level, ConstantsData.xy_to_pos(5, 5))
	_with_hero(hero, func() -> void:
		var wraith: Variant = mob._necromancers_minions_on_kill(0.0)
		t.check(wraith != null, "Roll 0.0 with 3 points raises a wraith (chance 0.4)")
		if wraith != null:
			t.check(wraith.mob_id == "wraith", "Raised minion is a wraith")
			t.check(wraith.pos == mob.pos, "Wraith rises at the corpse cell")
			t.check(wraith.has_buff("Corruption"), "Raised wraith is corrupted")
			t.check(wraith.is_ally, "Corrupted wraith fights as an ally")
			t.check(wraith.xp_value == 0, "Corrupted wraith grants no XP")
			t.check(wraith in level.mobs, "Wraith is registered with the level")
	)
	mob.free()
	hero.free()

func _test_roll_at_or_above_chance_fails(t: Object) -> void:
	var level := _make_level()
	var hero := _make_warlock(1)
	var mob := _make_mob(true, level, ConstantsData.xy_to_pos(5, 5))
	_with_hero(hero, func() -> void:
		t.check(mob._necromancers_minions_on_kill(0.14) == null,
			"Roll 0.14 with 1 point fails (chance 0.1333)")
		t.check(mob._necromancers_minions_on_kill(0.99) == null,
			"Roll 0.99 always fails")
		t.check(mob._necromancers_minions_on_kill(0.13) != null,
			"Roll 0.13 with 1 point succeeds (just under 0.1333)")
	)
	mob.free()
	hero.free()

func _test_zero_points_never_triggers(t: Object) -> void:
	var level := _make_level()
	var hero := _make_warlock(0)
	var mob := _make_mob(true, level, ConstantsData.xy_to_pos(5, 5))
	_with_hero(hero, func() -> void:
		t.check(mob._necromancers_minions_on_kill(0.0) == null,
			"Zero talent points never raise a wraith")
	)
	mob.free()
	hero.free()

func _test_unmarked_mob_never_triggers(t: Object) -> void:
	var level := _make_level()
	var hero := _make_warlock(3)
	var mob := _make_mob(false, level, ConstantsData.xy_to_pos(5, 5))
	_with_hero(hero, func() -> void:
		t.check(mob._necromancers_minions_on_kill(0.0) == null,
			"Unmarked mob kills never raise a wraith")
	)
	mob.free()
	hero.free()

func _test_non_warlock_never_triggers(t: Object) -> void:
	var level := _make_level()
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	hero.hero_subclass = ConstantsData.HeroSubclass.BATTLEMAGE
	hero.talent_levels["warlock_necromancers_minions"] = 3
	var mob := _make_mob(true, level, ConstantsData.xy_to_pos(5, 5))
	_with_hero(hero, func() -> void:
		t.check(mob._necromancers_minions_on_kill(0.0) == null,
			"Non-Warlock subclasses never raise wraiths")
	)
	mob.free()
	hero.free()

func _test_wraith_kills_never_chain(t: Object) -> void:
	var level := _make_level()
	var hero := _make_warlock(3)
	var mob := _make_mob(true, level, ConstantsData.xy_to_pos(5, 5))
	mob.mob_id = "wraith"
	_with_hero(hero, func() -> void:
		t.check(mob._necromancers_minions_on_kill(0.0) == null,
			"Killing a wraith never raises another wraith")
	)
	mob.free()
	hero.free()

func _test_occupied_corpse_cell_uses_neighbor(t: Object) -> void:
	var level := _make_level()
	var hero := _make_warlock(3)
	var corpse_pos: int = ConstantsData.xy_to_pos(5, 5)
	var mob := _make_mob(true, level, corpse_pos)
	# Park another mob on the corpse cell (e.g. simultaneous deaths/swaps).
	var blocker := _make_mob(false, level, corpse_pos)
	_with_hero(hero, func() -> void:
		var wraith: Variant = mob._necromancers_minions_on_kill(0.0)
		t.check(wraith != null, "Blocked corpse cell still raises a wraith")
		if wraith != null:
			t.check(wraith.pos != corpse_pos and level.distance(wraith.pos, corpse_pos) <= 1,
				"Wraith falls back to an adjacent free cell")
	)
	mob.free()
	blocker.free()
	hero.free()
