class_name BlazingTrap
extends Trap
## Sets the victim on fire and spreads fire to adjacent cells.

func _init() -> void:
	trap_name = "blazing trap"
	color = Color(1.0, 0.3, 0.0)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A blazing inferno erupts!")

	# Apply burning buff to the triggerer
	if triggerer != null and triggerer.has_method("add_buff"):
		var burn: Burning = Burning.new()
		burn.duration = 12.0
		burn.time_left = 12.0
		triggerer.add_buff(burn)

	# Deal initial fire damage
	if triggerer != null and triggerer.has_method("take_damage"):
		var damage: int = 4 + level.depth
		triggerer.take_damage(damage, "blazing trap")

	# Spread fire to all 8 adjacent cells
	for dir: int in ConstantsData.DIRS_8:
		var adj: int = pos + dir
		if level.adjacent(pos, adj):
			var t: int = level.terrain_at(adj)
			if t == ConstantsData.Terrain.GRASS or t == ConstantsData.Terrain.HIGH_GRASS:
				level.set_terrain(adj, ConstantsData.Terrain.EMBERS)
			elif t == ConstantsData.Terrain.BARRICADE:
				level.set_terrain(adj, ConstantsData.Terrain.EMBERS)
