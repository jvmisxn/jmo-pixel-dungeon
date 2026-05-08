class_name Snake
extends Mob
## Fast and evasive, but fragile.

func _init() -> void:
	super._init()
	mob_id = "snake"
	mob_name = "Sewer Snake"
	description = "A venomous snake that slithers through the sewers."
	setup(4, 9, 8, 1, 4, 0)
	xp_value = 2
	max_level = 5
	awareness = 0.15
	aggro_range = 5
	base_speed = 1.5

func on_attack_hit(target_char: Char, _damage: int) -> void:
	super.on_attack_hit(target_char, _damage)
	# Small chance to poison
	if randf() < 0.2:
		var p: Poison = Poison.create(3.0)
		target_char.add_buff(p)
