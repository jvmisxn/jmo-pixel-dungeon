extends RefCounted
## Level.press_cell parity (upstream Level.pressCell): pressing a cell with
## physical force — wand bolts stopping on empty cells, falling objects —
## springs traps (hidden ones only on a hard press), tramples grass, triggers
## plants, and tears webs. Wand.zap presses the bolt's empty collision cell
## (upstream per-wand onZap pressCell calls, centralized in the port).

class _MarkerTrap extends Trap:
	var fired: bool = false
	func _init() -> void:
		trap_name = "marker trap"
	func _do_effect(_triggerer: Variant, _level: Level) -> void:
		fired = true

func run(t: Object) -> void:
	_test_press_springs_visible_trap(t)
	_test_secret_trap_hard_vs_soft(t)
	_test_press_tramples_grass(t)
	_test_press_triggers_plant(t)
	_test_hard_press_clears_web(t)
	_test_wand_zap_presses_empty_collision(t)

func _make_level() -> Level:
	var level := Level.new()
	for i: int in range(ConstantsData.LENGTH):
		level.set_terrain(i, ConstantsData.Terrain.EMPTY)
	level.entrance = 0
	level.exit_pos = ConstantsData.LENGTH - 1
	return level

func _place_marker_trap(level: Level, pos: int, terrain: int) -> _MarkerTrap:
	var trap := _MarkerTrap.new()
	trap.visible = terrain == ConstantsData.Terrain.TRAP
	level.place_trap(pos, trap)
	level.set_terrain(pos, terrain)
	return trap

func _test_press_springs_visible_trap(t: Object) -> void:
	var level := _make_level()
	var pos := ConstantsData.xy_to_pos(10, 10)
	var trap := _place_marker_trap(level, pos, ConstantsData.Terrain.TRAP)
	level.press_cell(pos)
	t.check(trap.fired, "hard press springs a visible trap")
	t.check(level.terrain_at(pos) == ConstantsData.Terrain.INACTIVE_TRAP,
		"sprung one-shot trap leaves an inactive trap tile")

func _test_secret_trap_hard_vs_soft(t: Object) -> void:
	var level := _make_level()
	var pos := ConstantsData.xy_to_pos(12, 10)
	var trap := _place_marker_trap(level, pos, ConstantsData.Terrain.SECRET_TRAP)
	level.press_cell(pos, false)
	t.check(not trap.fired and level.terrain_at(pos) == ConstantsData.Terrain.SECRET_TRAP,
		"soft press leaves a hidden trap unsprung and hidden")
	level.press_cell(pos, true)
	t.check(trap.fired, "hard press springs a hidden trap")

func _test_press_tramples_grass(t: Object) -> void:
	var level := _make_level()
	var high := ConstantsData.xy_to_pos(14, 10)
	var furrowed := ConstantsData.xy_to_pos(15, 10)
	level.set_terrain(high, ConstantsData.Terrain.HIGH_GRASS)
	level.set_terrain(furrowed, ConstantsData.Terrain.FURROWED_GRASS)
	level.press_cell(high)
	level.press_cell(furrowed)
	t.check(level.terrain_at(high) == ConstantsData.Terrain.GRASS,
		"press tramples high grass to plain grass")
	t.check(level.terrain_at(furrowed) == ConstantsData.Terrain.GRASS,
		"press flattens furrowed grass to plain grass")

func _test_press_triggers_plant(t: Object) -> void:
	var level := _make_level()
	var pos := ConstantsData.xy_to_pos(16, 10)
	var plant := Plant.new()
	plant.pos = pos
	level.plants[pos] = plant
	level.press_cell(pos)
	t.check(not level.plants.has(pos), "press triggers and consumes the plant")
	t.check(level.terrain_at(pos) == ConstantsData.Terrain.GRASS,
		"triggered plant reverts its tile to grass")

func _test_hard_press_clears_web(t: Object) -> void:
	var level := _make_level()
	var pos := ConstantsData.xy_to_pos(18, 10)
	var web := WebBlob.new()
	web.level = level
	level.add_blob(web, pos, 1.0)
	t.check(web.get_density(pos) > 0.0, "setup: web volume seeded at the cell")
	level.press_cell(pos, false)
	t.check(web.get_density(pos) > 0.0, "soft press leaves webs intact")
	level.press_cell(pos, true)
	t.check(web.get_density(pos) == 0.0, "hard press tears the web at the cell")

func _test_wand_zap_presses_empty_collision(t: Object) -> void:
	var level := _make_level()
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.MAGE)
	hero.pos = ConstantsData.xy_to_pos(10, 12)
	hero.level = level
	var trap_pos := ConstantsData.xy_to_pos(13, 12)
	var trap := _place_marker_trap(level, trap_pos, ConstantsData.Terrain.TRAP)
	# Magic bolts fly through the aimed cell until a char or wall (upstream
	# MAGIC_BOLT has no STOP_TARGET); wall the far side so the bolt's real
	# collision cell is the trap cell.
	level.set_terrain(ConstantsData.xy_to_pos(14, 12), ConstantsData.Terrain.WALL)
	var wand := Wand.WandOfMagicMissile.new()
	wand.charges = 2
	wand.zap(hero, trap_pos)
	t.check(trap.fired, "wand bolt stopping on an empty trap cell springs it")
	hero.free()
