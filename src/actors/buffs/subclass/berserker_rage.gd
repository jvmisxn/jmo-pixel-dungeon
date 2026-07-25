class_name BerserkerRage
extends Buff
## Berserker subclass passive. Activates Fury-like damage boost at low HP.
## Additionally tracks rage buildup from damage taken, which can prevent
## a single killing blow when maxed.

var rage: float = 0.0
const MAX_RAGE: float = 100.0
## Whether the death-prevention has been used this fight.
var rage_used: bool = false

## Upstream Talent.ENDLESS_RAGE: rage cap raised by 16.67% per point
## (up to 150%). Excess rage above 100% further empowers the fury.
func max_rage() -> float:
	return MAX_RAGE * (1.0 + 0.1667 * _endless_rage_points())

func _endless_rage_points() -> int:
	if target != null and target.has_method("get_talent_level"):
		return target.get_talent_level("berserker_endless_rage")
	return 0

func _init() -> void:
	buff_id = "BerserkerRage"
	buff_name = "Berserker Rage"
	duration = -1.0  # permanent
	icon_color = Color(0.9, 0.2, 0.1)

func modify_damage(dmg: int) -> int:
	if target == null:
		return dmg
	var result: float = float(dmg)
	# Bonus damage when below 50% HP, scaling with missing HP
	var hp_ratio: float = float(target.hp) / float(target.hp_max)
	if hp_ratio < 0.5:
		var missing_ratio: float = 1.0 - hp_ratio
		var bonus: float = missing_ratio * 0.8  # up to +80% at 1 HP
		result *= 1.0 + bonus
	# Endless Rage overfill: rage past 100% multiplies damage (up to x1.5),
	# mirroring upstream Berserk where power above 1.0 empowers berserking.
	if rage > MAX_RAGE:
		result *= rage / MAX_RAGE
	return int(result)

func on_damage_taken(amount: int, _source: Variant) -> void:
	# Build rage from damage taken
	rage = minf(rage + amount * 2.0, max_rage())

func on_turn() -> void:
	# Rage decays slowly when not taking damage
	if rage > 0:
		rage = maxf(0, rage - 1.0)
	# Reset rage_used between fights (when fully healed)
	if target and target.hp >= target.hp_max:
		rage_used = false

## Called from Hero._on_death override — prevents death once per fight at max rage.
func try_prevent_death() -> bool:
	if rage >= MAX_RAGE and not rage_used:
		rage_used = true
		rage = 0.0
		if target:
			target.hp = 1
			target.is_alive = true
		if MessageLog:
			MessageLog.add_positive("Your rage refuses to let you fall!")
		return true
	return false

func description() -> String:
	if rage > 0:
		return "Berserker Rage (%.0f%%)" % (rage / MAX_RAGE * 100)
	return "Berserker Rage"

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["rage"] = rage
	data["rage_used"] = rage_used
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	rage = float(data.get("rage", rage))
	rage_used = bool(data.get("rage_used", rage_used))
