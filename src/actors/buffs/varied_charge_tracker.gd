class_name VariedChargeTracker
extends Buff
## Champion Varied Charge talent tracker. Original: Talent.VariedChargeTracker
## (plain Buff, no time limit, hidden). Remembers which weapon last used a
## Duelist ability; using an ability with a different weapon consumes the
## tracker and refunds points/6 charge (upstream MeleeWeapon.afterAbilityUsed).

var weapon_id: String = ""

func _init() -> void:
	buff_id = "VariedChargeTracker"
	buff_name = "Varied Charge"
	duration = -1.0  # Upstream tracker has no time limit
	show_in_ui = false

func description() -> String:
	return "Tracks the weapon that last used an ability; using a " \
			+ "different weapon's ability will refund some charge."

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["weapon_id"] = weapon_id
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	weapon_id = str(data.get("weapon_id", ""))
