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

## In-bounds, passable cells within a Chebyshev `radius` of `center`, mirroring
## Shattered Pixel Dungeon's `PathFinder.NEIGHBOURS9` (radius 1) / distance-map
## (radius 2) seed footprints used by fire/frost traps and plants.
##
## Cells are enumerated by (x, y) rather than raw `center + offset` so the
## footprint can never wrap across a map edge -- the exact row-wrap bug the
## plant/blob edge tests guard against. Solid cells are skipped when the level
## exposes `is_passable`, matching SPD's `!Dungeon.level.solid[cell]` guard.
static func blast_cells(target_level: Variant, center: int, radius: int) -> Array[int]:
	var result: Array[int] = []
	if not ConstantsData.is_valid_pos(center):
		return result
	var cx: int = ConstantsData.pos_to_x(center)
	var cy: int = ConstantsData.pos_to_y(center)
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var x: int = cx + dx
			var y: int = cy + dy
			if x < 0 or x >= ConstantsData.WIDTH or y < 0 or y >= ConstantsData.HEIGHT:
				continue
			var cell: int = ConstantsData.xy_to_pos(x, y)
			if target_level != null and target_level.has_method("is_passable") \
					and not target_level.is_passable(cell):
				continue
			result.append(cell)
	return result

## Seed blob at a position with given density.
func seed(cell: int, amount: float) -> void:
	if not ConstantsData.is_valid_pos(cell):
		return
	density[cell] = maxf(density[cell], amount)
	if cell not in active_cells:
		active_cells.append(cell)

## Run one simulation step (apply effects -> volume-conserving diffusion) WITHOUT
## touching the turn scheduler. Blobs are not registered as TurnManager actors;
## instead `Level.advance_blobs()` runs one step per TICK of shared game-time
## (TurnManager.now()), so blobs advance on the timeline rather than per hero
## round and stay rate-correct under Haste/Slow and multi-hero co-op.
##
## Effects are applied to the CURRENT (pre-diffusion) field so a character
## standing in freshly-seeded dense gas is affected at full strength; the
## diffusion pass then averages density outward and applies decay.
func tick() -> void:
	_apply_effects()
	_evolve()
	if active_cells.is_empty():
		deactivate()

## Process one turn as a scheduled actor (kept for compatibility with the
## Actor contract). Equivalent to `tick()` plus spending a turn's energy.
func act() -> void:
	tick()
	spend_turn()

## Volume-conserving diffusion, mirroring Shattered Pixel Dungeon's
## `Blob.evolve()`. Each open cell becomes the AVERAGE of itself and its open
## cardinal neighbours, then loses `decay_rate` (SPD's constant `-1` drain).
##
## Why this cannot explode: averaging can never push a cell above the maximum of
## its neighbourhood, so the field's peak is non-increasing and total volume is
## approximately conserved each step (the old copy-outward model used `max()`,
## which minted fresh density at every frontier cell and let the total grow
## without bound). The decay term then makes the total strictly trend downward
## until cells fall below `min_density` and prune out.
##
## Only the frontier -- active cells plus the open cells they can flow into -- is
## scanned, since every other cell has an all-zero neighbourhood and stays zero.
func _evolve() -> void:
	if level == null:
		return
	# Non-spreading blobs (webs, wells) hold their shape and only decay in place.
	if spread_rate <= 0.0:
		_decay_in_place()
		return
	var cur: PackedFloat32Array = density
	var candidates: Array[int] = []
	var seen: Dictionary = {}
	for cell: int in active_cells:
		if not seen.has(cell):
			seen[cell] = true
			candidates.append(cell)
		for n: int in _cardinal_neighbors(cell):
			if _blocks_spread(n):
				continue
			if not seen.has(n):
				seen[n] = true
				candidates.append(n)
	# Compute every new value from the read-only `cur` snapshot first, then write
	# them back, so no cell is averaged against a value already updated this pass.
	var new_values: Array[float] = []
	var new_active: Array[int] = []
	for cell: int in candidates:
		if _blocks_spread(cell):
			new_values.append(0.0)
			continue
		var sum: float = cur[cell]
		var count: int = 1
		for n: int in _cardinal_neighbors(cell):
			if _blocks_spread(n):
				continue
			sum += cur[n]
			count += 1
		var value: float = (sum / float(count)) - decay_rate
		if value <= min_density:
			value = 0.0
		new_values.append(value)
		if value > min_density:
			new_active.append(cell)
	for i: int in range(candidates.size()):
		density[candidates[i]] = new_values[i]
	active_cells = new_active

## Decay path for blobs that do not diffuse (spread_rate == 0). Subtracts
## `decay_rate` from each active cell in place and prunes cells that fall to/below
## the active threshold, zeroing them so stale density never leaks into a later
## pass. With decay_rate == 0 the blob persists unchanged (webs, counters).
func _decay_in_place() -> void:
	var kept: Array[int] = []
	for cell: int in active_cells:
		var value: float = density[cell] - decay_rate
		if value <= min_density:
			density[cell] = 0.0
		else:
			density[cell] = value
			kept.append(cell)
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
	# Stamp the concrete subclass path so Blob.create_from_data() can rebuild the
	# correct type on load, mirroring the plant/trap reconstruction idiom. This is
	# what lets Level persist blobs as plain data instead of duplicating a live Node.
	data["_script_path"] = get_script().resource_path
	data["blob_id"] = blob_id
	data["active_cells"] = active_cells.duplicate()
	var densities: Array[float] = []
	for cell: int in active_cells:
		densities.append(density[cell])
	data["densities"] = densities
	return data

## Factory: rebuild a live blob Node from data produced by serialize(). Reads the
## concrete subclass from the `_script_path` stamped at save time (falling back to
## the base Blob when absent/invalid), then replays its cell densities via
## deserialize(). Level save/load uses this instead of storing live Node refs, so
## every blob round-trips through its own serialize()/deserialize() contract and
## each subclass's `_init()` restores its spread/decay tuning.
static func create_from_data(data: Dictionary) -> Blob:
	var blob: Blob = null
	var script_path: String = str(data.get("_script_path", ""))
	if not script_path.is_empty() and ResourceLoader.exists(script_path):
		var script: Script = load(script_path) as Script
		if script != null:
			blob = script.new() as Blob
	if blob == null:
		blob = Blob.new()
	blob.deserialize(data)
	return blob

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
