class_name LevelFactory
extends RefCounted
## Creates the appropriate Level subclass for a given depth.
## Mirrors Shattered PD's Dungeon.newLevel().

static func create_for_depth(p_depth: int) -> Level:
	var level: Level

	match p_depth:
		# Sewer boss
		5:
			level = SewerBossLevel.new()
		# Prison boss
		10:
			level = PrisonBossLevel.new()
		# Caves boss
		15:
			level = CavesBossLevel.new()
		# City boss
		20:
			level = CityBossLevel.new()
		# Halls boss
		25:
			level = HallsBossLevel.new()
		# Amulet level
		26:
			level = LastLevel.new()
		_:
			# Regular levels by region
			var region: int = ConstantsData.region_for_depth(p_depth)
			match region:
				ConstantsData.Region.SEWERS:
					level = SewerLevel.new()
				ConstantsData.Region.PRISON:
					level = PrisonLevel.new()
				ConstantsData.Region.CAVES:
					level = CavesLevel.new()
				ConstantsData.Region.CITY:
					level = CityLevel.new()
				ConstantsData.Region.HALLS:
					level = HallsLevel.new()
				_:
					level = RegularLevel.new()

	var success: bool = level.create(p_depth)
	if not success:
		push_warning("LevelFactory: Level generation failed for depth %d, using fallback." % p_depth)
		# Fallback: create a simple level with a single room
		level._init_arrays()
		level.depth = p_depth
		# Carve a room in the center of the map
		var cx: int = ConstantsData.WIDTH / 2
		var cy: int = ConstantsData.HEIGHT / 2
		for dy: int in range(-4, 5):
			for dx: int in range(-4, 5):
				var px: int = cx + dx
				var py: int = cy + dy
				if px > 0 and px < ConstantsData.WIDTH - 1 and py > 0 and py < ConstantsData.HEIGHT - 1:
					var pos: int = py * ConstantsData.WIDTH + px
					if absi(dx) == 4 or absi(dy) == 4:
						level.set_terrain(pos, ConstantsData.Terrain.WALL)
					else:
						level.set_terrain(pos, ConstantsData.Terrain.EMPTY)
		# Set entrance and exit
		level.entrance = cy * ConstantsData.WIDTH + cx
		level.set_terrain(level.entrance, ConstantsData.Terrain.ENTRANCE)
		level.exit_pos = (cy - 2) * ConstantsData.WIDTH + cx
		level.set_terrain(level.exit_pos, ConstantsData.Terrain.EXIT)
		level.build_flag_maps()
	return level
