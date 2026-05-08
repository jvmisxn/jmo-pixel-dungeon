class_name HallsBossLevel
extends Level
## Halls boss level (depth 25) — Yog-Dzewa fight.
## A fiery hellscape arena with lava (chasm) rings.

func _build() -> bool:
	_init_arrays()
	var W_: int = ConstantsData.WIDTH

	@warning_ignore("integer_division")
	var cx: int = W_ / 2
	var cy: int = 16  # Center of arena

	# Create a circular arena
	var radius: int = 11
	for y: int in range(cy - radius, cy + radius + 1):
		for x: int in range(cx - radius, cx + radius + 1):
			var dx: float = float(x - cx)
			var dy: float = float(y - cy)
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist <= float(radius):
				if dist > float(radius) - 2.0:
					# Lava ring at the edge
					set_terrain(y * W_ + x, ConstantsData.Terrain.CHASM)
				else:
					set_terrain(y * W_ + x, ConstantsData.Terrain.EMPTY)

	# Inner lava ring
	var inner_radius: int = 5
	for y: int in range(cy - inner_radius, cy + inner_radius + 1):
		for x: int in range(cx - inner_radius, cx + inner_radius + 1):
			var dx: float = float(x - cx)
			var dy: float = float(y - cy)
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist <= float(inner_radius) and dist > float(inner_radius) - 1.5:
				set_terrain(y * W_ + x, ConstantsData.Terrain.CHASM)

	# Bridges across the lava
	# North bridge
	for y: int in range(cy - radius, cy - inner_radius + 2):
		set_terrain(y * W_ + cx, ConstantsData.Terrain.EMPTY)
	# South bridge
	for y: int in range(cy + inner_radius - 1, cy + radius + 1):
		set_terrain(y * W_ + cx, ConstantsData.Terrain.EMPTY)
	# East bridge
	for x: int in range(cx + inner_radius - 1, cx + radius + 1):
		set_terrain(cy * W_ + x, ConstantsData.Terrain.EMPTY)
	# West bridge
	for x: int in range(cx - radius, cx - inner_radius + 2):
		set_terrain(cy * W_ + x, ConstantsData.Terrain.EMPTY)

	# Embers scattered in the arena
	for y: int in range(cy - radius + 2, cy + radius - 1):
		for x: int in range(cx - radius + 2, cx + radius - 1):
			var pos: int = y * W_ + x
			if terrain_at(pos) == ConstantsData.Terrain.EMPTY and randf() < 0.15:
				set_terrain(pos, ConstantsData.Terrain.EMBERS)

	# Center pedestal for Yog
	set_terrain(cy * W_ + cx, ConstantsData.Terrain.PEDESTAL)

	# Entrance corridor from south
	entrance = (cy + radius + 3) * W_ + cx
	set_terrain(entrance, ConstantsData.Terrain.ENTRANCE)
	for y: int in range(cy + radius, cy + radius + 4):
		set_terrain(y * W_ + cx, ConstantsData.Terrain.EMPTY)

	# Exit at north (leads to depth 26)
	exit_pos = (cy - radius - 2) * W_ + cx
	set_terrain(exit_pos, ConstantsData.Terrain.EXIT)
	for y: int in range(cy - radius - 2, cy - radius + 1):
		set_terrain(y * W_ + cx, ConstantsData.Terrain.EMPTY)
	set_terrain((cy - radius) * W_ + cx, ConstantsData.Terrain.LOCKED_DOOR)

	build_flag_maps()

	# Spawn Yog-Dzewa boss on the center pedestal
	var boss: Mob = MobFactory.create_boss(25)
	boss.pos = cy * W_ + cx
	add_mob(boss)

	return true
