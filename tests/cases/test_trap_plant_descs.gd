extends RefCounted
## Examine descriptions for traps and plants (SPD levels.properties /
## plants.properties parity): every concrete trap and plant class must resolve
## to a real upstream description through CellExaminer, never the generic
## fallback line, and unknown/null inputs must fall back safely.


func _instance_scripts(dir_path: String, base_file: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".gd") and fname != base_file:
			var script: GDScript = load(dir_path + "/" + fname)
			if script != null and script.can_instantiate():
				out.append(script.new())
		fname = dir.get_next()
	dir.list_dir_end()
	return out


func run(t: Object) -> void:
	# --- Traps ---
	var traps: Array = _instance_scripts("res://src/levels/traps", "trap.gd")
	t.check(traps.size() >= 31, "instantiated all concrete trap classes (%d)" % traps.size())
	var missing_traps: Array[String] = []
	for trap: Variant in traps:
		var desc: String = CellExaminer.trap_desc(trap)
		if desc.is_empty() or desc == CellExaminer.GENERIC_TRAP_DESC:
			missing_traps.append(str(trap.trap_name))
	t.check(missing_traps.is_empty(),
		"every trap has a real upstream description (missing: %s)" % str(missing_traps))

	# --- Plants ---
	var plants: Array = _instance_scripts("res://src/plants", "plant.gd")
	t.check(plants.size() >= 12, "instantiated all concrete plant classes (%d)" % plants.size())
	var missing_plants: Array[String] = []
	for plant: Variant in plants:
		var desc: String = CellExaminer.plant_desc(plant)
		if desc.is_empty() or desc == CellExaminer.GENERIC_PLANT_DESC:
			missing_plants.append(str(plant.plant_name))
	t.check(missing_plants.is_empty(),
		"every plant has a real upstream description (missing: %s)" % str(missing_plants))

	# --- No orphaned table keys (catches renames drifting out of sync) ---
	var trap_names: Array[String] = []
	for trap: Variant in traps:
		trap_names.append(str(trap.trap_name))
	var orphan_traps: Array[String] = []
	for key: String in CellExaminer.TRAP_DESCS.keys():
		if not trap_names.has(key):
			orphan_traps.append(key)
	t.check(orphan_traps.is_empty(),
		"no TRAP_DESCS key without a matching trap class (orphans: %s)" % str(orphan_traps))

	var plant_names: Array[String] = []
	for plant: Variant in plants:
		plant_names.append(str(plant.plant_name))
	var orphan_plants: Array[String] = []
	for key: String in CellExaminer.PLANT_DESCS.keys():
		if not plant_names.has(key):
			orphan_plants.append(key)
	t.check(orphan_plants.is_empty(),
		"no PLANT_DESCS key without a matching plant class (orphans: %s)" % str(orphan_plants))

	# --- Fallbacks ---
	t.check(CellExaminer.trap_desc(null) == CellExaminer.GENERIC_TRAP_DESC,
		"null trap falls back to the generic pressure-plate line")
	t.check(CellExaminer.plant_desc(null) == CellExaminer.GENERIC_PLANT_DESC,
		"null plant falls back to the generic activation line")
	var unknown_trap := Trap.new()
	unknown_trap.trap_name = "totally unknown trap"
	t.check(CellExaminer.trap_desc(unknown_trap) == CellExaminer.GENERIC_TRAP_DESC,
		"unknown trap name falls back to the generic line")
