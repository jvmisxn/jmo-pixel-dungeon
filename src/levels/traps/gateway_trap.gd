class_name GatewayTrap
extends Trap
## Teleports the first nearby character or ordinary heap to a random cell, then
## funnels the rest of the trap's 3x3 footprint around that destination.
##
## Source notes: Shattered Pixel Dungeon's GatewayTrap is a teal crosshair trap
## that is not disarmed by activation. It first establishes `telePos` by
## teleporting one neighbouring character or heap, then moves other nearby
## characters/heaps to that gateway destination. This port mirrors that durable
## tele_pos behavior for characters and single-item heap dictionaries.

var tele_pos: int = -1

func _init() -> void:
	trap_name = "gateway trap"
	color = Color(0.1, 0.75, 0.75)
	one_shot = false

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if level == null:
		return
	if MessageLog:
		MessageLog.add("A gateway opens!")

	if tele_pos < 0:
		tele_pos = _establish_gateway_destination(level)
	if tele_pos < 0:
		return

	var destinations: Array[int] = _gateway_destinations(level)
	for cell: int in _footprint_cells():
		var ch: Variant = level.find_char_at(cell) if level.has_method("find_char_at") else null
		if ch != null:
			var new_pos: int = _take_destination(destinations)
			if new_pos >= 0:
				_teleport_char(ch, new_pos)
				_reset_hunting_mob(ch)

		for heap: Dictionary in _ordinary_heaps_at(level, cell):
			_move_heap(level, heap, tele_pos)

func _establish_gateway_destination(level: Level) -> int:
	for cell: int in _footprint_cells():
		var ch: Variant = level.find_char_at(cell) if level.has_method("find_char_at") else null
		if ch != null:
			var new_pos: int = _random_destination(level)
			if new_pos >= 0:
				_teleport_char(ch, new_pos)
				_reset_hunting_mob(ch)
				return new_pos

		for heap: Dictionary in _ordinary_heaps_at(level, cell):
			var heap_pos: int = _random_destination(level)
			if heap_pos >= 0:
				_move_heap(level, heap, heap_pos)
				return heap_pos
	return -1

func _gateway_destinations(level: Level) -> Array[int]:
	var cells: Array[int] = []
	for neighbor: int in Pathfinder.get_neighbors(tele_pos, ConstantsData.WIDTH, ConstantsData.LENGTH):
		if level.is_passable(neighbor) and level.find_char_at(neighbor) == null:
			cells.append(neighbor)
	cells.shuffle()
	if level.is_passable(tele_pos) and level.find_char_at(tele_pos) == null:
		cells.insert(0, tele_pos)
	return cells

func _take_destination(destinations: Array[int]) -> int:
	if destinations.is_empty():
		return -1
	return destinations.pop_front()

func _random_destination(level: Level) -> int:
	for _i: int in range(1000):
		var candidate: int = level.random_passable_cell()
		if candidate >= 0 and level.find_char_at(candidate) == null:
			return candidate
	return -1

func _teleport_char(ch: Variant, new_pos: int) -> void:
	if ch == null:
		return
	if ch.has_method("set_pos"):
		ch.set_pos(new_pos)
	elif ch.get("pos") != null:
		ch.pos = new_pos

func _reset_hunting_mob(ch: Variant) -> void:
	if ch is Mob and ch.state == Mob.AIState.HUNTING:
		ch.state = Mob.AIState.WANDERING

func _ordinary_heaps_at(level: Level, cell: int) -> Array[Dictionary]:
	var heaps: Array[Dictionary] = []
	for heap: Dictionary in level.heaps:
		if int(heap.get("pos", -1)) == cell and str(heap.get("type", "heap")) == "heap":
			heaps.append(heap)
	return heaps

func _move_heap(level: Level, heap: Dictionary, new_pos: int) -> void:
	var idx: int = level.heaps.find(heap)
	if idx >= 0:
		level.heaps.remove_at(idx)
	var item: Variant = heap.get("item")
	if item != null:
		level.drop_item(new_pos, item, str(heap.get("type", "heap")))

func _footprint_cells() -> Array[int]:
	if not ConstantsData.is_valid_pos(pos):
		return []
	var cells: Array[int] = [pos]
	cells.append_array(Pathfinder.get_neighbors(pos, ConstantsData.WIDTH, ConstantsData.LENGTH))
	return cells

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["tele_pos"] = tele_pos
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	tele_pos = int(data.get("tele_pos", tele_pos))
