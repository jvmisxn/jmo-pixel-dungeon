extends RefCounted
## Amok target-priority parity (upstream Mob.chooseEnemy amok branch):
## an enraged mob targets visible enemy-aligned mobs first, then ally mobs,
## then heroes — nearest of the winning pool, never itself, NPCs, hidden
## mimics, or invisible chars. Also covers the wandering-state pickup: an
## amok'd wanderer starts hunting a visible mob without hero involvement.


func run(t: Object) -> void:
	seed(0xA40C)

	var original_hero: Node = GameManager.hero
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_level: Level = GameManager.current_level

	_test_enemy_mob_beats_closer_hero(t)
	_test_enemy_pool_beats_ally_pool(t)
	_test_ally_pool_beats_hero(t)
	_test_hero_fallback(t)
	_test_exclusions(t)
	_test_nearest_in_pool(t)
	_test_wandering_pickup(t)

	GameManager.hero = original_hero
	GameManager.heroes = original_heroes
	GameManager.current_level = original_level


func _make_level() -> Level:
	var level := Level.new()
	level.depth = 5
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	level.visible.resize(ConstantsData.LENGTH)
	level.visible.fill(true)
	return level


func _make_hero(level: Level, hero_pos: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.level = level
	hero.pos = hero_pos
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = level
	GameManager.add_hero(hero)
	return hero


func _make_mob(level: Level, mob_pos: int, ally: bool = false) -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = 20
	mob.hp = 20
	mob.pos = mob_pos
	mob.is_ally = ally
	level.add_mob(mob)
	return mob


func _amok(level: Level, mob_pos: int) -> Mob:
	var mob := _make_mob(level, mob_pos)
	var buff := Amok.new()
	buff.set_duration(5.0)
	mob.add_buff(buff)
	return mob


func _test_enemy_mob_beats_closer_hero(t: Object) -> void:
	var level := _make_level()
	var rager := _amok(level, ConstantsData.xy_to_pos(5, 5))
	_make_hero(level, ConstantsData.xy_to_pos(6, 5))
	var victim := _make_mob(level, ConstantsData.xy_to_pos(9, 5))
	t.check(rager._amok_target() == victim,
		"Amok prefers a visible enemy mob over a closer hero")


func _test_enemy_pool_beats_ally_pool(t: Object) -> void:
	var level := _make_level()
	var rager := _amok(level, ConstantsData.xy_to_pos(5, 5))
	_make_hero(level, ConstantsData.xy_to_pos(20, 20))
	_make_mob(level, ConstantsData.xy_to_pos(6, 5), true)
	var victim := _make_mob(level, ConstantsData.xy_to_pos(10, 5))
	t.check(rager._amok_target() == victim,
		"Enemy-aligned pool wins even when an ally mob is closer")


func _test_ally_pool_beats_hero(t: Object) -> void:
	var level := _make_level()
	var rager := _amok(level, ConstantsData.xy_to_pos(5, 5))
	_make_hero(level, ConstantsData.xy_to_pos(6, 5))
	var ally := _make_mob(level, ConstantsData.xy_to_pos(10, 5), true)
	t.check(rager._amok_target() == ally,
		"With no enemy mobs, ally mobs are targeted before the hero")


func _test_hero_fallback(t: Object) -> void:
	var level := _make_level()
	var rager := _amok(level, ConstantsData.xy_to_pos(5, 5))
	var hero := _make_hero(level, ConstantsData.xy_to_pos(9, 5))
	t.check(rager._amok_target() == hero,
		"With no other mobs visible, the hero is the amok target")


func _test_exclusions(t: Object) -> void:
	var level := _make_level()
	var rager := _amok(level, ConstantsData.xy_to_pos(5, 5))
	var hero := _make_hero(level, ConstantsData.xy_to_pos(12, 5))

	var npc := NPC.new()
	npc.is_alive = true
	npc.pos = ConstantsData.xy_to_pos(6, 5)
	level.add_mob(npc)

	var mimic := Mimic.new()
	mimic.set_mimic_level(5)
	mimic.pos = ConstantsData.xy_to_pos(7, 5)
	level.add_mob(mimic)

	var sneak := _make_mob(level, ConstantsData.xy_to_pos(8, 5))
	sneak.invisible = 1

	t.check(rager._amok_target() == hero,
		"NPCs, disguised mimics, and invisible mobs are never amok targets")

	mimic.reveal()
	t.check(rager._amok_target() == mimic,
		"A revealed mimic becomes a valid amok target")


func _test_nearest_in_pool(t: Object) -> void:
	var level := _make_level()
	var rager := _amok(level, ConstantsData.xy_to_pos(5, 5))
	_make_hero(level, ConstantsData.xy_to_pos(20, 20))
	var near := _make_mob(level, ConstantsData.xy_to_pos(8, 5))
	_make_mob(level, ConstantsData.xy_to_pos(12, 5))
	t.check(rager._amok_target() == near,
		"The nearest mob of the winning pool is chosen")


func _test_wandering_pickup(t: Object) -> void:
	var level := _make_level()
	var rager := _amok(level, ConstantsData.xy_to_pos(5, 5))
	rager.state = Mob.AIState.WANDERING
	_make_hero(level, ConstantsData.xy_to_pos(20, 20))
	# Adjacent victim: detection chance 1/(0.5 + 0) = 2.0 > 1, so the roll
	# always succeeds and the pickup is deterministic.
	var victim := _make_mob(level, ConstantsData.xy_to_pos(6, 5))
	rager._act_wandering()
	t.check(rager.state == Mob.AIState.HUNTING,
		"An amok'd wanderer with a visible mob starts hunting")
	t.check(rager.target == victim,
		"The wandering pickup targets the mob, not the distant hero")
