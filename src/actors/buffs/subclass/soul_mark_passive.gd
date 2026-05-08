class_name SoulMarkPassive
extends Buff
## Warlock subclass passive. Wand attacks apply Soul Mark.
## Killing a Soul Marked enemy with melee heals the Warlock and satisfies hunger.

func _init() -> void:
	buff_id = "SoulMarkPassive"
	buff_name = "Soul Mark"
	duration = -1.0
	icon_color = Color(0.5, 0.1, 0.7)

## Apply soul mark to an enemy hit by a wand.
func apply_soul_mark(enemy: Node) -> void:
	if enemy == null or not enemy.is_alive:
		return
	var mark: SoulMark = SoulMark.new()
	enemy.add_buff(mark)

func description() -> String:
	return "Soul Mark (wand hits mark enemies)"
