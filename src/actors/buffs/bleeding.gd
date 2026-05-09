class_name Bleeding
extends Buff
## Deals damage each turn based on remaining bleed level. Decreases over time.

var bleed_level: float = 0.0

func _init() -> void:
	buff_id = "Bleeding"
	buff_name = "Bleeding"
	buff_type = BuffType.NEGATIVE
	duration = -1  # Managed by bleed_level
	icon_color = Color(0.8, 0.0, 0.0)

static func create(amount: float) -> Bleeding:
	var b: Bleeding = Bleeding.new()
	b.bleed_level = amount
	return b

func on_turn() -> void:
	if target == null:
		return
	# Original: level = NormalFloat(level/2, level); dmg = round(level)
	# The level itself decays each tick to a random value between half and full,
	# and that new level is also the damage dealt.
	bleed_level = randf_range(bleed_level / 2.0, bleed_level)
	var dmg: int = roundi(bleed_level)
	if dmg > 0:
		target.take_damage(dmg, self)
	else:
		if target:
			target.remove_buff(self)

## Set bleed level (takes the higher of current vs new, matching original).
func set_level(amount: float) -> void:
	bleed_level = maxf(bleed_level, amount)

## Extend bleed by adding to the level.
func extend(amount: float) -> void:
	bleed_level += amount

func description() -> String:
	return "Bleeding! Taking %d damage per turn." % roundi(bleed_level)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["bleed_level"] = bleed_level
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	bleed_level = float(data.get("bleed_level", bleed_level))
