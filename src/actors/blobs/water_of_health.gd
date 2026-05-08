class_name WaterOfHealth
extends Blob
## Healing water from wells. Heals characters standing in it.

func _init() -> void:
	super._init()
	blob_id = "water_of_health"
	blob_name = "Water of Health"
	spread_rate = 0.0  # Doesn't spread
	decay_rate = 0.05

func affect_char(ch: Char) -> void:
	if ch.hp < ch.hp_max:
		ch.heal(3)
		# Remove debuffs
		if ch.has_buff("Poison"):
			ch.remove_buff_by_id("Poison")
		if ch.has_buff("Burning"):
			ch.remove_buff_by_id("Burning")
		if ch.has_buff("Bleeding"):
			ch.remove_buff_by_id("Bleeding")
