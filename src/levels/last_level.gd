class_name LastLevel
extends Level
## Final level (depth 26) — Contains the Amulet of Yendor.
## A simple, small level with the amulet on a pedestal.

func _build() -> bool:
	_init_arrays()
	var W_: int = ConstantsData.WIDTH

	@warning_ignore("integer_division")
	var cx: int = W_ / 2
	@warning_ignore("integer_division")
	var cy: int = W_ / 2

	# Small circular chamber
	var radius: int = 5
	for y: int in range(cy - radius, cy + radius + 1):
		for x: int in range(cx - radius, cx + radius + 1):
			var dx: float = float(x - cx)
			var dy: float = float(y - cy)
			if sqrt(dx * dx + dy * dy) <= float(radius):
				set_terrain(y * W_ + x, ConstantsData.Terrain.EMPTY_SP)

	# Chasm ring around the chamber
	for y: int in range(cy - radius - 2, cy + radius + 3):
		for x: int in range(cx - radius - 2, cx + radius + 3):
			var dx: float = float(x - cx)
			var dy: float = float(y - cy)
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist > float(radius) and dist <= float(radius) + 2.0:
				set_terrain(y * W_ + x, ConstantsData.Terrain.CHASM)

	# Bridge from south
	for y: int in range(cy + radius - 1, cy + radius + 5):
		set_terrain(y * W_ + cx, ConstantsData.Terrain.EMPTY_SP)

	# Pedestal with Amulet at center
	set_terrain(cy * W_ + cx, ConstantsData.Terrain.PEDESTAL)

	# Entrance from bridge
	entrance = (cy + radius + 4) * W_ + cx
	set_terrain(entrance, ConstantsData.Terrain.ENTRANCE)

	# No exit — the amulet IS the exit (ascending back to surface)
	exit_pos = -1

	# Embers around the pedestal
	for dir: int in ConstantsData.DIRS_8:
		var pos: int = cy * W_ + cx + dir
		if terrain_at(pos) == ConstantsData.Terrain.EMPTY_SP:
			set_terrain(pos, ConstantsData.Terrain.EMBERS)

	build_flag_maps()

	# Place the Amulet of Yendor on the central pedestal
	var amulet: Item = Generator.create_item("amulet_of_yendor")
	if amulet:
		drop_item(cy * W_ + cx, amulet)

	return true
