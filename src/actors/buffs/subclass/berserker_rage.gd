class_name BerserkerRage
extends Buff
## Berserker subclass passive. Activates Fury-like damage boost at low HP.
## Additionally tracks rage buildup from damage taken, which can prevent
## a single killing blow when maxed.

var rage: float = 0.0
const MAX_RAGE: float = 100.0
## Whether the death-prevention has been used this fight.
var rage_used: bool = false

func _init() -> void:
	buff_id = "BerserkerRage"
	buff_name = "Berserker Rage"
	duration = -1.0  # permanent
	icon_color = Color(0.9, 0.2, 0.1)

func modify_damage(dmg: int) -> int:
	if target == null:
		return dmg
	# Bonus damage when below 50% HP, scaling with missing HP
	var hp_ratio: float = float(target.hp) / float(target.hp_max)
	if hp_ratio < 0.5:
		var missing_ratio: float = 1.0 - hp_ratio
		var bonus: float = missing_ratio * 0.8  # up to +80% at 1 HP
		return int(dmg * (1.0 + bonus))
	return dmg

func on_damage_taken(amount: int, _source: Variant) -> void:
	# Build rage from damage taken
	rage = minf(rage + amount * 2.0, MAX_RAGE)

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
