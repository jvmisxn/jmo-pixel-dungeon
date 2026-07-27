class_name GrimTracker
extends Buff
## Grim enchant hit tracker (upstream Grim.GrimTracker).
## Attached to the defender by the Grim proc so Char.take_damage can roll the
## deferred execute against the true post-hit HP. Carries the proc's max
## chance (50% + 5%/level, scaled by the proc-chance multiplier). Upstream
## detaches itself on its next act(); here it self-removes on the next turn
## tick and is never saved.

## Upstream GrimTracker.maxChance, set by Grim.proc before damage lands.
var max_chance: float = 0.0

func _init() -> void:
	buff_id = "GrimTracker"
	buff_name = "Grim Tracker"
	buff_type = BuffType.NEUTRAL
	duration = -1
	show_in_ui = false

func on_turn() -> void:
	if target:
		target.remove_buff(self)

func is_persistent() -> bool:
	return false
