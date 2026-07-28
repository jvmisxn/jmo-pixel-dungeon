class_name RunicSlashTracker
extends Buff
## Duelist Runic Slash enchant-power window. Original:
## RunicBlade.RunicSlashTracker. Attached for the single Runic Slash
## ability strike; the enchantment proc-chance roll consumes it, adding
## `boost` (3 + 0.5*lvl) to the proc-chance multiplier. The hero removes
## any leftover tracker right after the strike resolves.

var boost: float = 2.0

func _init() -> void:
	buff_id = "RunicSlashTracker"
	buff_name = "Runic Slash"
	buff_type = BuffType.POSITIVE
	show_in_ui = false

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["boost"] = boost
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	boost = float(data.get("boost", 2.0))

func description() -> String:
	return "Your runic blade glows with power, boosting the next enchantment activation."
