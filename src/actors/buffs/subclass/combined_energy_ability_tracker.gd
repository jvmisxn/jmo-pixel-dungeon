class_name CombinedEnergyAbilityTracker
extends Buff
## Monk Combined Energy talent window. Original:
## Talent.CombinedEnergyAbilityTracker (5-turn FlavourBuff, hidden).
## A qualifying monk ability or a weapon ability arms this tracker; using
## the other kind while it is active refunds 1 monk energy
## (MonkEnergy.process_combined_energy) and consumes the tracker.

var monk_abil_used: bool = false
var wep_abil_used: bool = false

func _init() -> void:
	buff_id = "CombinedEnergyAbilityTracker"
	buff_name = "Combined Energy"
	duration = 5.0
	show_in_ui = false

func description() -> String:
	return "Following up an ability with the other kind (monk or weapon) " \
			+ "within a few turns will refund 1 monk energy."

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["monk_abil_used"] = monk_abil_used
	data["wep_abil_used"] = wep_abil_used
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	monk_abil_used = bool(data.get("monk_abil_used", false))
	wep_abil_used = bool(data.get("wep_abil_used", false))
