class_name Gnoll
extends Mob

func _init() -> void:
	super._init()
	mob_id = "gnoll"
	mob_name = "Gnoll Scout"
	description = "Gnolls are hyena-like humanoids. They dwell in sewers and dungeons, venturing up to raid the surface from time to time. Gnoll scouts are regular members of their pack, they are not as strong as brutes and not as intelligent as shamans."
	setup(12, 10, 4, 1, 6, 2)
	xp_value = 2
	max_level = 6
	awareness = 0.3
	aggro_range = 8
	loot_table = [{"item_id": "gold", "chance": 0.5}, {"item_id": "dart", "chance": 0.2}]
