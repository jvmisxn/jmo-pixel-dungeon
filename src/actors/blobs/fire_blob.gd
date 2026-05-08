class_name FireBlob
extends Blob
## Spreading fire. Sets characters on fire, burns flammable terrain.

func _init() -> void:
	super._init()
	blob_id = "fire"
	blob_name = "Fire"
	spread_rate = 0.6
	decay_rate = 0.15

func affect_char(ch: Char) -> void:
	if not ch.has_buff("Burning"):
		var burn: Burning = Burning.new()
		ch.add_buff(burn)

func _apply_effects() -> void:
	super._apply_effects()
	# Burn flammable terrain
	if level == null:
		return
	for cell: int in active_cells:
		if density[cell] <= min_density:
			continue
		if level.has_method("get_terrain"):
			var terrain: int = level.get_terrain(cell)
			match terrain:
				ConstantsData.Terrain.HIGH_GRASS, ConstantsData.Terrain.FURROWED_GRASS:
					if level.has_method("set_terrain"):
						level.set_terrain(cell, ConstantsData.Terrain.EMBERS)
				ConstantsData.Terrain.BARRICADE:
					if level.has_method("set_terrain"):
						level.set_terrain(cell, ConstantsData.Terrain.EMBERS)
				ConstantsData.Terrain.DOOR:
					if level.has_method("set_terrain"):
						level.set_terrain(cell, ConstantsData.Terrain.OPEN_DOOR)
