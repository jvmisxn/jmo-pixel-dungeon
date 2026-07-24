class_name Barrier
extends Buff
## Barrier: temporary shielding that absorbs damage.
## Original: ShieldBuff subclass, shielding decays by 1 per turn.
## Used by Brimstone glyph, BrokenSeal, various talents.

var shield_amount: int = 0
## Upstream Barrier.partialLostShield: fractional decay accumulator, reset by
## set_shield/inc_shield so refreshed barriers pause their decay.
var partial_lost_shield: float = 0.0

func _init() -> void:
	buff_id = "Barrier"
	buff_name = "Barrier"
	buff_type = BuffType.POSITIVE
	duration = -1  # Managed by shield depletion
	icon_color = Color(0.5, 0.8, 1.0)

func get_shielding() -> int:
	return shield_amount

func set_shield(amount: int) -> void:
	shield_amount = maxi(0, amount)
	partial_lost_shield = 0.0

func inc_shield(amount: int) -> void:
	shield_amount = maxi(0, shield_amount + amount)
	partial_lost_shield = 0.0

func absorb_damage(dmg: int) -> int:
	## Absorb damage from shield. Returns remaining damage after absorption.
	var absorbed: int = mini(shield_amount, dmg)
	shield_amount -= absorbed
	if shield_amount <= 0:
		if target:
			target.remove_buff(self)
	return dmg - absorbed

func on_turn() -> void:
	# Upstream Barrier.act(): decay is fractional, min(1, shielding/20) per turn,
	# so small barriers persist for several turns instead of losing 1 flat per turn.
	partial_lost_shield += minf(1.0, float(shield_amount) / 20.0)
	if partial_lost_shield >= 1.0:
		partial_lost_shield = 0.0
		shield_amount -= 1
	if shield_amount <= 0:
		if target:
			target.remove_buff(self)

func merge(other: Node) -> void:
	if other is Barrier:
		# Take the max shield, don't stack
		shield_amount = maxi(shield_amount, (other as Barrier).shield_amount)
	else:
		super.merge(other)

func is_expired() -> bool:
	return shield_amount <= 0

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["shield_amount"] = shield_amount
	data["partial_lost_shield"] = partial_lost_shield
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	shield_amount = data.get("shield_amount", 0)
	partial_lost_shield = float(data.get("partial_lost_shield", 0.0))

func icon_text() -> String:
	return str(shield_amount) if shield_amount > 0 else ""

func description() -> String:
	return "Protected by a barrier (%d shielding remaining)." % shield_amount
