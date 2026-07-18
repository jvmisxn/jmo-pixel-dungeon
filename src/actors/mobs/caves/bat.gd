class_name Bat
extends Mob
## Fast flying mob that heals on hit (vampiric). High evasion.

func _init() -> void:
	super._init()
	mob_id = "bat"
	mob_name = "Vampire Bat"
	description = "A large bat that drains life force with each bite."
	setup(30, 18, 14, 5, 16, 4)
	xp_value = 7
	max_level = 17
	awareness = 0.5
	aggro_range = 8
	base_speed = 1.5  # Very fast
	# Dark gold ore for the Troll Blacksmith quest. This port sources the ore
	# from Caves bats (see blacksmith.gd / quest_handler.gd) rather than SPD's
	# Pickaxe-and-mining terrain. Bats span depths 11-17, so 15 pieces are
	# reachable across the Caves/City with a moderate per-kill drop chance.
	loot_table = [{"item_id": "dark_gold_ore", "chance": 0.5}]

func on_attack_hit(_target_char: Char, damage: int) -> void:
	super.on_attack_hit(_target_char, damage)
	# Vampiric heal
	@warning_ignore("integer_division")
	var heal_amount: int = maxi(1, damage / 2)
	heal(heal_amount)
