class_name FireImbue
extends Buff
## FireImbue: imbues attacks with fire, applying Burning to targets.
## Original (FireImbue.java): from Potion of Liquid Flame / exotic variant.
## Duration: 30 turns. On proc: applies Burning for 1 turn to the target.
## Grants immunity to Burning while active.

const BASE_DURATION: float = 30.0

func _init() -> void:
	buff_id = "FireImbue"
	buff_name = "Fire Imbue"
	buff_type = BuffType.POSITIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(1.0, 0.5, 0.0)

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_positive("%s's attacks are imbued with fire!" % target.name)

## Called after the owner deals melee damage. Applies Burning to the defender.
func proc(defender: Node) -> void:
	if defender == null:
		return
	var burn := Burning.new()
	burn.reignite(1.0)
	defender.add_buff(burn)

func description() -> String:
	return "Attacks set enemies on fire (%s turns left)." % disp_turns(time_left)
