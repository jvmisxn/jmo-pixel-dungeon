class_name GoldenStatue
extends AnimatedStatue
## A rare golden variant of the animated statue.
## Even tougher than normal statues, always drops a highly enchanted weapon.
## Only found in special rooms or rare spawns.

func _init() -> void:
	super._init()
	mob_id = "golden_statue"
	mob_name = "Golden Statue"
	description = "A magnificent golden statue radiating magical energy. It wields a superbly enchanted weapon."
	# Even tankier than regular statues
	setup(80, 22, 15, 8, 20, 15, 0.7)
	xp_value = 20
	awareness = 0.8
	aggro_range = 6

## Scale with extra power and generate a highly upgraded weapon.
func scale_to_depth(p_depth: int) -> void:
	@warning_ignore("integer_division")
	var tier: int = 1 + p_depth / 5
	hp = 50 + tier * 20
	hp_max = hp
	ht = hp
	attack_skill = 15 + tier * 6
	defense_skill = 10 + tier * 4
	damage_roll_min = 6 + tier * 4
	damage_roll_max = 14 + tier * 5
	armor_value = 10 + tier * 4
	xp_value = 10 + tier * 5
	spawn_pos = pos
	# Generate a highly enchanted weapon
	_generate_golden_weapon(tier)

func _generate_golden_weapon(tier: int) -> void:
	if not Generator:
		return
	# Golden statues always wield high-tier weapons
	weapon = Generator.random_weapon_for_tier(tier)
	if weapon == null:
		return
	# Upgrade it significantly
	if "level" in weapon:
		weapon.level = tier + 2
	if weapon.has_method("enchant"):
		weapon.enchant(WeaponEnchantment.random())
	# Ensure it's not cursed
	if "cursed" in weapon:
		weapon.cursed = false

## Golden statues take reduced damage (stone resilience).
func take_damage(dmg: int, source: Variant = null) -> int:
	# 25% damage reduction
	var reduced: int = maxi(1, int(dmg * 0.75))
	return super.take_damage(reduced, source)
