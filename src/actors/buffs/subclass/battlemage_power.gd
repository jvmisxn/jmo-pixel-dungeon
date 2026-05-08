class_name BattemagePower
extends Buff
## Battlemage subclass passive. Boosts wand recharge rate and triggers
## on-hit wand effects from staff melee attacks.

func _init() -> void:
	buff_id = "BattemagePower"
	buff_name = "Battlemage"
	duration = -1.0
	icon_color = Color(0.3, 0.5, 0.9)

## Wand recharge speed multiplier (33% faster).
func wand_recharge_multiplier() -> float:
	return 1.33

## Called when the Battlemage lands a melee hit with staff.
## Triggers the imbued wand's on-hit effect.
func on_staff_hit(enemy: Node) -> void:
	if target == null or not target.get("is_hero") == true:
		return
	var hero: Node = target
	if hero.belongings == null:
		return
	# Check if weapon is a staff with imbued wand
	var weapon: Variant = hero.belongings.weapon
	if weapon == null:
		return
	if not weapon.has_method("get_imbued_wand"):
		return
	var wand: Variant = weapon.get_imbued_wand()
	if wand and wand.has_method("on_hit_effect"):
		wand.on_hit_effect(enemy)
	# Chance to gain a charge on the imbued wand
	if wand and wand.has_method("gain_charge") and randf() < 0.33:
		wand.gain_charge(1)

func on_damage_dealt(amount: int, hit_target: Node) -> void:
	# Trigger staff on-hit if using staff weapon
	if amount > 0:
		on_staff_hit(hit_target)

func description() -> String:
	return "Battlemage (wands recharge faster when attacking)."
