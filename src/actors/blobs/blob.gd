class_name Blob
extends Actor
## Base class for area-of-effect gas/liquid that spreads across tiles.
## Blobs exist on the level and process each turn, spreading and affecting characters.

var blob_id: String = "blob"
var blob_name: String = "Blob"
## Density at each cell (0 = no blob here). Indexed by flat position.
var density: PackedFloat32Array = PackedFloat32Array()
## Cells that currently have density > 0.
var active_cells: Array[int] = []
## How fast this blob spreads (0-1). Higher = more spread per turn.
var spread_rate: float = 0.5
## How fast density decays per turn.
var decay_rate: float = 0.1
## Minimum density to count as active.
var min_density: float = 0.1

func _init() -> void:
	density.resize(ConstantsData.LENGTH)
	density.fill(0.0)

## Seed blob at a position with given density.
func seed(cell: int, amount: float) -> void:
	if not ConstantsData.is_valid_pos(cell):
		return
	density[cell] = maxf(density[cell], amount)
	if cell not in active_cells:
		active_cells.append(cell)

## Run one simulation step (spread -> apply effects -> decay -> prune) WITHOUT
## touching the turn scheduler. Levels drive this directly each hero round via
## `Level.tick_blobs()`; blobs are not registered as TurnManager actors.
func tick() -> void:
	_spread()
	_apply_effects()
	_decay()
	_prune_inactive()
	if active_cells.is_empty():
		deactivate()

## Process one turn as a scheduled actor (kept for compatibility with the
## Actor contract). Equivalent to `tick()` plus spending a turn's energy.
func act() -> void:
	tick()
	spend_turn()

func _spread() -> void:
	if level == null:
		return
	# Build the next density field separately so we never read cells we have
	# already written this pass, and collect newly-touched cells to append AFTER
	# iteration (mutating active_cells mid-loop caused single-turn cascades).
	var new_density: PackedFloat32Array = density.duplicate()
	var touched: Array[int] = []
	for cell: int in active_cells:
		var here: float = density[cell]
		if here <= min_density:
			continue
		var spread_amount: float = here * spread_rate * 0.25
		if spread_amount <= 0.0:
			continue
		for neighbor: int in _cardinal_neighbors(cell):
			if _blocks_spread(neighbor):
				continue
			new_density[neighbor] = maxf(new_density[neighbor], spread_amount)
			if new_density[neighbor] > min_density \
					and neighbor not in active_cells and neighbor not in touched:
				touched.append(neighbor)
	density = new_density
	for cell: int in touched:
		active_cells.append(cell)

func _decay() -> void:
	if decay_rate <= 0.0:
		return
	for cell: int in active_cells:
		density[cell] -= decay_rate
		if density[cell] < 0.0:
			density[cell] = 0.0

## Drop cells that have fallen to/below the active threshold, zeroing their
## density so stale values never leak into later spread passes.
func _prune_inactive() -> void:
	var kept: Array[int] = []
	for cell: int in active_cells:
		if density[cell] > min_density:
			kept.append(cell)
		else:
			density[cell] = 0.0
	active_cells = kept

## Cardinal (N/E/S/W) in-bounds neighbors of a cell, guarding against the
## row-wrap that raw +/-1 index math produces at column edges.
func _cardinal_neighbors(cell: int) -> Array[int]:
	var result: Array[int] = []
	var x: int = ConstantsData.pos_to_x(cell)
	var y: int = ConstantsData.pos_to_y(cell)
	if y > 0:
		result.append(cell - ConstantsData.WIDTH)
	if y < ConstantsData.HEIGHT - 1:
		result.append(cell + ConstantsData.WIDTH)
	if x > 0:
		result.append(cell - 1)
	if x < ConstantsData.WIDTH - 1:
		result.append(cell + 1)
	return result

## Whether the blob is blocked from spreading into a cell (walls etc.).
func _blocks_spread(cell: int) -> bool:
	if level != null and level.has_method("is_passable"):
		return not level.is_passable(cell)
	return false

## Override in subclasses to apply effects to characters standing in the blob.
func _apply_effects() -> void:
	if level == null:
		return
	for cell: int in active_cells:
		if density[cell] <= min_density:
			continue
		if level.has_method("find_char_at"):
			var victim: Variant = level.find_char_at(cell)
			if victim and victim is Char:
				affect_char(victim as Char)

## Override to define what this blob does to characters.
func affect_char(_ch: Char) -> void:
	pass

## Get density at a position.
func get_density(cell: int) -> float:
	if not ConstantsData.is_valid_pos(cell):
		return 0.0
	return density[cell]

## Check if blob exists at a position.
func is_active_at(cell: int) -> bool:
	return get_density(cell) > min_density

func get_speed() -> float:
	return 1.0

func serialize() -> Dictionary:
	var data: Dictionary = serialize_actor()
	data["blob_id"] = blob_id
	data["active_cells"] = active_cells.duplicate()
	var densities: Array[float] = []
	for cell: int in active_cells:
		densities.append(density[cell])
	data["densities"] = densities
	return data

func deserialize(data: Dictionary) -> void:
	deserialize_actor(data)
	blob_id = data.get("blob_id", blob_id)
	density.resize(ConstantsData.LENGTH)
	density.fill(0.0)
	active_cells.clear()
	var cells: Array = data.get("active_cells", [])
	var densities: Array = data.get("densities", [])
	for i: int in range(cells.size()):
		var cell: int = int(cells[i])
		if not ConstantsData.is_valid_pos(cell):
			continue
		density[cell] = float(densities[i]) if i < densities.size() else min_density + 0.01
		if cell not in active_cells:
			active_cells.append(cell)
