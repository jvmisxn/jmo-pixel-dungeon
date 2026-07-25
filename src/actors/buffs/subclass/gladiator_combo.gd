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

func _init() -> void:
	buff_id = "GladiatorCombo"
	buff_name = "Combo"
	duration = -1.0
	icon_color = Color(0.9, 0.7, 0.1)

func on_damage_dealt(_amount: int, hit_target: Node) -> void:
	combo_count = mini(combo_count + 1, MAX_COMBO)
	if hit_target != null and hit_target.get("is_alive") == false:
		combo_window = KILL_WINDOW + KILL_WINDOW * _cleave_points()
	else:
		# A normal hit does not refresh an extended kill window; it keeps
		# ticking down, like upstream comboTime = max(comboTime, 5f).
		combo_window = maxi(combo_window - turns_since_attack, BASE_WINDOW)
	turns_since_attack = 0

func _cleave_points() -> int:
	if target != null and target.has_method("get_talent_level"):
		return target.get_talent_level("gladiator_cleave")
	return 0

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

func modify_damage(dmg: int) -> int:
	if combo_count >= 3:
		var mult: float = get_combo_multiplier()
		var boosted: int = int(dmg * mult)
		# Consume combo on finisher
		if combo_count >= 3:
			if MessageLog:
				MessageLog.add_positive("Combo finisher! (x%.1f)" % mult)
			combo_count = 0
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
