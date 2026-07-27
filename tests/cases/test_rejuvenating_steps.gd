extends RefCounted
## Huntress Rejuvenating Steps (upstream Level.occupyCell + Talent counters):
## stepping on short grass or embers off cooldown sprouts tall grass that the
## Huntress immediately furrows (with trample drop rolls), counts the furrow
## counter up by 3 - points, and starts a 15 - 5*points turn cooldown (10/5).
## At furrow count >= 200 the sprout comes up already furrowed with no drops.
## Exp gain counts the furrow down by 200x the level fraction gained
## (Hero.earn_xp), detaching at 0.

func run(t: Object) -> void:
	_test_registry(t)
	_test_no_talent_no_sprout(t)
	_test_sprout_and_cooldown(t)
	_test_cooldown_gates(t)
	_test_embers_sprout(t)
	_test_furrow_threshold(t)
	_test_exp_counts_furrow_down(t)
	_test_furrow_serialize(t)

func _make_level(terrain: int, cell: int) -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.map[cell] = terrain
	level.build_flag_maps()
	return level

func _make_huntress(points: int, level: Level, cell: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	if points > 0:
		hero.talent_levels["huntress_rejuvenating_steps"] = points
	hero.level = level
	hero.pos = cell
	return hero

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.HUNTRESS, "huntress_rejuvenating_steps")
	t.check(info != null, "huntress_rejuvenating_steps is registered")
	if info != null:
		t.check(info.tier == 2 and info.max_points == 2 and info.implemented,
			"Rejuvenating Steps is an implemented 2-point T2 talent")

func _test_no_talent_no_sprout(t: Object) -> void:
	var cell: int = ConstantsData.xy_to_pos(10, 10)
	var level := _make_level(ConstantsData.Terrain.GRASS, cell)
	var hero := _make_huntress(0, level, cell)
	hero._check_terrain_effects()
	t.check(level.get_terrain(cell) == ConstantsData.Terrain.GRASS,
		"no talent: stepping on grass leaves it as short grass")
	t.check(not hero.has_buff("RejuvenatingStepsCooldown")
		and not hero.has_buff("RejuvenatingStepsFurrow"),
		"no talent: no rejuvenating steps buffs attach")
	hero.free()

func _test_sprout_and_cooldown(t: Object) -> void:
	for points: int in [1, 2]:
		var cell: int = ConstantsData.xy_to_pos(10, 10)
		var level := _make_level(ConstantsData.Terrain.GRASS, cell)
		var hero := _make_huntress(points, level, cell)
		hero._check_terrain_effects()
		t.check(level.get_terrain(cell) == ConstantsData.Terrain.FURROWED_GRASS,
			"+%d: stepping on grass furrows it" % points)
		var cd: Variant = hero.get_buff("RejuvenatingStepsCooldown")
		t.check(cd != null and absf(cd.get_time_left() - (15.0 - 5.0 * points)) < 0.001,
			"+%d: cooldown lasts %d turns" % [points, 15 - 5 * points])
		var furrow: Variant = hero.get_buff("RejuvenatingStepsFurrow")
		t.check(furrow != null and absf(furrow.count - float(3 - points)) < 0.001,
			"+%d: furrow counter counts up by %d" % [points, 3 - points])
		hero.free()

func _test_cooldown_gates(t: Object) -> void:
	var cell_a: int = ConstantsData.xy_to_pos(10, 10)
	var cell_b: int = ConstantsData.xy_to_pos(11, 10)
	var level := _make_level(ConstantsData.Terrain.GRASS, cell_a)
	level.set_terrain(cell_b, ConstantsData.Terrain.GRASS)
	var hero := _make_huntress(1, level, cell_a)
	hero._check_terrain_effects()
	hero.pos = cell_b
	hero._check_terrain_effects()
	t.check(level.get_terrain(cell_b) == ConstantsData.Terrain.GRASS,
		"second grass step during cooldown sprouts nothing")
	hero.free()

func _test_embers_sprout(t: Object) -> void:
	var cell: int = ConstantsData.xy_to_pos(10, 10)
	var level := _make_level(ConstantsData.Terrain.EMBERS, cell)
	var hero := _make_huntress(2, level, cell)
	hero._check_terrain_effects()
	t.check(level.get_terrain(cell) == ConstantsData.Terrain.FURROWED_GRASS,
		"+2: stepping on embers furrows them into grass")
	t.check(hero.has_buff("RejuvenatingStepsCooldown"),
		"embers sprout starts the cooldown")
	hero.free()

func _test_furrow_threshold(t: Object) -> void:
	var cell: int = ConstantsData.xy_to_pos(10, 10)
	var level := _make_level(ConstantsData.Terrain.GRASS, cell)
	var hero := _make_huntress(1, level, cell)
	var furrow := RejuvenatingStepsFurrow.new()
	hero.add_buff(furrow)
	furrow.count = 200.0
	hero._check_terrain_effects()
	t.check(level.get_terrain(cell) == ConstantsData.Terrain.FURROWED_GRASS,
		"at furrow >= 200 the sprout is directly furrowed")
	t.check(absf(furrow.count - 200.0) < 0.001,
		"direct-furrow sprouts do not count the furrow up")
	t.check(hero.has_buff("RejuvenatingStepsCooldown"),
		"direct-furrow sprouts still start the cooldown")
	hero.free()

func _test_exp_counts_furrow_down(t: Object) -> void:
	var hero := _make_huntress(1, null, 0)
	var furrow := RejuvenatingStepsFurrow.new()
	hero.add_buff(furrow)
	furrow.count = 150.0
	# Gaining a quarter of a level counts the furrow down by 50.
	var quarter: int = int(hero.xp_to_next / 4.0)
	var expected: float = furrow.count - (float(quarter) / float(hero.xp_to_next)) * 200.0
	hero.earn_xp(quarter)
	t.check(absf(furrow.count - expected) < 0.001,
		"exp gain counts the furrow down by 200x the level fraction")
	# Enough further exp drives it to 0 and detaches the counter.
	hero.earn_xp(hero.xp_to_next)
	t.check(not hero.has_buff("RejuvenatingStepsFurrow"),
		"furrow counter detaches once counted down to 0")
	hero.free()

func _test_furrow_serialize(t: Object) -> void:
	var furrow := RejuvenatingStepsFurrow.new()
	furrow.count = 42.5
	var data: Dictionary = furrow.serialize()
	var restored := RejuvenatingStepsFurrow.new()
	restored.deserialize(data)
	t.check(absf(restored.count - 42.5) < 0.001,
		"furrow count survives a serialize round trip")
	t.check(not restored.show_in_ui and restored.revive_persists,
		"furrow counter is hidden and revive-persistent")
	furrow.free()
	restored.free()
