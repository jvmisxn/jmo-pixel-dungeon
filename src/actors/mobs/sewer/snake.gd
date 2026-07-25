class_name Snake
extends Mob
## Fast and evasive, but fragile.

func _init() -> void:
	super._init()
	mob_id = "snake"
	mob_name = "Sewer Snake"
	description = "These oversized serpents are capable of quickly slithering around blows, making them quite hard to hit. Magical attacks or surprise attacks are capable of catching them off-guard however.\n\nYou can perform a surprise attack by attacking while out of the snake's vision. One way is to let a snake chase you through a doorway and then strike just after it moves into the door."
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
