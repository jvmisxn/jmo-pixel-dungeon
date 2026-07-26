class_name HoldFastBuff
extends Buff
## Warrior talent effect (upstream Talent.HOLD_FAST / buffs/HoldFast.java):
## waiting braces the Warrior on his current tile. While he stays there he
## gains bonus armor (NormalIntRange(points, 2*points) per hit) and the decay
## of combo and shielding buffs slows by 50%/75%/100% per talent point.
## The buff detaches as soon as he stands anywhere else.

## Tile the Warrior braced on. -1 until set by the wait action.
var hold_pos: int = -1

func _init() -> void:
	buff_id = "HoldFast"
	buff_name = "Hold Fast"
	buff_type = BuffType.POSITIVE
	duration = -1
	icon_color = Color(0.55, 0.7, 0.95)

func on_turn() -> void:
	# Upstream HoldFast.act(): detach once the target has moved off the tile.
	if target == null or target.get("pos") != hold_pos:
		if target != null:
			target.remove_buff(self)

func _points() -> int:
	if target != null and target.has_method("get_talent_level"):
		return target.get_talent_level("warrior_hold_fast")
	return 0

## Upstream HoldFast.armorBonus(): NormalIntRange(points, 2*points) while
## still standing on the braced tile; otherwise detach and grant nothing.
func armor_bonus() -> int:
	if target == null or target.get("pos") != hold_pos:
		if target != null:
			target.remove_buff(self)
		return 0
	var points: int = _points()
	if points <= 0:
		return 0
	return Balance.normal_int_range(points, 2 * points)

## Upstream HoldFast.buffDecayFactor(): multiplier on combo/shielding decay
## speed — 0.5/0.25/0.0 at 1/2/3 points while braced, 1.0 otherwise.
static func decay_factor(ch: Node) -> float:
	if ch == null or not ch.has_method("get_buff"):
		return 1.0
	var buff: HoldFastBuff = ch.get_buff("HoldFast") as HoldFastBuff
	if buff == null:
		return 1.0
	if ch.get("pos") != buff.hold_pos:
		ch.remove_buff(buff)
		return 1.0
	match buff._points():
		1:
			return 0.5
		2:
			return 0.25
		3:
			return 0.0
	return 1.0

func description() -> String:
	var points: int = _points()
	return "The Warrior braces on this tile, gaining %d-%d bonus armor and slowing the decay of combo and shielding buffs. Moving ends the effect." % [points, 2 * points]

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["hold_pos"] = hold_pos
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	hold_pos = int(data.get("hold_pos", -1))
