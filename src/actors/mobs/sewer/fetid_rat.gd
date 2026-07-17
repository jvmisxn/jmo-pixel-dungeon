class_name FetidRat
extends Rat

func _init() -> void:
	super._init()
	mob_id = "fetid_rat"
	mob_name = "Fetid Rat"
	description = "A diseased sewer rat that leaks corrosive filth."
	setup(12, 10, 3, 2, 5, 1)
	xp_value = 3
	max_level = 7
	awareness = 0.3
	aggro_range = 6
	loot_table = [{"item_id": "mystery_meat", "chance": 0.2}]

func _on_death(_source: Variant = null) -> void:
	var death_pos: int = pos
	var death_level: Variant = level
	super._on_death(_source)
	if death_level != null and death_level.has_method("add_blob"):
		var blob: ToxicGas = ToxicGas.new()
		death_level.add_blob(blob, death_pos, 6.0)
