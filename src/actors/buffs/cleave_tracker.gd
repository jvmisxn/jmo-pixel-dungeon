class_name CleaveTracker
extends Buff
## Duelist Cleave follow-up window. Original: Sword.CleaveTracker.
## Attached when a sword-family weapon ability kills its target; while
## active the next sword-family ability costs 0 charges. Upstream prolongs
## 4 turns (5 - 1 because the killing blow was instant).

const WINDOW: float = 4.0

func _init() -> void:
	buff_id = "CleaveTracker"
	buff_name = "Cleave"
	buff_type = BuffType.POSITIVE
	duration = WINDOW

func merge(_other: Node) -> void:
	time_left = WINDOW

func description() -> String:
	return "Your cleave felled its target. Your next weapon ability is free."
