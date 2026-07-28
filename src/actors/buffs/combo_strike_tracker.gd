class_name ComboStrikeTracker
extends Buff
## Duelist combo hit counter. Original: Sai.ComboStrikeTracker.
## Every Duelist hit on an enemy adds a hit and resets the 5-turn window;
## the Gloves/Sai Combo Strike ability consumes the tracker for bonus
## damage per recent hit. Upstream hides the buff icon unless a
## combo-family weapon is equipped and announces combos from 2 hits.

const WINDOW: float = 5.0

var hits: int = 0

func _init() -> void:
	buff_id = "ComboStrikeTracker"
	buff_name = "Combo"
	buff_type = BuffType.POSITIVE
	duration = WINDOW
	show_in_ui = false

## Upstream Sai.ComboStrikeTracker.addHit: count the hit, reset the
## 5-turn window, and announce combos of 2+ while a combo weapon is worn.
func add_hit() -> void:
	hits += 1
	time_left = WINDOW
	show_in_ui = _combo_weapon_equipped()
	if hits >= 2 and show_in_ui and MessageLog:
		MessageLog.add_positive("%d hit combo!" % hits)

func _combo_weapon_equipped() -> bool:
	if target is Hero:
		var held: Variant = (target as Hero).belongings.weapon
		if held is MeleeWeapon:
			return (held as MeleeWeapon).ability_kind() == "combo_strike"
	return false

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["hits"] = hits
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	hits = int(data.get("hits", 0))

func description() -> String:
	return "You have landed %d recent hit%s. The combo strike weapon ability deals bonus damage per recent hit." \
			% [hits, "" if hits == 1 else "s"]
