class_name BerserkerRage
extends Buff
## Berserker subclass passive. Activates Fury-like damage boost at low HP.
## Additionally tracks rage buildup from damage taken, which can prevent
## a single killing blow when maxed.

var rage: float = 0.0
const MAX_RAGE: float = 100.0
## Turns left before deathless fury can trigger again. Port adaptation of
## upstream Berserk levelRecovery (4 - Deathless Fury points, in hero levels):
## one level is approximated as 25 turns. No rage builds while recovering.
var recovery_left: float = 0.0
const RECOVERY_TURNS_PER_LEVEL: float = 25.0

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
	# Build rage from damage taken. Upstream Berserk.damage() gains no power
	# while berserking/recovering.
	if recovery_left > 0:
		return
	rage = minf(rage + amount * 2.0, max_rage())

func on_turn() -> void:
	# Rage decays slowly when not taking damage
	if rage > 0:
		rage = maxf(0, rage - 1.0)
	if recovery_left > 0:
		recovery_left = maxf(0.0, recovery_left - 1.0)

func _deathless_fury_points() -> int:
	if target != null and target.has_method("get_talent_level"):
		return target.get_talent_level("berserker_deathless_fury")
	return 0

## Upstream Berserk.currentShieldBoost(): base 8 + 2*armor level, multiplied
## by 1 + 2*(1 - HP/HT)^3 (3x at 0 HP), further multiplied by overfill power.
func deathless_shield_amount() -> int:
	var base_shield: float = 8.0
	if target != null and target.get("belongings") != null:
		var armor: Variant = target.belongings.get_equipped_armor()
		if armor != null and armor.has_method("buffed_lvl"):
			base_shield += 2.0 * float(armor.buffed_lvl())
	var hp_ratio: float = 0.0
	if target != null and target.hp_max > 0:
		hp_ratio = clampf(float(maxi(target.hp, 0)) / float(target.hp_max), 0.0, 1.0)
	var multiplier: float = 1.0 + 2.0 * pow(1.0 - hp_ratio, 3.0)
	if rage > MAX_RAGE:
		multiplier *= rage / MAX_RAGE
	return roundi(base_shield * multiplier)

## Called from Hero._try_prevent_death. Upstream Berserk.berserking(): only
## with the Deathless Fury talent can a lethal hit start berserking instead of
## death. Port adaptation: the hero survives at 1 HP with an upstream-formula
## Barrier instead of standing at 0 HP behind shielding.
func try_prevent_death() -> bool:
	if _deathless_fury_points() <= 0:
		return false
	if rage < MAX_RAGE or recovery_left > 0:
		return false
	var shield: int = deathless_shield_amount()
	recovery_left = RECOVERY_TURNS_PER_LEVEL * float(4 - mini(_deathless_fury_points(), 3))
	rage = 0.0
	if target:
		target.hp = 1
		target.is_alive = true
		var barrier: Barrier = target.get_buff("Barrier") as Barrier
		if barrier == null:
			barrier = target.add_buff(Barrier.new()) as Barrier
		if barrier != null:
			barrier.inc_shield(shield)
	if MessageLog:
		MessageLog.add_positive("Your rage refuses to let you fall!")
	return true

func description() -> String:
	if recovery_left > 0:
		return "Berserker Rage (recovering, %d turns)" % int(ceilf(recovery_left))
	if rage > 0:
		return "Berserker Rage (%.0f%%)" % (rage / MAX_RAGE * 100)
	return "Berserker Rage"

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["rage"] = rage
	data["recovery_left"] = recovery_left
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	rage = float(data.get("rage", rage))
	recovery_left = float(data.get("recovery_left", recovery_left))
	# Legacy saves stored a once-per-fight rage_used flag instead of a
	# recovery timer; map a spent flag to a conservative 3-level recovery.
	if bool(data.get("rage_used", false)) and recovery_left <= 0:
		recovery_left = RECOVERY_TURNS_PER_LEVEL * 3.0
