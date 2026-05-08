class_name Rat
extends Mob

func _init() -> void:
	super._init()
	mob_id = "rat"
	mob_name = "Marsupial Rat"
	description = "A large, aggressive rat that dwells in the sewers."
	setup(8, 8, 2, 1, 4, 0)
	xp_value = 1
	max_level = 5
	awareness = 0.2
	aggro_range = 6
	loot_table = [{"item_id": "food_ration", "chance": 0.1}]
