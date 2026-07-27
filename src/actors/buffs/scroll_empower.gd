class_name ScrollEmpower
extends Buff
## Mage Inscribed Power effect (upstream buffs/ScrollEmpower.java): reading a
## scroll empowers the Mage's next 1+points (2/3) wand zaps with +2 bonus wand
## levels. Permanent until consumed — Wand.zap calls use() once per zap,
## detaching the buff when the counter hits 0. Re-reading routes through
## Char.add_buff's merge path; upstream reset() never lowers the counter
## (left = max(left, new)).

var zaps_left: int = 0

func _init() -> void:
	buff_id = "ScrollEmpower"
	buff_name = "Scroll Empower"
	buff_type = BuffType.POSITIVE
	duration = -1
	icon_color = Color(0.84, 0.79, 0.65)  # upstream scroll-colors tint

## Upstream ScrollEmpower.reset: left = max(left, new_left).
func reset(new_left: int) -> void:
	zaps_left = maxi(zaps_left, new_left)

## Upstream ScrollEmpower.use: decrement, detach at 0.
func use() -> void:
	zaps_left -= 1
	if zaps_left <= 0 and target != null and target.has_method("remove_buff_by_id"):
		target.remove_buff_by_id("ScrollEmpower")

func merge(other: Node) -> void:
	if other is ScrollEmpower:
		reset((other as ScrollEmpower).zaps_left)

func description() -> String:
	return ("Empowered by inscribed magic, the Mage's next %d wand zap%s " +
		"gain 2 bonus wand levels.") \
		% [zaps_left, "" if zaps_left == 1 else "s"]

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["zaps_left"] = zaps_left
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	zaps_left = int(data.get("zaps_left", 0))
