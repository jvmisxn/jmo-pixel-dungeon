class_name WandEmpower
extends Buff
## Mage Empowering Meal effect (upstream buffs/WandEmpower.java): eating food
## grants bonus damage on the hero's next 3 damage-wand zaps. Permanent until
## consumed — each damage-wand roll (Wand.roll_zap_damage with a hero) adds
## dmg_boost, decrements zaps_left, and detaches the buff when it hits 0.

var dmg_boost: int = 0
var zaps_left: int = 0

func _init() -> void:
	buff_id = "WandEmpower"
	buff_name = "Wand Empower"
	buff_type = BuffType.POSITIVE
	duration = -1
	icon_color = Color(1.0, 1.0, 0.0)

## Upstream WandEmpower.set: the boost is overwritten, remaining shots are
## never lowered (left = max(left, shots)).
func set_boost(dmg: int, shots: int) -> void:
	dmg_boost = dmg
	zaps_left = maxi(zaps_left, shots)

## Re-eating while the buff is live routes through Char.add_buff's merge path.
func merge(other: Node) -> void:
	if other is WandEmpower:
		set_boost((other as WandEmpower).dmg_boost, (other as WandEmpower).zaps_left)

func description() -> String:
	return "Empowered by a meal, the Mage's next %d wand zap%s deal %d bonus damage." \
		% [zaps_left, "" if zaps_left == 1 else "s", dmg_boost]

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["dmg_boost"] = dmg_boost
	data["zaps_left"] = zaps_left
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	dmg_boost = int(data.get("dmg_boost", 0))
	zaps_left = int(data.get("zaps_left", 0))
