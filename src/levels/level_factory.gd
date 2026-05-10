class_name LevelFactory
extends RefCounted
## Creates the appropriate Level subclass for a given depth.
## Mirrors Shattered PD's Dungeon.newLevel().

const MAX_GENERATION_ATTEMPTS: int = 6

static func create_for_depth(p_depth: int) -> Level:
	var level: Level = null
	var success: bool = false
	for _attempt: int in range(MAX_GENERATION_ATTEMPTS):
		level = instantiate_for_depth(p_depth)
		success = level.create(p_depth)
		if success:
			break
	if not success:
		level = instantiate_for_depth(p_depth)
		push_warning("LevelFactory: Level generation failed for depth %d after %d attempts, using fallback." % [p_depth, MAX_GENERATION_ATTEMPTS])
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

static func instantiate_for_depth(p_depth: int) -> Level:
	match p_depth:
		5:
			return SewerBossLevel.new()
		10:
			return PrisonBossLevel.new()
		15:
			return CavesBossLevel.new()
		20:
			return CityBossLevel.new()
		25:
			return HallsBossLevel.new()
		26:
			return LastLevel.new()
		_:
			var region: int = ConstantsData.region_for_depth(p_depth)
			match region:
				ConstantsData.Region.SEWERS:
					return SewerLevel.new()
				ConstantsData.Region.PRISON:
					return PrisonLevel.new()
				ConstantsData.Region.CAVES:
					return CavesLevel.new()
				ConstantsData.Region.CITY:
					return CityLevel.new()
				ConstantsData.Region.HALLS:
					return HallsLevel.new()
	return RegularLevel.new()
