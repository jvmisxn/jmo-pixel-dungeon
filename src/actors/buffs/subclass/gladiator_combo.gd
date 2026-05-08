class_name GladiatorCombo
extends Buff
## Gladiator subclass passive. Tracks successive hits and applies combo finisher.

var combo_count: int = 0
const MAX_COMBO: int = 10
## Turns since last attack (combo resets if > 1).
var turns_since_attack: int = 0

func _init() -> void:
	buff_id = "GladiatorCombo"
	buff_name = "Combo"
	duration = -1.0
	icon_color = Color(0.9, 0.7, 0.1)

func on_damage_dealt(_amount: int, _target: Node) -> void:
	combo_count = mini(combo_count + 1, MAX_COMBO)
	turns_since_attack = 0

func on_turn() -> void:
	turns_since_attack += 1
	if turns_since_attack > 1:
		if combo_count > 0:
			combo_count = 0

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
