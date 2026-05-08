class_name Charm
extends Buff
## Charmed characters cannot attack or harm the charm source.

var source_id: int = -1  # actor_id of the charmer
const BASE_DURATION: float = 5.0

func _init() -> void:
	buff_id = "Charm"
	buff_name = "Charmed"
	buff_type = BuffType.NEGATIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(1.0, 0.4, 0.6)

static func create(charmer_id: int, dur: float = BASE_DURATION) -> Charm:
	var c: Charm = Charm.new()
	c.source_id = charmer_id
	c.duration = dur
	c.time_left = dur
	return c

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["source_id"] = source_id
	return data

func description() -> String:
	return "Charmed! Cannot harm the source of the charm."
