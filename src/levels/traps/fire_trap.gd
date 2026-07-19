class_name FireTrap
extends Trap
## Sets the triggering character on fire and spreads fire blobs.

func _init() -> void:
	trap_name = "fire trap"
	color = Color(1.0, 0.4, 0.1)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("Flames erupt from the floor!")

	# Apply burning buff to the triggerer
	if triggerer != null and triggerer.has_method("add_buff"):
		var burn: Burning = Burning.new()
		burn.left = Burning.DURATION
		triggerer.add_buff(burn)

	# Deal fire damage
	if triggerer != null and triggerer.has_method("take_damage"):
		var damage: int = 4 + level.depth
		triggerer.take_damage(damage, "fire trap")

	# Spread fire to adjacent cells
	for dir: int in ConstantsData.DIRS_4:
		var adj: int = pos + dir
		if adj >= 0 and adj < Level.LEN:
			var t: int = level.terrain_at(adj)
			if t == ConstantsData.Terrain.GRASS or t == ConstantsData.Terrain.HIGH_GRASS:
				level.set_terrain(adj, ConstantsData.Terrain.EMBERS)
			elif t == ConstantsData.Terrain.BARRICADE:
				level.set_terrain(adj, ConstantsData.Terrain.EMBERS)
