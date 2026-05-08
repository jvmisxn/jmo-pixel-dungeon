class_name Barrier
extends Buff
## Barrier: temporary shielding that absorbs damage.
## Original: ShieldBuff subclass, shielding decays by 1 per turn.
## Used by Brimstone glyph, BrokenSeal, various talents.

var shield_amount: int = 0

func _init() -> void:
	buff_id = "Barrier"
	buff_name = "Barrier"
	buff_type = BuffType.POSITIVE
	duration = -1  # Managed by shield depletion
	icon_color = Color(0.5, 0.8, 1.0)

func shielding() -> int:
	return shield_amount

func set_shield(amount: int) -> void:
	shield_amount = amount
	_apply_to_target()

func inc_shield(amount: int) -> void:
	shield_amount += amount
	_apply_to_target()

func absorb_damage(dmg: int) -> int:
	## Absorb damage from shield. Returns remaining damage after absorption.
	var absorbed: int = mini(shield_amount, dmg)
	shield_amount -= absorbed
	if shield_amount <= 0:
		if target:
			target.remove_buff(self)
	return dmg - absorbed

func _apply_to_target() -> void:
	if target:
		target.shielding = maxi(target.shielding, shield_amount)

func on_turn() -> void:
	# Barrier decays by 1 each turn (original behavior)
	shield_amount -= 1
	if shield_amount <= 0:
		if target:
			target.remove_buff(self)
	elif target:
		target.shielding = shield_amount

func on_detach() -> void:
	if target:
		target.shielding = maxi(0, target.shielding - shield_amount)

func merge(other: Node) -> void:
	if other is Barrier:
		# Take the max shield, don't stack
		shield_amount = maxi(shield_amount, (other as Barrier).shield_amount)
		_apply_to_target()
	else:
		super.merge(other)

func is_expired() -> bool:
	return shield_amount <= 0

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["shield_amount"] = shield_amount
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	shield_amount = data.get("shield_amount", 0)

func icon_text() -> String:
	return str(shield_amount) if shield_amount > 0 else ""

func description() -> String:
	return "Protected by a barrier (%d shielding remaining)." % shield_amount
