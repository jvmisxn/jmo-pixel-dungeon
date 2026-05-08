class_name Dread
extends Buff
## Dread: like Terror but stronger — flees at double speed and cannot attack.
## Original: speed *= 2f, mob enters FLEEING state, taking damage calls recover().

var source_id: int = -1

func _init() -> void:
	buff_id = "Dread"
	buff_name = "Dread"
	buff_type = BuffType.NEGATIVE
	duration = -1  # Permanent until source dies or damage accumulates
	icon_color = Color(0.3, 0.0, 0.3)

func modify_speed(speed: float) -> float:
	return speed * 2.0

## Original: taking damage has a chance to break Dread.
func on_damage_taken(amount: int, _source: Variant) -> void:
	if amount > 0 and target:
		# Each hit has a chance to recover based on damage vs HP
		if randi_range(0, amount) >= randi_range(0, target.hp):
			if MessageLog:
				MessageLog.add_info("%s overcomes their dread!" % target.name)
			target.remove_buff(self)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["source_id"] = source_id
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	source_id = data.get("source_id", -1)

func description() -> String:
	return "Overcome with dread! Fleeing at double speed."
