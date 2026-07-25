class_name GladiatorCombo
extends Buff
## Gladiator subclass passive. Tracks successive hits and applies combo finisher.

var combo_count: int = 0
const MAX_COMBO: int = 10
## Turns since last attack (combo resets if > combo_window).
var turns_since_attack: int = 0
## How many turns the combo persists without attacking. Normally 1 turn, but a
## killing combo hit extends it — upstream Combo.hit() sets comboTime to
## 15 + 15*Cleave points versus a base of 5 (3x base, +3x per Cleave point).
## The port's base window is 1 turn, so a kill extends it to 3 + 3*points.
const BASE_WINDOW: int = 1
const KILL_WINDOW: int = 3
var combo_window: int = BASE_WINDOW
## Set when modify_damage consumes the combo as a finisher, so the
## on_damage_dealt call for the same hit can tell finisher kills apart
## (Lethal Defense only triggers on finisher kills, upstream Combo.doAttack).
var _finisher_this_hit: bool = false

func _init() -> void:
	buff_id = "GladiatorCombo"
	buff_name = "Combo"
	duration = -1.0
	icon_color = Color(0.9, 0.7, 0.1)

func on_damage_dealt(_amount: int, hit_target: Node) -> void:
	combo_count = mini(combo_count + 1, MAX_COMBO)
	var killed: bool = hit_target != null and hit_target.get("is_alive") == false
	if killed:
		combo_window = KILL_WINDOW + KILL_WINDOW * _cleave_points()
	else:
		# A normal hit does not refresh an extended kill window; it keeps
		# ticking down, like upstream comboTime = max(comboTime, 5f).
		combo_window = maxi(combo_window - turns_since_attack, BASE_WINDOW)
	turns_since_attack = 0
	if killed and _finisher_this_hit:
		_apply_lethal_defense()
	_finisher_this_hit = false

func _cleave_points() -> int:
	return _talent_points("gladiator_cleave")

func _talent_points(talent_id: String) -> int:
	if target != null and target.has_method("get_talent_level"):
		return target.get_talent_level(talent_id)
	return 0

## Lethal Defense (upstream Talent.LETHAL_DEFENSE): a finisher kill reduces the
## broken seal shield's cooldown by 50/100/150 turns, down to -150 at most —
## upstream Combo.doAttack: Buff.affect(hero, WarriorShield).reduceCooldown(points/3).
func _apply_lethal_defense() -> void:
	var points: int = _talent_points("gladiator_lethal_defense")
	if points <= 0 or target == null:
		return
	var shield: Node = target.get_buff("WarriorShield")
	if shield == null:
		shield = target.add_buff(WarriorShield.new())
	if shield != null and shield.has_method("reduce_cooldown"):
		shield.reduce_cooldown(50 * points)

func on_turn() -> void:
	turns_since_attack += 1
	if turns_since_attack > combo_window:
		if combo_count > 0:
			combo_count = 0
		combo_window = BASE_WINDOW

## Get the combo damage multiplier for a finisher.
func get_combo_multiplier() -> float:
	if combo_count < 3:
		return 1.0
	# Scale from 1.5x at 3 hits to 3.0x at 10 hits
	var t: float = float(combo_count - 3) / float(MAX_COMBO - 3)
	return 1.5 + t * 1.5

## Enhanced Combo (upstream Talent.ENHANCED_COMBO): upstream empowers manual
## combo moves used at higher counts (Clobber knockback+vertigo at 7+, Parry at
## 9+, leap range and AoE at +3). The port's combo has no manual moves — it is
## an auto-finisher — so each point instead raises the finisher threshold by 2
## (3 -> 5/7/9 hits), letting the combo build toward the x3.0 multiplier cap.
func finisher_threshold() -> int:
	return 3 + 2 * _talent_points("gladiator_enhanced_combo")

func modify_damage(dmg: int) -> int:
	if combo_count >= finisher_threshold():
		var mult: float = get_combo_multiplier()
		var boosted: int = int(dmg * mult)
		# Consume combo on finisher
		if MessageLog:
			MessageLog.add_positive("Combo finisher! (x%.1f)" % mult)
		combo_count = 0
		_finisher_this_hit = true
		return boosted
	return dmg

func description() -> String:
	if combo_count > 0:
		return "Combo (%d hits)" % combo_count
	return "Combo"

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["combo_count"] = combo_count
	data["turns_since_attack"] = turns_since_attack
	data["combo_window"] = combo_window
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	combo_count = int(data.get("combo_count", combo_count))
	turns_since_attack = int(data.get("turns_since_attack", turns_since_attack))
	combo_window = int(data.get("combo_window", combo_window))
