class_name ExplosiveTrap
extends Trap
## Explodes dealing area damage like a bomb.

func _init() -> void:
	trap_name = "explosive trap"
	color = Color(1.0, 0.2, 0.2)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("The trap explodes!")

	# Explosion radius — damage center and all 8 adjacent cells
	var explosion_cells: Array[int] = [pos]
	for dir: int in ConstantsData.DIRS_8:
		var adj: int = pos + dir
		if level.adjacent(pos, adj):
			explosion_cells.append(adj)

	var base_damage: int = 10 + level.depth * 2

	for cell: int in explosion_cells:
		# Damage mobs in the area
		var mob: Variant = level.mob_at(cell)
		if mob != null and mob.has_method("take_damage"):
			# Reduce damage for cells further from center
			var damage: int = base_damage if cell == pos else int(base_damage * 0.6)
			mob.take_damage(damage, "explosive trap")

		# Destroy terrain
		var t: int = level.terrain_at(cell)
		if t == ConstantsData.Terrain.BARRICADE or t == ConstantsData.Terrain.HIGH_GRASS:
			level.set_terrain(cell, ConstantsData.Terrain.EMBERS)
		elif t == ConstantsData.Terrain.GRASS:
			level.set_terrain(cell, ConstantsData.Terrain.EMBERS)
		elif t == ConstantsData.Terrain.DOOR:
			level.set_terrain(cell, ConstantsData.Terrain.OPEN_DOOR)

	# Also damage the triggerer (may be different from mob_at)
	if triggerer != null and triggerer.has_method("take_damage"):
		triggerer.take_damage(base_damage, "explosive trap")
