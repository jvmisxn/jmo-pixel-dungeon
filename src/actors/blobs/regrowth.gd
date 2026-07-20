class_name Regrowth
extends Blob
## Living growth cloud. Grows grass/high grass and roots characters standing in it.

const ROOT_DURATION: float = 1.0
const HIGH_GRASS_THRESHOLD: float = 9.0

func _init() -> void:
	super._init()
	blob_id = "regrowth"
	blob_name = "Regrowth"
	spread_rate = 0.5
	decay_rate = 0.1

func affect_char(ch: Char) -> void:
	if density[ch.pos] <= 1.0:
		return
	var rooted: Rooted = Rooted.new()
	rooted.set_duration(ROOT_DURATION)
	ch.add_buff(rooted)

func _apply_effects() -> void:
	super._apply_effects()
	if level == null or not level.has_method("get_terrain") or not level.has_method("set_terrain"):
		return
	for cell: int in active_cells:
		var amount: float = density[cell]
		if amount <= min_density:
			continue
		var terrain: int = level.get_terrain(cell)
		var next_terrain: int = terrain
		var occupied: bool = level.has_method("find_char_at") and level.find_char_at(cell) != null
		match terrain:
			ConstantsData.Terrain.EMPTY, ConstantsData.Terrain.EMBERS:
				next_terrain = ConstantsData.Terrain.GRASS
				if amount > HIGH_GRASS_THRESHOLD and not occupied:
					next_terrain = ConstantsData.Terrain.HIGH_GRASS
			ConstantsData.Terrain.GRASS, ConstantsData.Terrain.FURROWED_GRASS:
				if amount > HIGH_GRASS_THRESHOLD and not occupied:
					next_terrain = ConstantsData.Terrain.HIGH_GRASS
		if next_terrain != terrain:
			level.set_terrain(cell, next_terrain)
