extends RefCounted
## Examine-mode classification parity with Shattered PD GameScene.examineCell():
## unknown cells give no info, visible chars win over heaps/traps/terrain,
## hidden traps stay disguised as plain floor, and known-but-unseen cells fall
## back to map knowledge. Also smoke-tests the info window construction.

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 1
	level._init_arrays()
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func run(t: Object) -> void:
	var level: Level = _make_level()

	var unseen: int = ConstantsData.xy_to_pos(20, 20)
	var info: Dictionary = CellExaminer.describe_cell(level, null, unseen)
	t.check(str(info["kind"]) == "unknown",
		"an unvisited, unmapped cell reports unknown")

	t.check(str(CellExaminer.describe_cell(level, null, -1)["kind"]) == "none",
		"an invalid cell reports none")

	# --- Visible mob beats everything else on the cell ---
	var mob_pos: int = ConstantsData.xy_to_pos(5, 5)
	level.visible[mob_pos] = true
	level.visited[mob_pos] = true
	var rat: Variant = MobFactory.create_mob("rat")
	t.check(rat != null, "factory creates a rat for the examine test")
	rat.pos = mob_pos
	level.mobs.append(rat)
	level.drop_item(mob_pos, Generator.create_item("dewdrop"))
	info = CellExaminer.describe_cell(level, null, mob_pos)
	t.check(str(info["kind"]) == "mob", "a visible mob wins over a heap on the same cell")
	t.check(info["char"] == rat, "the mob result carries the mob instance")

	# --- Same cell out of FOV but visited: falls back to map knowledge ---
	level.visible[mob_pos] = false
	info = CellExaminer.describe_cell(level, null, mob_pos)
	t.check(str(info["kind"]) == "heap",
		"out-of-FOV chars are skipped; the known heap is reported instead")

	# --- Hero on a visible cell reports hero ---
	var hero_pos: int = ConstantsData.xy_to_pos(6, 6)
	level.visible[hero_pos] = true
	level.visited[hero_pos] = true
	var hero := Hero.new()
	hero.pos = hero_pos
	level.mobs.append(hero)
	info = CellExaminer.describe_cell(level, hero, hero_pos)
	t.check(str(info["kind"]) == "hero", "examining your own cell reports hero")
	level.mobs.erase(hero)
	hero.free()

	# --- Visible trap vs hidden trap ---
	var trap_pos: int = ConstantsData.xy_to_pos(8, 8)
	level.visited[trap_pos] = true
	var trap := Trap.new()
	trap.trap_name = "fire trap"
	trap.visible = true
	level.place_trap(trap_pos, trap)
	level.map[trap_pos] = ConstantsData.Terrain.TRAP
	info = CellExaminer.describe_cell(level, null, trap_pos)
	t.check(str(info["kind"]) == "trap", "a revealed trap is reported as a trap")

	var secret_pos: int = ConstantsData.xy_to_pos(9, 9)
	level.visited[secret_pos] = true
	var secret := Trap.new()
	secret.visible = false
	level.place_trap(secret_pos, secret)
	level.map[secret_pos] = ConstantsData.Terrain.SECRET_TRAP
	info = CellExaminer.describe_cell(level, null, secret_pos)
	t.check(str(info["kind"]) == "terrain", "a hidden trap is not revealed by examining")
	t.check(str(info["title"]) == "floor", "a hidden trap masquerades as plain floor")

	# --- Plant ---
	var plant_pos: int = ConstantsData.xy_to_pos(10, 10)
	level.visited[plant_pos] = true
	var plant := Plant.new()
	plant.plant_name = "firebloom"
	plant.pos = plant_pos
	level.plants[plant_pos] = plant
	info = CellExaminer.describe_cell(level, null, plant_pos)
	t.check(str(info["kind"]) == "plant", "a known plant is reported as a plant")

	# --- Terrain knowledge on mapped-only cells ---
	var mapped_pos: int = ConstantsData.xy_to_pos(12, 12)
	level.mapped[mapped_pos] = true
	level.map[mapped_pos] = ConstantsData.Terrain.WATER
	info = CellExaminer.describe_cell(level, null, mapped_pos)
	t.check(str(info["kind"]) == "terrain" and str(info["title"]) == "murky water",
		"a mapped-only cell reports its region terrain name (sewers water)")

	t.check(not CellExaminer.terrain_name(ConstantsData.Terrain.BOOKSHELF).is_empty()
		and not CellExaminer.terrain_desc(ConstantsData.Terrain.BOOKSHELF).is_empty(),
		"terrain name/desc tables cover furniture tiles")

	# --- Window smoke tests (construction only, no HUD) ---
	var wnd_mob: WndInfoMob = WndInfoMob.new()
	wnd_mob.setup(rat)
	t.check(wnd_mob.window_title.to_lower().contains("rat"),
		"WndInfoMob titles itself after the mob")
	var mob_content: Control = wnd_mob._build_content()
	t.check(mob_content != null and mob_content.get_child_count() >= 2,
		"WndInfoMob builds HP plus description content")
	mob_content.free()
	wnd_mob.free()

	var wnd_cell: WndInfoCell = WndInfoCell.new()
	wnd_cell.setup("Water", CellExaminer.terrain_desc(ConstantsData.Terrain.WATER))
	var cell_content: Control = wnd_cell._build_content()
	t.check(cell_content is Label and not (cell_content as Label).text.is_empty(),
		"WndInfoCell builds its description label")
	cell_content.free()
	wnd_cell.free()

	# --- Cleanup ---
	level.mobs.clear()
	if rat is Node:
		rat.free()
