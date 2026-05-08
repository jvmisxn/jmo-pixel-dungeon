class_name Earthroot
extends Plant
## Grants herbal armor buff that provides damage reduction. The armor
## absorbs a set amount of damage before expiring.

func _init() -> void:
	plant_id = "Earthroot"
	plant_name = "Earthroot"

func _do_effect(char: Variant, _level: Variant) -> void:
	if char == null:
		return
	if char.has_method("add_buff"):
		var buff: HerbalArmorBuff = HerbalArmorBuff.new()
		char.add_buff(buff)
	if MessageLog:
		if char.get("is_hero"):
			MessageLog.add_positive("Roots emerge and wrap around you protectively.")
		else:
			MessageLog.add("Roots wrap around the %s." % str(char.get("name")))
