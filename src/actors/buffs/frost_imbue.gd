class_name FrostImbue
extends Buff
## FrostImbue: imbues attacks with frost, matching upstream `FrostImbue.java`
## (Elixir of Icy Touch; Warden icecap trample grants 30% duration).
## Duration: 50 turns. On proc (upstream `Char.attack` after damage): applies
## 3 turns of Chill to the target. Grants immunity to Chill and Frozen while
## active and strips any existing Chill/Frozen on attach.

const BASE_DURATION: float = 50.0

func _init() -> void:
	buff_id = "FrostImbue"
	buff_name = "Frost Imbue"
	buff_type = BuffType.POSITIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.4, 0.7, 1.0)

## Upstream `immunities.add(Frost/Chill)`; port Frozen stands in for Frost.
func immunities() -> Array:
	return ["Chill", "Frozen"]

func on_attach() -> void:
	# Upstream attachTo: Buff.detach(target, Frost/Chill.class).
	if target != null and target.has_method("remove_buff_by_id"):
		target.remove_buff_by_id("Chill")
		target.remove_buff_by_id("Frozen")
	if MessageLog and target:
		MessageLog.add_positive("%s's attacks are imbued with frost!" % target.name)

## Called after the owner deals attack damage (upstream `FrostImbue.proc`):
## applies 3 turns of Chill to the defender.
func proc(defender: Node) -> void:
	if defender == null or not defender.get("is_alive"):
		return
	if defender.has_method("add_buff"):
		var chill := Chill.new()
		chill.set_level(3.0)
		defender.add_buff(chill)

func description() -> String:
	return "Attacks chill enemies for 3 turns (%s turns left)." % disp_turns(time_left)
