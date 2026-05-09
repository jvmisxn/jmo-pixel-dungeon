class_name StandardRoom
extends Room
## Standard room — the most common room type in regular levels.
## Has variable sizes and can be painted with different terrain themes.

enum SizeCategory { SMALL, NORMAL, LARGE, GIANT }

var size_cat: SizeCategory = SizeCategory.NORMAL

func _init() -> void:
	type = Type.STANDARD

# ---------------------------------------------------------------------------
# Size Requirements
# ---------------------------------------------------------------------------

func min_width() -> int:
	match size_cat:
		SizeCategory.SMALL: return 4
		SizeCategory.NORMAL: return 5
		SizeCategory.LARGE: return 7
		SizeCategory.GIANT: return 9
	return 5

func min_height() -> int:
	match size_cat:
		SizeCategory.SMALL: return 4
		SizeCategory.NORMAL: return 5
		SizeCategory.LARGE: return 7
		SizeCategory.GIANT: return 9
	return 5

func max_width() -> int:
	match size_cat:
		SizeCategory.SMALL: return 6
		SizeCategory.NORMAL: return 8
		SizeCategory.LARGE: return 10
		SizeCategory.GIANT: return 14
	return 8

func max_height() -> int:
	match size_cat:
		SizeCategory.SMALL: return 6
		SizeCategory.NORMAL: return 8
		SizeCategory.LARGE: return 10
		SizeCategory.GIANT: return 14
	return 8

# ---------------------------------------------------------------------------
# Painting
# ---------------------------------------------------------------------------

func paint(level: Level) -> void:
	# Fill the room with walls first, then empty interior
	for pos: int in all_cells():
		level.set_terrain(pos, ConstantsData.Terrain.WALL)

	var interior: Array[int] = interior_cells()

	# Determine floor terrain based on level feeling or random variation
	var floor_terrain: int = _pick_floor_terrain(level)
	for pos: int in interior:
		level.set_terrain(pos, floor_terrain)

	# Add some decoration variation
	_decorate_interior(level, interior)

	# Place doors from connections
	for other: Variant in connected:
		var door_pos: int = connected[other]
		if door_pos >= 0:
			level.set_terrain(door_pos, ConstantsData.Terrain.DOOR)

	painted = true

func _pick_floor_terrain(level: Level) -> int:
	match level.feeling:
		Level.Feeling.CHASM:
			return ConstantsData.Terrain.EMPTY
		_:
			return ConstantsData.Terrain.EMPTY

func _decorate_interior(level: Level, interior: Array[int]) -> void:
	if interior.is_empty():
		return

	match level.feeling:
		Level.Feeling.GRASS:
			for pos: int in interior:
				var roll: float = randf()
				if roll < 0.22:
					level.set_terrain(pos, ConstantsData.Terrain.GRASS)
				elif roll < 0.34:
					level.set_terrain(pos, ConstantsData.Terrain.HIGH_GRASS)
				elif roll < 0.38:
					level.set_terrain(pos, ConstantsData.Terrain.FURROWED_GRASS)
		_:
			# Normal rooms should only pick up a little natural clutter.
			for pos: int in interior:
				if randf() < 0.035:
					level.set_terrain(pos, ConstantsData.Terrain.GRASS)

## Create a StandardRoom with a random size category weighted toward NORMAL.
static func create_random() -> StandardRoom:
	var room: StandardRoom = StandardRoom.new()
	var roll: float = randf()
	if roll < 0.5:
		room.size_cat = SizeCategory.NORMAL
	elif roll < 0.75:
		room.size_cat = SizeCategory.SMALL
	elif roll < 0.92:
		room.size_cat = SizeCategory.LARGE
	else:
		room.size_cat = SizeCategory.GIANT
	return room
