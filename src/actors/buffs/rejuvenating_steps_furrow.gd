class_name RejuvenatingStepsFurrow
extends Buff
## Huntress Rejuvenating Steps anti-farming counter (upstream
## Talent.RejuvenatingStepsFurrow, a CounterBuff with revivePersists). Each
## talent-sprouted grass tile counts it up by 3 - points; once it reaches 200
## the talent produces furrowed grass (no trample drops) until exp gain counts
## it back down (Hero.earn_xp: -200 * level-fraction gained, detach at 0).
## Hidden from the buff bar like upstream.

var count: float = 0.0

func _init() -> void:
	buff_id = "RejuvenatingStepsFurrow"
	buff_name = "Rejuvenating Steps Furrow"
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
	count = float(data.get("count", 0.0))
