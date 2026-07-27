class_name KineticTracker
extends Buff
## Kinetic enchant hit tracker (upstream Kinetic.KineticTracker).
## Attached to the attacker by the Kinetic proc so Char.take_damage can see
## the true final damage of the hit; records how much of that hit was recycled
## conserved damage so overkill storage doesn't re-bank it. Upstream detaches
## itself on its next act(); here it self-removes on the next turn tick and is
## never saved.

## Conserved bonus that was folded into this hit's damage (upstream
## KineticTracker.conservedDamage); subtracted from overkill before banking.
var conserved_damage: int = 0

func _init() -> void:
	buff_id = "KineticTracker"
	buff_name = "Kinetic Tracker"
	buff_type = BuffType.NEUTRAL
	duration = -1
	show_in_ui = false

func on_turn() -> void:
	if target:
		target.remove_buff(self)

func is_persistent() -> bool:
	return false
