class_name CombinedLethalityAbilityTracker
extends Buff
## Champion Combined Lethality talent window. Original:
## Talent.CombinedLethalityAbilityTracker (hidden FlavourBuff lasting
## hero.cooldown()). A weapon ability arms it; a melee hit with a different
## weapon while armed executes low-HP non-boss enemies (Char.attack block)
## and consumes it either way.

## Runtime reference to the weapon whose ability armed the tracker. Upstream
## does not bundle this field either, so after a save/load it restores null,
## which still counts as "a different weapon" on the next hit.
var weapon: Variant = null

func _init() -> void:
	buff_id = "CombinedLethalityAbilityTracker"
	buff_name = "Combined Lethality"
	duration = 1.0
	show_in_ui = false

func description() -> String:
	return "An attack with a different melee weapon will execute enemies " \
			+ "left at low health."
