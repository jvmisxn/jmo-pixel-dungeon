class_name UnarmedAbilityTracker
extends Buff
## Marks the Monk as mid unarmed-ability strike. While attached the hero's
## damage roll ignores the equipped weapon and rolls unarmed damage
## (1..max(1, STR-8)), weapon enchantments do not proc, and MonkEnergy kill
## gains defer the energy cap until the ability finishes spending.
## Original: MonkEnergy.MonkAbility.UnarmedAbilityTracker (FlavourBuff),
## checked in Hero.damageRoll and MonkEnergy.gainEnergy.

func _init() -> void:
	buff_id = "UnarmedAbilityTracker"
	buff_name = "Unarmed Strike"
	buff_type = BuffType.POSITIVE
	show_in_ui = false
