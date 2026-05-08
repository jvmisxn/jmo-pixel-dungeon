class_name MonkMob
extends Mob
## Fast martial artist. Multiple attacks per turn, can disarm.

var combo: int = 0

func _init() -> void:
	super._init()
	mob_id = "monk"
	mob_name = "Dwarf Monk"
	description = "A dwarven martial artist with lightning-fast strikes."
	setup(50, 22, 14, 6, 16, 6)
	xp_value = 10
	max_level = 22
	awareness = 0.5
	aggro_range = 8
	base_speed = 1.5  # Very fast

func on_attack_hit(target_char: Char, damage: int) -> void:
	super.on_attack_hit(target_char, damage)
	combo += 1
	# Every 3rd hit disarms the hero
	if combo >= 3 and target_char is Hero:
		combo = 0
		if randf() < 0.5:
			if MessageLog:
				MessageLog.add_negative("The monk knocks your weapon away!")
			# Disarm effect (Phase 3 will handle item dropping)

func on_attack_miss(_target_char: Char) -> void:
	combo = 0
