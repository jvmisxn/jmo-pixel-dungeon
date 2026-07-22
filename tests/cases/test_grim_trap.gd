extends RefCounted
## GrimTrap parity with current Shattered Pixel Dungeon: target the character on
## the trap cell or closest aimable character, deal round(HT/2 + HP/2), and cap
## hero damage at 90% HT. The old low-HP instakill + Weakness path must stay gone.

func run(t: Object) -> void:
	_test_character_on_trap_takes_psi_blast_damage(t)
	_test_hero_damage_caps_at_ninety_percent_ht(t)
	_test_closest_aimable_target_is_hit(t)
	_test_blocked_or_too_far_targets_are_ignored(t)
	_test_diagonal_target_uses_true_distance_range(t)
	_test_invisible_targets_count_as_max_range(t)

func _make_level(depth: int = 22) -> Level:
	var level := Level.new()
	level.depth = depth
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func _make_char(pos: int, level: Level, hp: int = 100, ht: int = 100) -> Char:
	var ch := Char.new()
	ch.pos = pos
	ch.level = level
	ch.hp_max = ht
	ch.ht = ht
	ch.hp = hp
	ch.is_alive = true
	return ch

func _make_hero(pos: int, level: Level, hp: int = 100, ht: int = 100) -> Hero:
	var hero := Hero.new()
	hero.pos = pos
	hero.level = level
	hero.hp_max = ht
	hero.ht = ht
	hero.hp = hp
	hero.is_alive = true
	return hero

func _test_character_on_trap_takes_psi_blast_damage(t: Object) -> void:
	var old_heroes: Array[Node] = GameManager.heroes.duplicate() if GameManager != null else []
	if GameManager != null:
		GameManager.heroes.clear()
	var trap_pos: int = ConstantsData.xy_to_pos(10, 10)
	var level: Level = _make_level()
	level.set_terrain(trap_pos, ConstantsData.Terrain.TRAP)
	var mob := _make_char(trap_pos, level, 40, 100)
	level.mobs = [mob] as Array[Node]
	var trap := GrimTrap.new()
	trap.set_pos(trap_pos)

	trap.activate(null, level)

	t.check(trap.visible, "grim trap starts visible like upstream")
	t.check(mob.hp == 0, "grim trap deals round(HT/2 + HP/2) damage")
	t.check(not mob.has_buff("Weakness"), "grim trap does not apply the old invented Weakness debuff")
	t.check(level.terrain_at(trap_pos) == ConstantsData.Terrain.INACTIVE_TRAP,
		"grim trap is consumed as a one-shot")

	_free_nodes([mob])
	if GameManager != null:
		GameManager.heroes = old_heroes

func _test_hero_damage_caps_at_ninety_percent_ht(t: Object) -> void:
	var old_heroes: Array[Node] = GameManager.heroes.duplicate() if GameManager != null else []
	var trap_pos: int = ConstantsData.xy_to_pos(10, 10)
	var level: Level = _make_level()
	var hero := _make_hero(trap_pos, level, 100, 100)
	if GameManager != null:
		GameManager.heroes = [hero]
	var trap := GrimTrap.new()
	trap.set_pos(trap_pos)

	trap._do_effect(hero, level)

	t.check(hero.hp == 10, "hero grim damage is capped at 90% HT")
	t.check(hero.is_alive, "a full-health hero survives the capped grim hit")

	_free_nodes([hero])
	if GameManager != null:
		GameManager.heroes = old_heroes

func _test_closest_aimable_target_is_hit(t: Object) -> void:
	var old_heroes: Array[Node] = GameManager.heroes.duplicate() if GameManager != null else []
	if GameManager != null:
		GameManager.heroes.clear()
	var trap_pos: int = ConstantsData.xy_to_pos(10, 10)
	var level: Level = _make_level()
	var near := _make_char(ConstantsData.xy_to_pos(13, 10), level, 100, 100)
	var far := _make_char(ConstantsData.xy_to_pos(16, 10), level, 100, 100)
	level.mobs = [near, far] as Array[Node]
	var trap := GrimTrap.new()
	trap.set_pos(trap_pos)

	trap._do_effect(null, level)

	t.check(near.hp == 0, "grim trap targets the closest aimable character")
	t.check(far.hp == 100, "farther aimable characters are not hit")

	_free_nodes([near, far])
	if GameManager != null:
		GameManager.heroes = old_heroes

func _test_blocked_or_too_far_targets_are_ignored(t: Object) -> void:
	var old_heroes: Array[Node] = GameManager.heroes.duplicate() if GameManager != null else []
	if GameManager != null:
		GameManager.heroes.clear()
	var trap_pos: int = ConstantsData.xy_to_pos(10, 10)
	var level: Level = _make_level()
	var blocked := _make_char(ConstantsData.xy_to_pos(13, 10), level, 100, 100)
	var too_far := _make_char(ConstantsData.xy_to_pos(25, 10), level, 100, 100)
	level.mobs = [blocked, too_far] as Array[Node]
	level.set_terrain(ConstantsData.xy_to_pos(12, 10), ConstantsData.Terrain.WALL)
	var trap := GrimTrap.new()
	trap.set_pos(trap_pos)

	trap._do_effect(null, level)

	t.check(blocked.hp == 100, "grim trap ignores targets blocked by projectile terrain")
	t.check(too_far.hp == 100, "grim trap ignores aimable targets past trap range")

	_free_nodes([blocked, too_far])
	if GameManager != null:
		GameManager.heroes = old_heroes

func _test_diagonal_target_uses_true_distance_range(t: Object) -> void:
	var old_heroes: Array[Node] = GameManager.heroes.duplicate() if GameManager != null else []
	if GameManager != null:
		GameManager.heroes.clear()
	var trap_pos: int = ConstantsData.xy_to_pos(10, 10)
	var level: Level = _make_level()
	var diagonal := _make_char(ConstantsData.xy_to_pos(17, 17), level, 100, 100)
	level.mobs = [diagonal] as Array[Node]
	var trap := GrimTrap.new()
	trap.set_pos(trap_pos)

	trap._do_effect(null, level)

	t.check(diagonal.hp == 100,
		"grim trap range uses Euclidean trueDistance, not Chebyshev distance")

	_free_nodes([diagonal])
	if GameManager != null:
		GameManager.heroes = old_heroes

func _test_invisible_targets_count_as_max_range(t: Object) -> void:
	var old_heroes: Array[Node] = GameManager.heroes.duplicate() if GameManager != null else []
	if GameManager != null:
		GameManager.heroes.clear()
	var trap_pos: int = ConstantsData.xy_to_pos(10, 10)
	var level: Level = _make_level()
	var invisible := _make_char(ConstantsData.xy_to_pos(11, 11), level, 100, 100)
	invisible.invisible = 5
	var visible := _make_char(ConstantsData.xy_to_pos(16, 10), level, 100, 100)
	level.mobs = [invisible, visible] as Array[Node]
	var trap := GrimTrap.new()
	trap.set_pos(trap_pos)

	trap._do_effect(null, level)

	t.check(invisible.hp == 100, "invisible close targets are treated as max-range")
	t.check(visible.hp == 0, "a farther visible target can be closer than an invisible one")

	_free_nodes([invisible, visible])
	if GameManager != null:
		GameManager.heroes = old_heroes

func _free_nodes(nodes: Array) -> void:
	for node: Variant in nodes:
		if node != null and is_instance_valid(node):
			if TurnManager != null and TurnManager.has_actor(node):
				TurnManager.remove_actor(node)
			if node is Node:
				(node as Node).free()
