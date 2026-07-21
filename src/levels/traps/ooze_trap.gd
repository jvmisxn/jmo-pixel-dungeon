class_name OozeTrap
extends Trap
## Splashes caustic ooze over the 3x3 non-solid footprint around the trap.

func _init() -> void:
	trap_name = "ooze trap"
	color = Color(0.2, 0.7, 0.1)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("Caustic ooze splashes from the trap!")
	if level == null:
		return
	for cell: int in _affected_cells(level):
		var ch: Variant = level.find_char_at(cell) if level.has_method("find_char_at") else null
		if ch == null or not ch.has_method("add_buff"):
			continue
		var is_flying_char: bool = false
		if ch.has_method("is_flying"):
			is_flying_char = bool(ch.is_flying())
		elif ch.get("flying") != null:
			is_flying_char = bool(ch.get("flying"))
		if is_flying_char:
			continue
		var ooze := Ooze.new()
		ooze.set_duration_value(Ooze.DURATION)
		ch.add_buff(ooze)

func _affected_cells(level: Level) -> Array[int]:
	var result: Array[int] = []
	var dirs: Array[int] = [0]
	dirs.append_array(ConstantsData.DIRS_8)
	var x0: int = ConstantsData.pos_to_x(pos)
	var y0: int = ConstantsData.pos_to_y(pos)
	for dir: int in dirs:
		var cell: int = pos + dir
		if cell < 0 or cell >= Level.LEN:
			continue
		var dx: int = abs(ConstantsData.pos_to_x(cell) - x0)
		var dy: int = abs(ConstantsData.pos_to_y(cell) - y0)
		if dx > 1 or dy > 1:
			continue
		if ConstantsData.terrain_is_solid(level.terrain_at(cell)):
			continue
		result.append(cell)
	return result
