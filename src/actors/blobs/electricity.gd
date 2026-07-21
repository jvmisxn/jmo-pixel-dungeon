class_name Electricity
extends Blob
## Electrical charge seeded by ShockingTrap and StormTrap.
##
## Shattered Pixel Dungeon's Electricity blob spreads instantly across connected
## water, paralyzes characters in charged cells, deals small damage on odd
## charge values, then loses one charge per tick. This keeps that special
## non-diffusion behavior instead of using the base gas averaging model.

func _init() -> void:
	super._init()
	blob_id = "electricity"
	blob_name = "Electricity"
	spread_rate = 0.0
	decay_rate = 1.0
	min_density = 0.0

func tick() -> void:
	_spread_through_water()
	_apply_effects()
	_decay_in_place()
	if active_cells.is_empty():
		deactivate()

func affect_char(ch: Char) -> void:
	if ch == null or ch.is_immune(blob_id):
		return
	var charge: int = int(get_density(ch.pos))
	if charge <= 0:
		return
	if not ch.has_buff("Paralysis"):
		var para: Paralysis = Paralysis.new()
		para.set_duration(float(charge))
		ch.add_buff(para)
	if charge % 2 == 1:
		var depth: int = level.depth if level != null else 1
		ch.take_damage(roundi(randf() * (2.0 + float(depth) / 5.0)), blob_id)

func _spread_through_water() -> void:
	if level == null:
		return
	var queue: Array[int] = active_cells.duplicate()
	var index: int = 0
	while index < queue.size():
		var cell: int = queue[index]
		index += 1
		var power: float = density[cell]
		if power <= 0.0:
			continue
		for n: int in _cardinal_neighbors(cell):
			if level.terrain_at(n) != ConstantsData.Terrain.WATER:
				continue
			if density[n] >= power:
				continue
			density[n] = power
			if n not in active_cells:
				active_cells.append(n)
				queue.append(n)
