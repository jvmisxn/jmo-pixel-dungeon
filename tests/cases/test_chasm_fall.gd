extends RefCounted

class FallSceneStub:
	extends RefCounted

	var _game_ended: bool = false
	var _current_level: Level = null
	var refreshed: bool = false

	func _is_online_host() -> bool:
		return false

	func refresh_after_turn() -> void:
		refreshed = true

func _make_level(chasm_pos: int) -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.map[chasm_pos] = ConstantsData.Terrain.CHASM
	level.build_flag_maps()
	return level

func _make_hero(pos: int, level: Level) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.pos = pos
	hero.level = level
	hero.hp = 60
	hero.hp_max = 60
	hero.ht = 60
	return hero

func run(t: Object) -> void:
	var chasm_pos: int = ConstantsData.xy_to_pos(10, 10)
	var level: Level = _make_level(chasm_pos)
	var hero: Hero = _make_hero(chasm_pos, level)

	t.check(
		level.get_terrain(chasm_pos) == ConstantsData.Terrain.CHASM,
		"test level marks the fall cell as a chasm"
	)
	var fall_roll: int = Chasm.fall_damage(hero)
	t.check(fall_roll >= 10 and fall_roll <= 20, "chasm fall damage stays in SPD's HT/6..HT/3 range")
	t.check(not Chasm.can_cross(hero), "grounded hero cannot cross chasms safely")

	seed(0xC4A5)
	var damage: int = Chasm.apply_landing_damage(hero, level)
	t.check(damage >= 10 and damage <= 20, "landing damage reports the SPD fall amount")
	t.check(hero.hp == 60 - damage, "landing damage reduces HP without instant-killing the hero")
	t.check(hero.has_buff("Cripple"), "landing damage applies cripple")

	var levitating_hero: Hero = _make_hero(chasm_pos, level)
	var levitation := Levitation.new()
	levitating_hero.add_buff(levitation)
	t.check(Chasm.can_cross(levitating_hero), "Levitation buff allows safe chasm crossing")

	var fell_hero: Array[Variant] = [null]
	if EventBus != null and EventBus.has_signal("hero_fell"):
		var on_fell: Callable = func(hero_node: Variant) -> void:
			fell_hero[0] = hero_node
		EventBus.hero_fell.connect(on_fell, CONNECT_ONE_SHOT)
		var falling_hero: Hero = _make_hero(chasm_pos, level)
		falling_hero._check_terrain_effects()
		t.check(fell_hero[0] == falling_hero, "hero on chasm emits fall transition event")
		t.check(falling_hero.hp == 60, "chasm terrain event no longer kills in place")
		falling_hero.free()

	var safe_hero: Hero = _make_hero(chasm_pos, level)
	safe_hero.add_buff(Levitation.new())
	fell_hero[0] = null
	if EventBus != null and EventBus.has_signal("hero_fell"):
		var on_safe_fell: Callable = func(hero_node: Variant) -> void:
			fell_hero[0] = hero_node
		EventBus.hero_fell.connect(on_safe_fell, CONNECT_ONE_SHOT)
	safe_hero._check_terrain_effects()
	t.check(fell_hero[0] == null, "levitating hero on chasm does not emit fall event")
	t.check(safe_hero.hp == 60, "levitating hero takes no chasm damage")

	var original_depth: int = GameManager.depth
	GameManager.depth = ConstantsData.MAX_DEPTH
	var bottom_level: Level = _make_level(chasm_pos)
	var bottom_hero: Hero = _make_hero(chasm_pos, bottom_level)
	var bottom_scene := FallSceneStub.new()
	bottom_scene._current_level = bottom_level
	seed(0xC4A5)
	FloorTransitionCoordinator.handle_fall(bottom_scene, bottom_hero)
	t.check(bottom_scene.refreshed, "bottom-depth chasm fall refreshes without transitioning")
	t.check(bottom_hero.pos != chasm_pos, "bottom-depth chasm fall moves hero off the chasm")
	t.check(bottom_level.is_passable(bottom_hero.pos), "bottom-depth chasm fall lands on a passable cell")
	t.check(bottom_hero.hp >= 40 and bottom_hero.hp <= 50, "bottom-depth chasm fall applies landing damage once")
	GameManager.depth = original_depth

	hero.free()
	levitating_hero.free()
	safe_hero.free()
	bottom_hero.free()
