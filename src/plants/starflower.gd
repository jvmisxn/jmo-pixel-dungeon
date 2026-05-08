class_name Starflower
extends Plant
## Rare plant that grants a large XP boost when stepped on.
## Only benefits heroes (mobs gain nothing).

const XP_BOOST: int = 50

func _init() -> void:
	plant_id = "Starflower"
	plant_name = "Starflower"

func _do_effect(char: Variant, level: Variant) -> void:
	if char == null:
		return

	if char.get("is_hero") and char.has_method("earn_xp"):
		# Scale XP with dungeon depth
		var depth: int = 1
		if level and level.get("depth") != null:
			depth = level.depth
		var xp_amount: int = XP_BOOST + depth * 5
		char.earn_xp(xp_amount)
		if MessageLog:
			MessageLog.add_positive("The starflower releases a " +
				"brilliant flash! (+%d XP)" % xp_amount)
	else:
		if MessageLog:
			MessageLog.add("The starflower releases a brilliant flash!")
