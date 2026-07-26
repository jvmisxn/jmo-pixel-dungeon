class_name WarriorFoodImmunity
extends Buff
## Warrior Iron Stomach immunity window (upstream Talent.WarriorFoodImmunity,
## a FlavourBuff lasting the eating cooldown). Hero.take_damage quarters
## incoming damage at +1 and negates it at +2 while this is active.
## Port adaptation: eating always takes 1 turn in this port (upstream base is
## 3 turns, reduced to 1 by this talent), so the buff covers that single
## eating turn.

const DURATION := 1.0

func _init() -> void:
	buff_id = "WarriorFoodImmunity"
	buff_name = "Iron Stomach"
	buff_type = BuffType.POSITIVE
	duration = DURATION
	icon_color = Color(0.8, 0.72, 0.5)

func description() -> String:
	return "The Warrior's iron stomach lets him shrug off damage while he eats."
