class_name GreatCrab
extends Mob
## Great Crab: mini-boss with very high armor and frequent blocking.
## Blocks attacks frequently and has a lot of defense.

const BLOCK_CHANCE: float = 0.5

func _init() -> void:
	super._init()
	mob_id = "great_crab"
	mob_name = "Great Crab"
	description = "An enormous crustacean with an impenetrable shell. It blocks many attacks."
	setup(25, 12, 12, 4, 10, 10, 0.7)  # Very high armor and defense, slow
	xp_value = 6
	max_level = 9
	awareness = 0.4
	aggro_range = 6
	base_speed = 0.7
	loot_table = [
		{"item_id": "mystery_meat", "chance": 1.0},
		{"item_id": "gold", "chance": 0.5},
	]

## Override take_damage to implement blocking.
func take_damage(dmg: int, source: Variant = null) -> int:
	# Roll to block the attack entirely
	if dmg > 0 and randf() < BLOCK_CHANCE:
		if MessageLog:
			MessageLog.add_info("The great crab blocks the attack!")
		# Still wake up if sleeping
		if state == AIState.SLEEPING and source is Char:
			_wake_up(source as Char)
		return 0
	return super.take_damage(dmg, source)

## Great crab never flees — it stands and fights.
func should_flee() -> bool:
	return false

func scale_to_depth(p_depth: int) -> void:
	var scale: int = maxi(0, p_depth - 3)
	hp = 25 + scale * 4
	hp_max = hp
	ht = hp
	damage_roll_min = 4 + scale
	damage_roll_max = 10 + scale * 2
	armor_value = 10 + scale * 2
	attack_skill = 12 + scale * 2
	defense_skill = 12 + scale * 2
