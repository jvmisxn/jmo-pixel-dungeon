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
	_test_pitfall_trap_uses_fall_handoff(t)
	_test_fall_from_weak_floor_prefers_pit_room_landing(t)
	_test_fall_source_room_detection(t)

	var chasm_pos: int = ConstantsData.xy_to_pos(10, 10)
	var level: Level = _make_level(chasm_pos)
	var hero: Hero = _make_hero(chasm_pos, level)

	t.check(
		level.get_terrain(chasm_pos) == ConstantsData.Terrain.CHASM,
		"test level marks the fall cell as a chasm"
	)
	var fall_roll: int = Chasm.fall_damage(hero)
	t.check(fall_roll == 30, "full-health chasm fall damage uses SPD's current-HP floor")
	t.check(not Chasm.can_cross(hero), "grounded hero cannot cross chasms safely")

	seed(0xC4A5)
	var damage: int = Chasm.apply_landing_damage(hero, level)
	t.check(damage == 30, "landing damage reports the SPD current-HP-scaled fall amount")
	t.check(hero.hp == 60 - damage, "landing damage reduces HP without instant-killing the hero")
	t.check(hero.has_buff("Cripple"), "landing damage applies cripple")
	var bleed: Bleeding = hero.get_buff("Bleeding") as Bleeding
	t.check(bleed != null, "landing damage applies bleeding")
	t.check(roundi(bleed.bleed_level) == 5, "full-health fall applies SPD's low bleed amount")

	var wounded_hero: Hero = _make_hero(chasm_pos, level)
	wounded_hero.hp = 15
	seed(0xC4A5)
	var wounded_damage: int = Chasm.fall_damage(wounded_hero)
	t.check(
		wounded_damage >= 7 and wounded_damage <= 15,
		"low-health chasm fall damage uses HP/2..HT/4 range"
	)
	t.check(
		roundi(Chasm.fall_bleed_level(wounded_hero)) == 8,
		"low-health chasm fall applies stronger SPD bleed"
	)

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
	t.check(bottom_hero.hp == 30, "bottom-depth chasm fall applies current-HP landing damage once")
	t.check(bottom_hero.has_buff("Bleeding"), "bottom-depth chasm fall applies landing bleed")
	GameManager.depth = original_depth

	hero.free()
	levitating_hero.free()
	wounded_hero.free()
	safe_hero.free()
	bottom_hero.free()

func _test_pitfall_trap_uses_fall_handoff(t: Object) -> void:
	var original_depth: int = GameManager.depth
	var original_hero: Node = GameManager.hero
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_level: Level = GameManager.current_level
	var trap_pos: int = ConstantsData.xy_to_pos(8, 8)
	var level: Level = _make_level(trap_pos)
	level.map[trap_pos] = ConstantsData.Terrain.TRAP
	level.build_flag_maps()
	GameManager.depth = 6
	GameManager.current_level = level

	var hero: Hero = _make_hero(trap_pos, level)
	GameManager.hero = hero
	GameManager.heroes = [hero]
	var fell_hero: Array[Variant] = [null]
	var on_fell: Callable = func(hero_node: Variant) -> void:
		fell_hero[0] = hero_node
	if EventBus != null and EventBus.has_signal("hero_fell"):
		EventBus.hero_fell.connect(on_fell)

	var trap := PitfallTrap.new()
	trap.set_pos(trap_pos)
	trap.activate(hero, level)

	t.check(fell_hero[0] == null, "pitfall trap waits for the delayed collapse before falling")
	t.check(hero.has_buff("DelayedPit"), "pitfall trap arms a DelayedPit warning buff")
	t.check(hero.hp == 60, "pitfall trap does not apply same-level proxy damage before transition")
	t.check(hero.pos == trap_pos, "pitfall trap no longer teleports the hero on the current level")
	t.check(not hero.has_buff("Cripple"), "pitfall trap leaves landing cripple to the fall arrival path")
	t.check(not trap.active, "pitfall trap remains one-shot after activation")
	t.check(
		level.get_terrain(trap_pos) == ConstantsData.Terrain.INACTIVE_TRAP,
		"pitfall trap tile becomes inactive after triggering"
	)

	hero.process_buffs()
	t.check(fell_hero[0] == hero, "pitfall trap routes heroes through the chasm fall transition")

	if EventBus != null and EventBus.has_signal("hero_fell") and EventBus.hero_fell.is_connected(on_fell):
		EventBus.hero_fell.disconnect(on_fell)
	hero.free()

	var levitating_hero: Hero = _make_hero(trap_pos, level)
	levitating_hero.add_buff(Levitation.new())
	GameManager.hero = levitating_hero
	GameManager.heroes = [levitating_hero]
	var levitating_fell: Array[Variant] = [null]
	var on_levitating_fell: Callable = func(hero_node: Variant) -> void:
		levitating_fell[0] = hero_node
	if EventBus != null and EventBus.has_signal("hero_fell"):
		EventBus.hero_fell.connect(on_levitating_fell)

	var levitating_trap := PitfallTrap.new()
	levitating_trap.set_pos(trap_pos)
	levitating_trap.activate(levitating_hero, level)
	levitating_hero.process_buffs()

	t.check(levitating_fell[0] == null, "pitfall trap does not drop levitating heroes")
	t.check(levitating_hero.hp == 60, "levitating hero takes no pitfall damage")
	t.check(levitating_hero.pos == trap_pos, "levitating hero is not teleported by pitfall trap")

	if EventBus != null and EventBus.has_signal("hero_fell") and EventBus.hero_fell.is_connected(on_levitating_fell):
		EventBus.hero_fell.disconnect(on_levitating_fell)
	levitating_hero.free()
	GameManager.depth = original_depth
	GameManager.hero = original_hero
	GameManager.heroes = original_heroes
	GameManager.current_level = original_level

func _test_fall_from_weak_floor_prefers_pit_room_landing(t: Object) -> void:
	var level := Level.new()
	level.depth = 9
	level.map.fill(ConstantsData.Terrain.WALL)
	var pit_room := PitRoom.new()
	pit_room.left = 8
	pit_room.top = 8
	pit_room.right = 16
	pit_room.bottom = 16
	level.rooms = [pit_room]
	pit_room.paint(level)
	level.entrance = ConstantsData.xy_to_pos(2, 2)
	level.exit_pos = ConstantsData.xy_to_pos(3, 2)
	level.map[level.entrance] = ConstantsData.Terrain.ENTRANCE
	level.map[level.exit_pos] = ConstantsData.Terrain.EXIT
	level.build_flag_maps()

	var loading := LoadingScene.new()
	loading._transition_type = "fall"
	loading._fall_into_pit = true
	var landing: int = loading._landing_anchor_for_transition(level)
	t.check(landing == pit_room.center(), "weak-floor falls land on the next floor's PitRoom platform")
	loading.free()

func _test_fall_source_room_detection(t: Object) -> void:
	var level := Level.new()
	level.map.fill(ConstantsData.Terrain.EMPTY)
	var weak_room := WeakFloorRoom.new()
	weak_room.left = 5
	weak_room.top = 5
	weak_room.right = 11
	weak_room.bottom = 11
	var ordinary_room := StandardRoom.new()
	ordinary_room.left = 15
	ordinary_room.top = 5
	ordinary_room.right = 21
	ordinary_room.bottom = 11
	level.rooms = [weak_room, ordinary_room]

	t.check(
		FloorTransitionCoordinator._is_weak_floor_room(level, weak_room.center()),
		"fall metadata detects source cells inside WeakFloorRoom"
	)
	t.check(
		not FloorTransitionCoordinator._is_weak_floor_room(level, ordinary_room.center()),
		"fall metadata does not mark ordinary-room falls as pit-room landings"
	)
