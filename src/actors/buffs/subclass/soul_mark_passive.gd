class_name SoulMarkPassive
extends Buff
## Warlock subclass passive indicator. The marking itself happens in
## Wand._warlock_wand_proc (upstream Wand.wandProc) and restoration in
## SoulMark.process_restoration (upstream Mob.defenseProc).

func _init() -> void:
	buff_id = "SoulMarkPassive"
	buff_name = "Soul Mark"
	duration = -1.0
	icon_color = Color(0.5, 0.2, 1.0)

func description() -> String:
	return ("Wand zaps have a chance to soul mark enemies; the chance and"
		+ " duration grow with wand level. The Warlock heals 2 HP for every 5"
		+ " damage he deals to marked enemies with melee or thrown attacks,"
		+ " not wands.")
