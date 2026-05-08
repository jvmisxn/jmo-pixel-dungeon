class_name Crab
extends Mob
## Hard shell gives high armor but low HP.

func _init() -> void:
	super._init()
	mob_id = "crab"
	mob_name = "Sewer Crab"
	description = "A large crustacean with powerful pincers and a thick shell."
	setup(15, 12, 6, 1, 7, 6)
	xp_value = 3
	max_level = 7
	awareness = 0.3
	aggro_range = 6
	base_speed = 0.8  # Slightly slow
	loot_table = [{"item_id": "mystery_meat", "chance": 0.2}]
