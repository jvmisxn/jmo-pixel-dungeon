class_name StrongmanBuff
extends Buff
## Warrior talent effect (upstream Talent.STRONGMAN, applied in Hero.STR()):
## bonus strength equal to floor(baseSTR * (0.03 + 0.05 * points)), i.e.
## 8%/13%/18% of base strength at 1/2/3 points.
## Like RingOfMight.MightBuff this is a live modifier that mutates str_val
## while attached and is never serialized; the hero persists clean base stats
## via get_str_contribution and rebuilds this buff after load, talent
## upgrades, and base-strength changes (see Hero.update_strongman_bonus).

var _str_bonus: int = 0

func _init() -> void:
	buff_id = "Strongman"
	buff_name = "Strongman"
	buff_type = BuffType.POSITIVE
	duration = -1
	icon_color = Color(0.85, 0.45, 0.2)

func is_persistent() -> bool:
	return false

func description() -> String:
	return "The Warrior's training grants +%d strength on top of his base strength." % _str_bonus

## Amount this buff currently adds to str_val, so the hero can persist a
## clean base value (see Hero.serialize).
func get_str_contribution() -> int:
	return _str_bonus

func on_detach() -> void:
	if target != null:
		target.str_val -= _str_bonus
	_str_bonus = 0

## Recompute the bonus from the hero's base strength (str_val minus every
## live buff contribution, including this buff's own) and current talent
## points, then apply the delta to str_val.
func update_bonus() -> void:
	if target == null:
		return
	var points: int = 0
	if target.has_method("get_talent_level"):
		points = target.get_talent_level("warrior_strongman")
	var base_str: int = int(target.get("str_val"))
	for b: Node in target.get_buffs():
		if b != null and is_instance_valid(b) and b.has_method("get_str_contribution"):
			base_str -= int(b.get_str_contribution())
	var new_bonus: int = 0
	if points > 0:
		new_bonus = int(floor(float(base_str) * (0.03 + 0.05 * float(points))))
	target.str_val += new_bonus - _str_bonus
	_str_bonus = new_bonus
