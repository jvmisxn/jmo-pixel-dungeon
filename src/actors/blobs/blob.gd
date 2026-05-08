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

## Process one turn: spread and apply effects.
func act() -> void:
	_spread()
	_apply_effects()
	_decay()
	# Remove dead cells
	var new_active: Array[int] = []
	for cell: int in active_cells:
		if density[cell] > min_density:
			new_active.append(cell)
	active_cells = new_active
	# If no cells left, deactivate
	if active_cells.is_empty():
		deactivate()
	spend_turn()

func _spread() -> void:
	if level == null:
		return
	var new_density: PackedFloat32Array = density.duplicate()
	for cell: int in active_cells:
		if density[cell] <= min_density:
			continue
		var spread_amount: float = density[cell] * spread_rate * 0.25
		for dir: int in ConstantsData.DIRS_4:
			var neighbor: int = cell + dir
			if not ConstantsData.is_valid_pos(neighbor):
				continue
			if level.has_method("is_passable") and level.is_passable(neighbor):
				new_density[neighbor] = maxf(new_density[neighbor], spread_amount)
				if neighbor not in active_cells:
					active_cells.append(neighbor)
	density = new_density

func _decay() -> void:
	for cell: int in active_cells:
		density[cell] -= decay_rate
		if density[cell] < 0:
			density[cell] = 0.0

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
