class_name FlurryCooldownTracker
extends Buff
## Blocks a second Flurry cast in the same turn. Original:
## MonkEnergy.MonkAbility.FlurryCooldownTracker (FlavourBuff, 0 turns —
## detaches as soon as any time passes). Port adaptation: buffs here tick
## once per hero turn, so a 1-turn duration expires on the first turn the
## hero actually spends after the instant Flurry.

func _init() -> void:
	buff_id = "FlurryCooldownTracker"
	buff_name = "Flurry Cooldown"
	buff_type = BuffType.NEUTRAL
	duration = 1.0
	show_in_ui = false
