class_name Firebloom
extends Plant
## Creates fire at the cell, applying the Burning debuff to any character
## that triggered it. Also burns adjacent high grass.

func _init() -> void:
	plant_id = "Firebloom"
	plant_name = "Firebloom"

func _do_effect(char: Variant, level: Variant) -> void:
	# Apply Burning to the character
	if char != null and char.has_method("add_buff"):
		var burn: Burning = Burning.new()
		char.add_buff(burn)
		if MessageLog:
			if char.get("is_hero"):
				MessageLog.add_negative("The firebloom explodes in a burst of flame!")
			else:
				MessageLog.add("The firebloom ignites the %s!" % str(char.get("name")))

	# Burn adjacent high grass
	if level != null and level.has_method("set_terrain"):
		for dir: int in ConstantsData.DIRS_8:
			var adj: int = pos + dir
			# Column-safe adjacency: reject cells that wrap across a map edge
			# (e.g. a West step from column 0 lands on the previous row's last
			# column), which would otherwise ignite grass across the map.
			if adj >= 0 and adj < Level.LEN and absi(adj % Level.W - pos % Level.W) <= 1:
				var t: int = level.terrain_at(adj)
				if t == ConstantsData.Terrain.HIGH_GRASS:
					level.set_terrain(adj, ConstantsData.Terrain.EMBERS)
				elif t == ConstantsData.Terrain.BARRICADE:
					level.set_terrain(adj, ConstantsData.Terrain.EMBERS)
