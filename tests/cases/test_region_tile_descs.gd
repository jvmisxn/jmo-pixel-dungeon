extends RefCounted
## Region-specific examine tile names/descriptions parity with upstream
## SewerLevel/PrisonLevel/CavesLevel/CityLevel/HallsLevel tileName()/tileDesc():
## water renames per region, caves ladders and city ramps replace stairs text,
## halls statues become skull pillars, and non-overridden tiles keep base text.


func run(t: Object) -> void:
	var water: int = ConstantsData.Terrain.WATER
	var statue: int = ConstantsData.Terrain.STATUE
	var bookshelf: int = ConstantsData.Terrain.BOOKSHELF
	var entrance: int = ConstantsData.Terrain.ENTRANCE
	var exit_t: int = ConstantsData.Terrain.EXIT

	# --- Per-region water names (every region overrides WATER) ---
	t.check(CellExaminer.terrain_name(water, 1) == "murky water",
		"sewers water is murky water")
	t.check(CellExaminer.terrain_name(water, 8) == "dark cold water",
		"prison water is dark cold water")
	t.check(CellExaminer.terrain_name(water, 12) == "freezing cold water",
		"caves water is freezing cold water")
	t.check(CellExaminer.terrain_name(water, 17) == "suspiciously colored water",
		"city water is suspiciously colored water")
	t.check(CellExaminer.terrain_name(water, 22) == "cold lava",
		"halls water is cold lava")

	# --- Region grass/statue renames ---
	t.check(CellExaminer.terrain_name(ConstantsData.Terrain.GRASS, 13) == "fluorescent moss",
		"caves grass is fluorescent moss")
	t.check(
		CellExaminer.terrain_name(ConstantsData.Terrain.HIGH_GRASS, 13)
			== "fluorescent mushrooms",
		"caves high grass is fluorescent mushrooms")
	t.check(CellExaminer.terrain_name(ConstantsData.Terrain.GRASS, 24) == "embermoss",
		"halls grass is embermoss")
	t.check(CellExaminer.terrain_name(statue, 24) == "pillar",
		"halls statues are pillars")
	t.check(CellExaminer.terrain_name(ConstantsData.Terrain.STATUE_SP, 24) == "pillar",
		"halls special statues are pillars too")
	t.check(CellExaminer.terrain_name(statue, 3) == "statue",
		"sewers statues keep the base name")

	# --- Furrowed grass never picks up the high-grass rename ---
	t.check(
		CellExaminer.terrain_name(ConstantsData.Terrain.FURROWED_GRASS, 13)
			== "furrowed grass",
		"furrowed grass keeps its base name in the caves")

	# --- Region stair/ladder/ramp descriptions ---
	t.check(CellExaminer.terrain_desc(entrance, 12).begins_with("The ladder leads up"),
		"caves entrance describes a ladder up")
	t.check(CellExaminer.terrain_desc(exit_t, 12).begins_with("The ladder leads down"),
		"caves exit describes a ladder down")
	t.check(CellExaminer.terrain_desc(entrance, 18).begins_with("A ramp leads up"),
		"city entrance describes a ramp up")
	t.check(CellExaminer.terrain_desc(exit_t, 18).begins_with("A ramp leads down"),
		"city exit describes a ramp down")
	t.check(CellExaminer.terrain_desc(entrance, 2).begins_with("The stairs lead up"),
		"sewers entrance keeps the base stairs text")

	# --- Region bookshelf/statue/water descriptions ---
	t.check(CellExaminer.terrain_desc(bookshelf, 4).contains("cheap useless books"),
		"sewers bookshelves hold cheap useless books")
	t.check(CellExaminer.terrain_desc(bookshelf, 7).contains("prison library"),
		"prison bookshelves reference the prison library")
	t.check(CellExaminer.terrain_desc(bookshelf, 15).contains("bookshelf in a cave"),
		"caves bookshelves question their own existence")
	t.check(CellExaminer.terrain_desc(bookshelf, 19).contains("different disciplines"),
		"city bookshelves hold disciplined rows of books")
	t.check(CellExaminer.terrain_desc(bookshelf, 25).contains("ancient languages"),
		"halls bookshelves smoulder in ancient languages")
	t.check(CellExaminer.terrain_desc(statue, 20).contains("heroic stance"),
		"city statues depict a heroic dwarf")
	t.check(CellExaminer.terrain_desc(statue, 26).contains("humanoid skulls"),
		"halls pillars are made of skulls")
	t.check(CellExaminer.terrain_desc(water, 23).contains("cold and probably safe"),
		"halls cold lava reassures it is safe to touch")
	t.check(
		CellExaminer.terrain_desc(water, 2)
			== "In case of burning, step into the water to extinguish the fire.",
		"sewers water keeps the base extinguish text")

	# --- describe_cell threads level depth into the override lookup ---
	var level := Level.new()
	level.depth = 22
	level._init_arrays()
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.build_flag_maps()
	var cell: int = ConstantsData.xy_to_pos(5, 5)
	level.map[cell] = ConstantsData.Terrain.WATER
	level.visited[cell] = true
	var info: Dictionary = CellExaminer.describe_cell(level, null, cell)
	t.check(str(info.get("kind", "")) == "terrain", "known water cell reports terrain")
	t.check(str(info.get("title", "")) == "cold lava",
		"describe_cell uses the level depth for region tile names")
