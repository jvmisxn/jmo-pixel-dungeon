class_name Terror
extends Buff
## Terrified characters flee from the source of terror.

var source_id: int = -1  # actor_id of the terror source
const BASE_DURATION: float = 5.0

func _init() -> void:
	buff_id = "Terror"
	buff_name = "Terrified"
	buff_type = BuffType.NEGATIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.6, 0.0, 0.8)

static func create(terror_source_id: int, dur: float = BASE_DURATION) -> Terror:
	var t: Terror = Terror.new()
	t.source_id = terror_source_id
	t.duration = dur
	t.time_left = dur
	return t

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["source_id"] = source_id
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	source_id = data.get("source_id", -1)

func description() -> String:
	return "Terrified! Fleeing from the source of terror."
