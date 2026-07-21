extends RefCounted

func run(t: Object) -> void:
	_test_gateway_persists_and_reuses_destination(t)
	_test_gateway_moves_ordinary_heaps(t)
	_test_gateway_serializes_tele_pos(t)

func _test_gateway_persists_and_reuses_destination(t: Object) -> void:
	seed(7)
	var old_heroes: Array[Node] = GameManager.heroes.duplicate()
	var level := _make_level()
	var trap_pos := ConstantsData.xy_to_pos(10, 10)
	var hero := Hero.new()
	hero.pos = trap_pos
	hero.level = level
	GameManager.heroes = [hero]
	var mob := Mob.new()
	mob.pos = trap_pos + 1
	mob.level = level
	mob.state = Mob.AIState.HUNTING
	level.add_mob(mob)

	var trap := GatewayTrap.new()
	level.place_trap(trap_pos, trap)
	level.set_terrain(trap_pos, ConstantsData.Terrain.TRAP)
	level.trigger_trap(trap_pos, hero)

	t.check(trap.active, "gateway trap is not consumed by activation")
	t.check(level.terrain_at(trap_pos) == ConstantsData.Terrain.TRAP,
		"gateway trap tile stays armed after terrain-driven activation")
	t.check(trap.tele_pos >= 0, "gateway trap records its destination")
	t.check(hero.pos == trap.tele_pos, "first nearby character establishes the gateway destination")
	t.check(mob.pos != trap_pos + 1, "second nearby character is moved through the gateway")
	t.check(level.distance(mob.pos, trap.tele_pos) <= 1,
		"second nearby character lands at or adjacent to the gateway destination")
	t.check(mob.state == Mob.AIState.WANDERING, "hunting mobs are reset after gateway teleport")

	var first_tele_pos: int = trap.tele_pos
	var second_mob := Mob.new()
	second_mob.pos = trap_pos
	second_mob.level = level
	level.add_mob(second_mob)
	level.trigger_trap(trap_pos, second_mob)

	t.check(trap.tele_pos == first_tele_pos, "gateway trap reuses its original destination")
	t.check(level.distance(second_mob.pos, first_tele_pos) <= 1,
		"later triggerers land at or adjacent to the existing gateway destination")
	t.check(level.terrain_at(trap_pos) == ConstantsData.Terrain.TRAP,
		"gateway trap tile remains armed after repeated activation")
	GameManager.heroes = old_heroes

func _test_gateway_moves_ordinary_heaps(t: Object) -> void:
	seed(11)
	var old_heroes: Array[Node] = GameManager.heroes.duplicate()
	GameManager.heroes = []
	var level := _make_level()
	var trap_pos := ConstantsData.xy_to_pos(8, 8)
	var heap_cell := trap_pos + ConstantsData.WIDTH
	var potion := Potion.create("healing")
	var second_potion := Potion.create("strength")
	level.drop_item(heap_cell, potion)
	level.drop_item(heap_cell, second_potion)

	var trap := GatewayTrap.new()
	trap.set_pos(trap_pos)
	trap.activate(null, level)

	t.check(trap.tele_pos >= 0, "heap-only gateway activation still establishes a destination")
	t.check(level.heaps_at(heap_cell).is_empty(), "gateway removes the ordinary heap from its source cell")
	var moved_heaps := level.heaps_at(trap.tele_pos)
	t.check(moved_heaps.size() == 2, "gateway drops all ordinary heap items at the gateway destination")
	var moved_items: Array = moved_heaps.map(func(heap: Dictionary) -> Variant: return heap.get("item"))
	t.check(moved_items.has(potion), "gateway preserves the first heap item identity")
	t.check(moved_items.has(second_potion), "gateway preserves the second heap item identity")
	GameManager.heroes = old_heroes

func _test_gateway_serializes_tele_pos(t: Object) -> void:
	var trap := GatewayTrap.new()
	trap.set_pos(123)
	trap.visible = true
	trap.tele_pos = 456

	var restored := GatewayTrap.new()
	restored.deserialize(trap.serialize())

	t.check(restored.pos == 123, "gateway trap restores base trap position")
	t.check(restored.visible, "gateway trap restores visibility")
	t.check(restored.active, "gateway trap restores active flag")
	t.check(restored.tele_pos == 456, "gateway trap restores persistent tele_pos")

func _make_level() -> Level:
	var level := Level.new()
	level.map.fill(ConstantsData.Terrain.EMPTY)
	for i: int in range(ConstantsData.LENGTH):
		level.set_terrain(i, ConstantsData.Terrain.EMPTY)
	level.entrance = 0
	level.exit_pos = ConstantsData.LENGTH - 1
	return level
