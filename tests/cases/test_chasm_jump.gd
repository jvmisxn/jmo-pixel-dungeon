extends RefCounted
## Voluntary walk-in chasm entry (upstream Chasm.heroJump -> jumpConfirmed ->
## Level.occupyCell -> Chasm.heroFall): the input layer shows a confirm
## prompt for an adjacent chasm tap; the confirmed "chasm_jump" action makes
## the hero descend via the shared `hero_fell` path. Flying heroes glide over
## and never fall, rooted heroes can't leap, and the action re-validates that
## the tapped cell is still an adjacent chasm.

const ROW_Y: int = 5
const HERO_X: int = 4
const CHASM_X: int = 5

func _make_level() -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.map[ConstantsData.xy_to_pos(CHASM_X, ROW_Y)] = ConstantsData.Terrain.CHASM
	level.build_flag_maps()
	return level

func _make_hero(level: Level) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.pos = ConstantsData.xy_to_pos(HERO_X, ROW_Y)
	hero.level = level
	hero.hp = 60
	hero.hp_max = 60
	hero.ht = 60
	return hero

func _capture_fell() -> Array[Variant]:
	var fell_hero: Array[Variant] = [null, null]
	if EventBus != null and EventBus.has_signal("hero_fell"):
		var on_fell: Callable = func(hero_node: Variant) -> void:
			fell_hero[0] = hero_node
		fell_hero[1] = on_fell
		EventBus.hero_fell.connect(on_fell, CONNECT_ONE_SHOT)
	return fell_hero

## Drop an unfired one-shot connection so it can't linger into later tests.
func _release_fell(fell: Array[Variant]) -> void:
	if fell[1] != null and EventBus != null \
			and EventBus.hero_fell.is_connected(fell[1]):
		EventBus.hero_fell.disconnect(fell[1])

func run(t: Object) -> void:
	_test_confirmed_jump_falls(t)
	_test_flying_hero_does_not_fall(t)
	_test_rooted_hero_does_not_fall(t)
	_test_non_adjacent_target_refused(t)
	_test_non_chasm_target_refused(t)

func _test_confirmed_jump_falls(t: Object) -> void:
	var level: Level = _make_level()
	var hero: Hero = _make_hero(level)
	var fell: Array[Variant] = _capture_fell()

	hero._do_chasm_jump(ConstantsData.xy_to_pos(CHASM_X, ROW_Y))

	t.check(fell[0] == hero,
		"confirmed chasm jump descends via the shared hero_fell path")
	t.check(hero.is_alive, "the jump itself does not kill the hero in place")

	hero.free()

func _test_flying_hero_does_not_fall(t: Object) -> void:
	var level: Level = _make_level()
	var hero: Hero = _make_hero(level)
	hero.flying = true
	var fell: Array[Variant] = _capture_fell()

	hero._do_chasm_jump(ConstantsData.xy_to_pos(CHASM_X, ROW_Y))

	t.check(fell[0] == null, "a flying hero glides over and never falls")

	hero.flying = false
	_release_fell(fell)
	hero.free()

func _test_rooted_hero_does_not_fall(t: Object) -> void:
	var level: Level = _make_level()
	var hero: Hero = _make_hero(level)
	hero.add_buff(Rooted.new())
	var fell: Array[Variant] = _capture_fell()

	hero._do_chasm_jump(ConstantsData.xy_to_pos(CHASM_X, ROW_Y))

	t.check(fell[0] == null, "a rooted hero cannot leap into the chasm")

	_release_fell(fell)
	hero.free()

func _test_non_adjacent_target_refused(t: Object) -> void:
	var level: Level = _make_level()
	var hero: Hero = _make_hero(level)
	hero.pos = ConstantsData.xy_to_pos(HERO_X - 3, ROW_Y)
	var fell: Array[Variant] = _capture_fell()

	hero._do_chasm_jump(ConstantsData.xy_to_pos(CHASM_X, ROW_Y))

	t.check(fell[0] == null,
		"a chasm cell that is no longer adjacent is refused")

	_release_fell(fell)
	hero.free()

func _test_non_chasm_target_refused(t: Object) -> void:
	var level: Level = _make_level()
	var hero: Hero = _make_hero(level)
	var fell: Array[Variant] = _capture_fell()

	hero._do_chasm_jump(ConstantsData.xy_to_pos(HERO_X + 1, ROW_Y - 1))

	t.check(fell[0] == null,
		"a confirmed jump onto a non-chasm cell is refused (terrain changed)")

	_release_fell(fell)
	hero.free()
