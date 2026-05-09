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
		var toxic_script: GDScript = load("res://src/actors/blobs/toxic_gas.gd")
		if toxic_script != null:
			var blob: Variant = toxic_script.new()
			if blob != null:
				blob.pos = death_pos
				if blob.has_method("seed"):
					blob.seed(death_level, death_pos, 6)
				death_level.add_blob(blob)
