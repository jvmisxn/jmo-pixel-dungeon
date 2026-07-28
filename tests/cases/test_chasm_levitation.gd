extends RefCounted
## Levitation/flight vs chasms (upstream AVOID semantics): a flying or
## levitating char can step onto a chasm cell (Char.flying makes avoid cells
## walkable, occupyCell skips heroFall while flying), while a grounded char
## still cannot move_to it. When Levitation detaches over a chasm (upstream
## Levitation.detach -> occupyCell), the hero falls via `hero_fell` and a mob
## dies to the fall (Chasm.mobFall).

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
	_test_grounded_move_refused(t)
	_test_levitating_move_crosses(t)
	_test_flying_flag_move_crosses(t)
	_test_levitation_detach_over_chasm_falls(t)
	_test_levitation_detach_on_floor_safe(t)
	_test_levitation_detach_mob_dies(t)

func _test_grounded_move_refused(t: Object) -> void:
	var level: Level = _make_level()
	var hero: Hero = _make_hero(level)
	var chasm_pos: int = ConstantsData.xy_to_pos(CHASM_X, ROW_Y)

	t.check(not hero.move_to(chasm_pos),
		"a grounded hero cannot move_to a chasm cell")
	t.check(hero.pos != chasm_pos, "the grounded hero stays put")

	hero.free()

func _test_levitating_move_crosses(t: Object) -> void:
	var level: Level = _make_level()
	var hero: Hero = _make_hero(level)
	hero.add_buff(Levitation.new())
	var fell: Array[Variant] = _capture_fell()
	var chasm_pos: int = ConstantsData.xy_to_pos(CHASM_X, ROW_Y)

	t.check(hero.move_to(chasm_pos),
		"a levitating hero can step onto a chasm cell")
	t.check(hero.pos == chasm_pos, "the levitating hero occupies the chasm cell")
	hero._check_terrain_effects()
	t.check(fell[0] == null, "floating over the chasm does not trigger a fall")

	_release_fell(fell)
	hero.remove_buff_by_id("Levitation")
	hero.free()

func _test_flying_flag_move_crosses(t: Object) -> void:
	var level: Level = _make_level()
	var hero: Hero = _make_hero(level)
	hero.flying = true
	var chasm_pos: int = ConstantsData.xy_to_pos(CHASM_X, ROW_Y)

	t.check(hero.move_to(chasm_pos),
		"an intrinsically flying char can step onto a chasm cell")

	hero.flying = false
	hero.free()

func _test_levitation_detach_over_chasm_falls(t: Object) -> void:
	var level: Level = _make_level()
	var hero: Hero = _make_hero(level)
	hero.add_buff(Levitation.new())
	var chasm_pos: int = ConstantsData.xy_to_pos(CHASM_X, ROW_Y)
	hero.move_to(chasm_pos)
	var fell: Array[Variant] = _capture_fell()

	hero.remove_buff_by_id("Levitation")

	t.check(fell[0] == hero,
		"levitation ending over a chasm drops the hero via hero_fell")

	_release_fell(fell)
	hero.free()

func _test_levitation_detach_on_floor_safe(t: Object) -> void:
	var level: Level = _make_level()
	var hero: Hero = _make_hero(level)
	hero.add_buff(Levitation.new())
	var fell: Array[Variant] = _capture_fell()

	hero.remove_buff_by_id("Levitation")

	t.check(fell[0] == null,
		"levitation ending on normal floor does not trigger a fall")

	_release_fell(fell)
	hero.free()

func _test_levitation_detach_mob_dies(t: Object) -> void:
	var level: Level = _make_level()
	var mob: Mob = Mob.new()
	mob.pos = ConstantsData.xy_to_pos(CHASM_X, ROW_Y)
	mob.level = level
	mob.hp = 10
	mob.hp_max = 10
	mob.add_buff(Levitation.new())

	mob.remove_buff_by_id("Levitation")

	t.check(not mob.is_alive,
		"a mob whose levitation ends over a chasm dies to the fall")

	mob.free()
