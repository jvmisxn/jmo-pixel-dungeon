class_name WandPreservationCounter
extends Buff
## Mage Wand Preservation tracker (upstream Talent.WandPreservationCounter, a
## CounterBuff). MagesStaff.imbue_new_wand preserves the replaced wand at +0
## only while this counter is 0, then counts up. At +2 talent points the hero
## detaches the counter on level-up (upstream Hero.earnExp), giving the
## "repeatable with a one hero level cooldown" behavior. Hidden from the buff
## bar like upstream (no icon).

var count: int = 0

func _init() -> void:
	buff_id = "WandPreservationCounter"
	buff_name = "Wand Preservation"
	buff_type = BuffType.NEUTRAL
	duration = -1
	show_in_ui = false

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["count"] = count
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	count = int(data.get("count", 0))
