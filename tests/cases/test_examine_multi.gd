extends RefCounted
## Multi-object examine parity with upstream GameScene.examineCell()/
## getObjectsAtCell(): everything of interest on a cell is collected in
## char > heap > plant > trap order, each heap item gets its own entry
## (the port's heap multi-item listing), and the chooser window lists one
## button per object.

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

	# --- Empty known cell lists nothing (terrain fallback happens in examine) ---
	var empty_pos: int = ConstantsData.xy_to_pos(4, 4)
	level.visited[empty_pos] = true
	t.check(CellExaminer.list_cell_objects(level, null, empty_pos).is_empty(),
		"an empty known cell collects no objects")
	t.check(CellExaminer.list_cell_objects(level, null, ConstantsData.xy_to_pos(20, 20)).is_empty(),
		"an unknown cell collects no objects")

	# --- Stacked cell: mob + two heap items + plant + trap ---
	var pos: int = ConstantsData.xy_to_pos(5, 5)
	level.visible[pos] = true
	level.visited[pos] = true
	var rat: Variant = MobFactory.create_mob("rat")
	rat.pos = pos
	level.mobs.append(rat)
	level.drop_item(pos, Generator.create_item("dewdrop"))
	level.drop_item(pos, Generator.create_item("dewdrop"))
	var plant := Plant.new()
	plant.plant_name = "Firebloom"
	plant.pos = pos
	level.plants[pos] = plant
	var trap := Trap.new()
	trap.trap_name = "fire trap"
	trap.visible = true
	level.place_trap(pos, trap)

	var objects: Array[Dictionary] = CellExaminer.list_cell_objects(level, null, pos)
	t.check(objects.size() == 5,
		"mob + 2 heap items + plant + trap yields 5 entries, got %d" % objects.size())
	if objects.size() == 5:
		t.check(str(objects[0]["kind"]) == "mob", "char entry comes first (upstream order)")
		t.check(str(objects[1]["kind"]) == "heap" and str(objects[2]["kind"]) == "heap",
			"each heap item gets its own entry (multi-item listing)")
		t.check(str(objects[3]["kind"]) == "plant" and str(objects[4]["kind"]) == "trap",
			"plant then visible trap close out the list")
		t.check(not str(objects[1]["name"]).is_empty(),
			"heap entries carry an item display name")

	# --- Out-of-FOV: mob entry drops, the rest remain ---
	level.visible[pos] = false
	objects = CellExaminer.list_cell_objects(level, null, pos)
	t.check(objects.size() == 4 and str(objects[0]["kind"]) == "heap",
		"out-of-FOV chars are skipped; heaps lead the remaining list")

	# --- Hidden trap is not listed ---
	trap.visible = false
	objects = CellExaminer.list_cell_objects(level, null, pos)
	t.check(objects.size() == 3,
		"a hidden trap is not collected")
	trap.visible = true

	# --- describe_cell keeps first-object priority semantics ---
	level.visible[pos] = true
	t.check(str(CellExaminer.describe_cell(level, null, pos)["kind"]) == "mob",
		"describe_cell reports the first collected object")

	# --- Chooser window smoke test ---
	var names: PackedStringArray = []
	for obj: Dictionary in CellExaminer.list_cell_objects(level, null, pos):
		names.append(str(obj["name"]))
	var wnd: WndExamineChoice = WndExamineChoice.new()
	wnd.setup(CellExaminer.MULTIPLE_EXAMINE_TEXT, names)
	var content: Control = wnd._build_content()
	var buttons: int = 0
	for child: Node in content.get_children():
		if child is Button:
			buttons += 1
	t.check(buttons == names.size(),
		"WndExamineChoice builds one button per object, got %d for %d" % [buttons, names.size()])
	# Pressing a button would run close_window()'s tween, which needs the
	# scene tree; headless we only verify each button is wired to a handler.
	var wired: bool = true
	for child: Node in content.get_children():
		if child is Button and (child as Button).pressed.get_connections().is_empty():
			wired = false
	t.check(wired, "every chooser button is wired to a pressed handler")
	content.free()
	wnd.free()

	# --- Cleanup ---
	level.mobs.clear()
	if rat is Node:
		rat.free()
