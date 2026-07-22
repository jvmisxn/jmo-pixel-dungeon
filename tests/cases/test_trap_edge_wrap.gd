extends RefCounted

## Trap footprint effects must use true grid neighbours. Raw `pos + dir` checks
## can treat the previous row's last column as west/diagonal-adjacent to a
## left-edge trap cell, leaking trap effects across the map edge.

func run(t: Object) -> void:
	_test_flashing_trap_no_edge_wrap(t)
	_test_blazing_trap_no_edge_wrap(t)
	_test_explosive_trap_no_edge_wrap(t)

func _test_flashing_trap_no_edge_wrap(t: Object) -> void:
	var level := Level.new()
	var trap := FlashingTrap.new()
	trap.pos = 2 * Level.W
	var real_neighbour := Rat.new()
	real_neighbour.pos = trap.pos + 1
	var wrapped := Rat.new()
	wrapped.pos = trap.pos - 1
	level.add_mob(real_neighbour)
	level.add_mob(wrapped)

	trap.activate(null, level)

	t.check(real_neighbour.has_buff("Blindness"), "FlashingTrap blinds a true same-row neighbour")
	t.check(not wrapped.has_buff("Blindness"), "FlashingTrap does not blind a wrapped previous-row cell")
	_free_mobs([real_neighbour, wrapped])

func _test_blazing_trap_no_edge_wrap(t: Object) -> void:
	var level := Level.new()
	var trap := BlazingTrap.new()
	trap.pos = 2 * Level.W
	var real_neighbour: int = trap.pos + 1
	var wrapped: int = trap.pos - 1
	level.set_terrain(real_neighbour, ConstantsData.Terrain.GRASS)
	level.set_terrain(wrapped, ConstantsData.Terrain.GRASS)

	trap.activate(null, level)

	t.check(level.terrain_at(real_neighbour) == ConstantsData.Terrain.EMBERS,
		"BlazingTrap burns a true same-row neighbouring grass cell")
	t.check(level.terrain_at(wrapped) == ConstantsData.Terrain.GRASS,
		"BlazingTrap does not burn wrapped previous-row grass")

func _test_explosive_trap_no_edge_wrap(t: Object) -> void:
	var level := Level.new()
	level.depth = 3
	var trap := ExplosiveTrap.new()
	trap.pos = 2 * Level.W
	var real_neighbour := Rat.new()
	real_neighbour.pos = trap.pos + 1
	var wrapped := Rat.new()
	wrapped.pos = trap.pos - 1
	level.add_mob(real_neighbour)
	level.add_mob(wrapped)
	var real_hp: int = int(real_neighbour.hp)
	var wrapped_hp: int = int(wrapped.hp)

	trap.activate(null, level)

	t.check(int(real_neighbour.hp) < real_hp, "ExplosiveTrap damages a true same-row neighbour")
	t.check(int(wrapped.hp) == wrapped_hp, "ExplosiveTrap does not damage a wrapped previous-row cell")
	_free_mobs([real_neighbour, wrapped])

func _free_mobs(mobs: Array) -> void:
	for mob: Variant in mobs:
		if mob != null and is_instance_valid(mob):
			if TurnManager != null and TurnManager.has_actor(mob):
				TurnManager.remove_actor(mob)
			if mob is Node:
				(mob as Node).free()
