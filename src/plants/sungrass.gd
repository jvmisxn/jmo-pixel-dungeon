class_name Sungrass
extends Plant
## Heals the hero over time when stepped on. Applies a healing buff that
## restores HP each turn for several turns.

func _init() -> void:
	plant_id = "Sungrass"
	plant_name = "Sungrass"

func _do_effect(char: Variant, _level: Variant) -> void:
	if char == null:
		return
	if char.has_method("add_buff"):
		var buff: SungrassHealBuff = SungrassHealBuff.new()
		char.add_buff(buff)
	if MessageLog:
		if char.get("is_hero"):
			MessageLog.add_positive("Golden light surrounds you, slowly healing your wounds.")
		else:
			MessageLog.add("The sungrass releases a golden glow.")
