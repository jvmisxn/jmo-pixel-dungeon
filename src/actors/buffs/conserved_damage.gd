class_name ConservedDamage
extends Buff
## Kinetic enchant stored overkill (upstream Kinetic.ConservedDamage).
## Holds excess damage from a killing Kinetic hit; the next Kinetic proc
## consumes it as bonus damage. Decays each turn by 2.5% of the remainder
## (minimum 0.1) until empty.

var preserved_damage: float = 0.0

func _init() -> void:
	buff_id = "ConservedDamage"
	buff_name = "Conserved Damage"
	buff_type = BuffType.POSITIVE
	duration = -1  # managed by decay
	icon_color = Color(0.85, 0.75, 0.3)  # kinetic golden

func set_bonus(bonus: int) -> void:
	preserved_damage = float(bonus)

## Upstream damageBonus(): ceil of the decaying float.
func damage_bonus() -> int:
	return int(ceilf(preserved_damage))

func on_turn() -> void:
	preserved_damage -= maxf(preserved_damage * 0.025, 0.1)
	if preserved_damage <= 0.0 and target:
		target.remove_buff(self)

func is_expired() -> bool:
	return preserved_damage <= 0.0

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["preserved_damage"] = preserved_damage
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	preserved_damage = float(data.get("preserved_damage", 0.0))

func icon_text() -> String:
	return str(damage_bonus()) if preserved_damage > 0.0 else ""

func description() -> String:
	return "Your weapon has conserved kinetic energy from a recent kill. " \
		+ "Your next attack with it will deal %d bonus damage." % damage_bonus()
