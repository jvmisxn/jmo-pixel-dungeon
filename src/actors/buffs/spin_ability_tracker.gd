class_name SpinAbilityTracker
extends Buff
## Duelist Flail Spin wind-up. Original: Flail.SpinAbilityTracker
## (FlavourBuff, 3 turns, re-prolonged by every cast). Stacks up to 3
## spins; the next flail attack releases them as a guaranteed hit with
## +spins*(8+2*lvl) bonus damage, consuming the tracker even if the
## strike is dodged by infinite evasion (upstream Flail.accuracyFactor).

var spins: int = 0

func _init() -> void:
	buff_id = "SpinAbilityTracker"
	buff_name = "Spin"
	buff_type = BuffType.POSITIVE
	announced = true
	icon_color = Color(0.4, 1.0, 0.4)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["spins"] = spins
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	spins = int(data.get("spins", 0))

func description() -> String:
	return "You are spinning your flail, powering up your next attack. " \
			+ "Spin power: %d%%." % [roundi(float(spins) / 3.0 * 100.0)]
