class_name ParalysisResist
extends Buff
## Accumulates damage taken while paralyzed so repeated hits make paralysis
## progressively easier to break. Once paralysis ends the tally decays by
## 10% (rounded up) per turn and the buff detaches at zero.
## Original: Paralysis.ParalysisResist (positive buff, slow decay).

var damage: int = 0

func _init() -> void:
	buff_id = "ParalysisResist"
	buff_name = "Paralysis Resistance"
	buff_type = BuffType.POSITIVE
	duration = -1
	show_in_ui = false

func on_turn() -> void:
	if target == null:
		return
	if target.get_buff("Paralysis") == null:
		damage -= ceili(damage / 10.0)
		if damage <= 0:
			target.remove_buff(self)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["damage"] = damage
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	damage = int(data.get("damage", 0))
