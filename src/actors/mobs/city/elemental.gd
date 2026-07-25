class_name Elemental
extends Mob
## Fire elemental. Burns on hit, immune to fire. Splits into smaller ones at low HP.

func _init() -> void:
	super._init()
	mob_id = "elemental"
	mob_name = "Fire Elemental"
	description = "Elementals are chaotic creatures that are often created when powerful occult magic isn't properly controlled. Elementals have minimal intelligence, and are usually associated with a particular type of magic.\n\nFire elementals are a common type of elemental which deals damage with fiery magic. They will set their target ablaze with melee attacks, and can occasionally shoot bolts of fire as well."
	setup(55, 20, 12, 8, 20, 5)
	xp_value = 10
	max_level = 22
	awareness = 0.5
	aggro_range = 8
	base_speed = 1.2

func on_attack_hit(target_char: Char, _damage: int) -> void:
	super.on_attack_hit(target_char, _damage)
	# Set target on fire
	var burn: Burning = Burning.new()
	target_char.add_buff(burn)

## Immune to fire/burning
func take_damage(dmg: int, source: Variant = null) -> int:
	if source is Burning:
		return 0
	return super.take_damage(dmg, source)
