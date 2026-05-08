class_name Rotberry
extends Plant
## Quest plant used in the Wandmaker quest. When activated, it simply
## marks itself as collected. Does not apply any buff/debuff.

func _init() -> void:
	plant_id = "Rotberry"
	plant_name = "Rotberry"

func _do_effect(char: Variant, _level: Variant) -> void:
	if char == null:
		return

	# Mark quest flag via GameManager
	if GameManager:
		GameManager.set_quest_flag("rotberry_collected", true)

	if MessageLog:
		if char.get("is_hero"):
			MessageLog.add_positive("You uproot the rotberry. " +
				"Its stench is overwhelming.")
		else:
			MessageLog.add("The rotberry withers away.")

	if EventBus:
		EventBus.quest_updated.emit("rotberry", "collected")
