class_name FrostImbue
extends Buff
## FrostImbue: imbues attacks with frost, applying Chill to targets.
## Original (FrostImbue.java): from Potion of Frost / exotic variant.
## Duration: 30 turns. On proc: applies 2 turns of Chill to the target.
## Grants immunity to Chill and Frozen while active.

const BASE_DURATION: float = 30.0

func _init() -> void:
	buff_id = "FrostImbue"
	buff_name = "Frost Imbue"
	buff_type = BuffType.POSITIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.4, 0.7, 1.0)

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_positive("%s's attacks are imbued with frost!" % target.name)

## Called after the owner deals melee damage. Applies Chill to the defender.
func proc(defender: Node) -> void:
	if defender == null:
		return
	var chill := Chill.new()
	chill.set_level(2.0)
	defender.add_buff(chill)

func description() -> String:
	return "Attacks chill enemies (%s turns left)." % disp_turns(time_left)
