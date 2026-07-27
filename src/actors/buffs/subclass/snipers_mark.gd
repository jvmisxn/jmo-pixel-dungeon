class_name SnipersMark
extends Buff
## Upstream SnipersMark (Sniper subclass): after the Sniper hits with a thrown
## missile weapon, the target is marked for 4 turns and she can fire a special
## spirit-bow shot at it. Port adaptation: the port has no actor-id registry or
## ActionIndicator, so the mark attaches to the marked ENEMY (like
## CharAwareness) and tapping the marked enemy fires the special shot.
## Shared Upgrades stores its damage bonus here (upstream percentDmgBonus).

var percent_dmg_bonus: float = 0.0

const DURATION: float = 4.0

func _init() -> void:
	buff_id = "SnipersMark"
	buff_name = "Sniper's Mark"
	buff_type = BuffType.NEGATIVE
	duration = DURATION
	time_left = DURATION
	icon_color = Color(0.85, 0.75, 0.2)

## Upstream Buff.prolong + set(): duration extends to the larger value and the
## newest mark's damage bonus replaces the old one.
func merge(other: Node) -> void:
	super.merge(other)
	if other is SnipersMark:
		percent_dmg_bonus = (other as SnipersMark).percent_dmg_bonus

func description() -> String:
	return "This creature is marked by the Sniper. Tapping it fires a special spirit bow shot."

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["percent_dmg_bonus"] = percent_dmg_bonus
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	percent_dmg_bonus = float(data.get("percent_dmg_bonus", percent_dmg_bonus))
