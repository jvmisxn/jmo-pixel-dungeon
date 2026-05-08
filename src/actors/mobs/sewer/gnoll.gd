class_name Gnoll
extends Mob

func _init() -> void:
	super._init()
	mob_id = "gnoll"
	mob_name = "Gnoll Scout"
	description = "A hyena-like humanoid armed with crude weapons."
	setup(12, 10, 4, 1, 6, 2)
	xp_value = 2
	max_level = 6
	awareness = 0.3
	aggro_range = 8
	loot_table = [{"item_id": "gold", "chance": 0.5}, {"item_id": "dart", "chance": 0.2}]
