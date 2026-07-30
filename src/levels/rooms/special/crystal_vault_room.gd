class_name CrystalVaultRoom
extends Room
## Upstream CrystalVaultRoom.java: fixed 7x7 vault behind an iron-LOCKED door.
## Interior ring is EMPTY_SP with an EMPTY core. Two prizes from a shuffled
## wand/ring/artifact category list are dropped as CRYSTAL_CHEST heaps on
## opposite CIRCLE8 neighbours of the centre (never adjacent to the door),
## each on a PEDESTAL. 1/10 of the time the second chest is a CrystalMimic
## holding the prize instead. A CrystalKey and an IronKey are added to the
## level's pending spawn items and scatter elsewhere on the floor.

func _init() -> void:
	type = Type.SPECIAL

## Special rooms have a single entrance.
## Matches original SpecialRoom.maxConnections() = 1.
func max_connections(_direction: int = -1) -> int:
	return 1

## Upstream: fixed size to improve presentation and give crystal mimics space.
func min_width() -> int:
	return 7

func min_height() -> int:
	return 7

func max_width() -> int:
	return 7

func max_height() -> int:
	return 7

func paint(level: Level) -> void:
	Painter.fill_room(level, self, ConstantsData.Terrain.WALL)
	Painter.fill_interior(level, self, ConstantsData.Terrain.EMPTY_SP)

	# Upstream Painter.fill(level, this, 2, EMPTY): inner core past the ring.
	for y: int in range(top + 2, bottom - 1):
		for x: int in range(left + 2, right - 1):
			level.set_terrain(y * ConstantsData.WIDTH + x, ConstantsData.Terrain.EMPTY)

	var door_pos: int = -1
	for other: Variant in connected:
		var pos: int = connected[other]
		if pos >= 0:
			door_pos = pos
			level.set_terrain(pos, ConstantsData.Terrain.LOCKED_DOOR)

	var c: int = center()
	var cats: Array[String] = ["wand", "ring", "artifact"]
	cats.shuffle()
	var prize_1: Item = _prize(cats[0])
	var prize_2: Item = _prize(cats[1])

	# Opposite CIRCLE8 neighbours of the centre, neither adjacent to the door.
	var pos_1: int = -1
	var pos_2: int = -1
	var guard: int = 0
	while guard < 100:
		guard += 1
		var idx: int = randi_range(0, ConstantsData.DIRS_8.size() - 1)
		pos_1 = c + ConstantsData.DIRS_8[idx]
		pos_2 = c + ConstantsData.DIRS_8[(idx + 4) % ConstantsData.DIRS_8.size()]
		if door_pos < 0:
			break
		if not _cells_adjacent(pos_1, door_pos) and not _cells_adjacent(pos_2, door_pos):
			break

	level.drop_item(pos_1, prize_1, "crystal_chest")
	# Upstream: base 1/10 chance the second chest is a CrystalMimic
	# (trinket multipliers not ported).
	var mimic_spawned: bool = false
	if randi_range(0, 9) == 0:
		mimic_spawned = _spawn_crystal_mimic(level, pos_2, prize_2)
	if not mimic_spawned:
		level.drop_item(pos_2, prize_2, "crystal_chest")
	level.set_terrain(pos_1, ConstantsData.Terrain.PEDESTAL)
	level.set_terrain(pos_2, ConstantsData.Terrain.PEDESTAL)

	# Upstream addItemToSpawn: keys land elsewhere on the floor.
	level.items_to_spawn.append(Key.create("crystal_key"))
	level.items_to_spawn.append(Key.create("iron_key"))

	painted = true

## Upstream prize(): random item of the category, re-rolled while null.
func _prize(category: String) -> Item:
	var item: Item = null
	var guard: int = 0
	while item == null and guard < 10:
		guard += 1
		match category:
			"wand":
				item = Generator.random_wand()
			"ring":
				item = Generator.random_ring()
			_:
				item = Generator.random_artifact()
	return item

## Upstream Mimic.spawnAt(pos, CrystalMimic.class, prize).
func _spawn_crystal_mimic(level: Level, pos: int, prize: Item) -> bool:
	var mimic: Mimic = MobFactory.create_mob("crystal_mimic") as Mimic
	if mimic == null:
		return false
	mimic.pos = pos
	mimic.level = level
	mimic.scale_to_depth(level.depth)
	if prize != null:
		mimic.stored_items.append(prize)
	mimic.generate_prize(level.depth)
	level.add_mob(mimic)
	return true

## Chebyshev adjacency (upstream Level.adjacent), including equality.
func _cells_adjacent(a: int, b: int) -> bool:
	var ax: int = a % ConstantsData.WIDTH
	var ay: int = a / ConstantsData.WIDTH
	var bx: int = b % ConstantsData.WIDTH
	var by: int = b / ConstantsData.WIDTH
	return abs(ax - bx) <= 1 and abs(ay - by) <= 1
