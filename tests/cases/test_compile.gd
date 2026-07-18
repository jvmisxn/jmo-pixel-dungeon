extends RefCounted
## Compile smoke test: every script under src must load as a valid GDScript. A
## parse error or truncated file makes load() return null, so this catches the
## exact failure mode this repo has historically suffered.

const SOURCE_ROOT: String = "res://src"

func run(t: Object) -> void:
	var paths: Array[String] = []
	_collect_gd_scripts(SOURCE_ROOT, paths)
	paths.sort()
	t.check(not paths.is_empty(), "compile smoke discovered source scripts")
	for path: String in paths:
		var res: Variant = load(path)
		t.check(res != null and res is GDScript, "compiles: " + path)


func _collect_gd_scripts(dir_path: String, paths: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var child_path: String = dir_path.path_join(file_name)
		if dir.current_is_dir():
			_collect_gd_scripts(child_path, paths)
		elif file_name.ends_with(".gd"):
			paths.append(child_path)
		file_name = dir.get_next()
	dir.list_dir_end()
