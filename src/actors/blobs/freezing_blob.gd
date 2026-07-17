class_name FreezingBlob
extends Blob
## Freezing vapor. Extinguishes fire, freezes characters, and hardens water.

func _init() -> void:
	super._init()
	blob_id = "freezing"
	blob_name = "Freezing Gas"
	spread_rate = 0.35
	decay_rate = 0.12

func affect_char(ch: Char) -> void:
	if ch.has_method("remove_buff_by_id"):
		ch.remove_buff_by_id("Burning")
	if not ch.has_buff("Frozen"):
		ch.add_buff(Frozen.new())

func _apply_effects() -> void:
	super._apply_effects()
	if level == null:
		return
	if not level.has_method("get_terrain") or not level.has_method("set_terrain"):
		return
	for cell: int in active_cells:
		if density[cell] <= min_density:
			continue
		if level.get_terrain(cell) == ConstantsData.Terrain.WATER:
			level.set_terrain(cell, ConstantsData.Terrain.EMPTY)
