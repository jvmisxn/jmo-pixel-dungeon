class_name WealthEquipTracker
extends Buff
## Ring of Wealth equipment-deck counter (upstream
## RingOfWealth.DropsToEquipTracker, a CounterBuff). Counts down one per
## consumable bonus drop; when it hits zero the next payout is an equipment
## drop and the counter refills with NormalIntRange(5, 10). Persists through
## saves and revives.

var count: float = 0.0

func _init() -> void:
	buff_id = "WealthEquipTracker"
	buff_name = "Wealth Equip Tracker"
	buff_type = BuffType.NEUTRAL
	duration = -1
	show_in_ui = false
	revive_persists = true

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["count"] = count
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	count = float(data.get("count", count))
