class_name WealthTriesTracker
extends Buff
## Ring of Wealth bonus-drop deck counter (upstream
## RingOfWealth.TriesToDropTracker, a CounterBuff). Counts down one per
## qualifying kill; when it hits zero the deck pays out a bonus drop and the
## counter refills with NormalIntRange(0, 20). Persists through saves and
## revives so the deck cannot be reset by save-scumming.

var count: float = 0.0

func _init() -> void:
	buff_id = "WealthTriesTracker"
	buff_name = "Wealth Tries Tracker"
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
