extends RefCounted

class SpawnLevel:
	extends RegularLevel

	var fallback_positions: Array[int] = []
	var fallback_index: int = 0
	var ignore_entrance: bool = true

	func random_passable_cell() -> int:
		if fallback_positions.is_empty():
			return -1
		var pos: int = fallback_positions[fallback_index % fallback_positions.size()]
		fallback_index += 1
		return pos

	func _near_entrance(pos: int) -> bool:
		return false if ignore_entrance else super._near_entrance(pos)

func _fill_empty(level: RegularLevel) -> void:
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.build_flag_maps()

func _make_room(left: int, top: int, right: int, bottom: int) -> StandardRoom:
	var room := StandardRoom.new()
	room.left = left
	room.top = top
	room.right = right
	room.bottom = bottom
	return room

func _unique_count(values: Array[int]) -> int:
	var seen: Dictionary[int, bool] = {}
	for value: int in values:
		seen[value] = true
	return seen.size()

func _make_rat(pos: int) -> Rat:
	var rat := Rat.new()
	rat.pos = pos
	return rat

func _free_level_mobs(level: RegularLevel) -> void:
	for mob: Variant in level.mobs:
		if mob != null and is_instance_valid(mob):
			if TurnManager != null and TurnManager.has_actor(mob):
				TurnManager.remove_actor(mob)
			if mob is Node:
				(mob as Node).free()
	level.mobs.clear()

func run(t: Object) -> void:
	var fallback_only := SpawnLevel.new()
	_fill_empty(fallback_only)
	fallback_only.rooms = []
	fallback_only.fallback_positions = [
		ConstantsData.xy_to_pos(12, 12),
		ConstantsData.xy_to_pos(13, 12),
		ConstantsData.xy_to_pos(14, 12),
		ConstantsData.xy_to_pos(15, 12),
	]
	var fallback_positions: Array[int] = fallback_only.mob_spawn_positions(4)
	t.check(
		fallback_positions.size() == 4,
		"mob fallback returns the requested count instead of a single position"
	)
	t.check(
		_unique_count(fallback_positions) == 4,
		"mob fallback avoids duplicate spawn cells"
	)

	var room_level := SpawnLevel.new()
	_fill_empty(room_level)
	room_level.rooms = [_make_room(10, 10, 18, 18)]
	var room_positions: Array[int] = room_level.mob_spawn_positions(6)
	t.check(
		room_positions.size() == 6,
		"standard-room mob placement keeps trying until the requested count is placed"
	)
	t.check(
		_unique_count(room_positions) == 6,
		"standard-room mob placement avoids duplicate spawn cells"
	)

	var blocked_room_level := SpawnLevel.new()
	_fill_empty(blocked_room_level)
	blocked_room_level.rooms = [_make_room(10, 10, 18, 18)]
	for pos: int in blocked_room_level.rooms[0].interior_cells():
		blocked_room_level.map[pos] = ConstantsData.Terrain.WALL
	blocked_room_level.fallback_positions = [
		ConstantsData.xy_to_pos(20, 20),
		ConstantsData.xy_to_pos(21, 20),
		ConstantsData.xy_to_pos(22, 20),
	]
	var blocked_positions: Array[int] = blocked_room_level.mob_spawn_positions(3)
	t.check(
		blocked_positions.size() == 3,
		"failed room placement does not consume the remaining mob count"
	)

	var respawn_level := SpawnLevel.new()
	_fill_empty(respawn_level)
	respawn_level.depth = 2
	var visible_cell: int = ConstantsData.xy_to_pos(12, 12)
	var occupied_cell: int = ConstantsData.xy_to_pos(13, 12)
	var hidden_cell: int = ConstantsData.xy_to_pos(14, 12)
	respawn_level.visible.resize(ConstantsData.LENGTH)
	respawn_level.visible.fill(false)
	respawn_level.visible[visible_cell] = true
	respawn_level.fallback_positions = [visible_cell, occupied_cell, hidden_cell]
	respawn_level.add_mob(_make_rat(occupied_cell))
	respawn_level.respawn_target_mob_count = 2
	t.check(
		respawn_level.respawn_mob_if_needed(),
		"respawner creates a replacement mob when below the floor target"
	)
	t.check(
		respawn_level.mobs.size() == 2,
		"respawner fills toward the stored floor target"
	)
	t.check(
		int(respawn_level.mobs[1].get("pos")) == hidden_cell,
		"respawner skips visible and occupied cells"
	)
	_free_level_mobs(respawn_level)

	var extended_sight_level := SpawnLevel.new()
	_fill_empty(extended_sight_level)
	extended_sight_level.depth = 2
	extended_sight_level.visible.resize(ConstantsData.LENGTH)
	extended_sight_level.visible.fill(false)
	var huntress := Hero.new()
	huntress.hero_class = ConstantsData.HeroClass.HUNTRESS
	huntress.pos = ConstantsData.xy_to_pos(5, 5)
	huntress.level = extended_sight_level
	var old_heroes: Array[Node] = GameManager.heroes.duplicate() if GameManager != null else []
	if GameManager != null:
		GameManager.heroes.clear()
		GameManager.heroes.append(huntress)
	var base_hidden_cell: int = ConstantsData.xy_to_pos(14, 5)
	var extended_hidden_cell: int = ConstantsData.xy_to_pos(17, 5)
	extended_sight_level.fallback_positions = [base_hidden_cell, extended_hidden_cell]
	extended_sight_level.respawn_target_mob_count = 1
	t.check(
		extended_sight_level.respawn_mob_if_needed(),
		"respawner still finds a spawn outside the hero's effective sight radius"
	)
	t.check(
		int(extended_sight_level.mobs[0].get("pos")) == extended_hidden_cell,
		"respawner skips cells inside extended hero sight, not just base view distance"
	)
	if GameManager != null:
		GameManager.heroes = old_heroes
	huntress.free()
	_free_level_mobs(extended_sight_level)

	var capped_level := SpawnLevel.new()
	_fill_empty(capped_level)
	capped_level.depth = 2
	capped_level.add_mob(_make_rat(ConstantsData.xy_to_pos(18, 18)))
	capped_level.respawn_target_mob_count = 1
	t.check(
		not capped_level.respawn_mob_if_needed(),
		"respawner does not exceed the stored floor mob target"
	)
	t.check(
		capped_level.mobs.size() == 1,
		"respawner leaves capped floors unchanged"
	)
	_free_level_mobs(capped_level)

	var serialized_level := SpawnLevel.new()
	_fill_empty(serialized_level)
	serialized_level.respawn_target_mob_count = 7
	var serialized: Dictionary = serialized_level.serialize()
	var restored_level := SpawnLevel.new()
	restored_level.deserialize(serialized)
	t.check(
		restored_level.respawn_target_mob_count == 7,
		"respawner target mob count survives level serialization"
	)

	var scheduled_level := SpawnLevel.new()
	_fill_empty(scheduled_level)
	scheduled_level.depth = 2
	scheduled_level.fallback_positions = [ConstantsData.xy_to_pos(20, 20)]
	scheduled_level.respawn_target_mob_count = 1
	if TurnManager != null:
		TurnManager.clear_actors()
		var respawner := Respawner.new()
		respawner.level = scheduled_level
		respawner.active = true
		TurnManager.add_actor(respawner)
		var actor: Node = TurnManager.process_turn()
		t.check(
			actor == respawner,
			"respawner participates in the turn scheduler as an Actor"
		)
		t.check(
			scheduled_level.mobs.size() == 1,
			"respawner actor spawns one replacement mob on its scheduled turn"
		)
		t.check(
			is_equal_approx(TurnManager.get_cooldown(respawner), Respawner.TIME_TO_RESPAWN),
			"respawner actor spends the SPD respawn cooldown"
		)
		TurnManager.clear_actors()
		respawner.free()
	_free_level_mobs(scheduled_level)
