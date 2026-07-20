class_name Vertigo
extends Buff
## Vertigo debuff: movement goes in a random direction instead.

const BASE_DURATION: float = 5.0

func _init() -> void:
	buff_id = "Vertigo"
	buff_name = "Vertigo"
	buff_type = BuffType.NEGATIVE
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.7, 0.3, 0.7)

func on_attach() -> void:
	if MessageLog and target:
		MessageLog.add_negative("%s feels dizzy!" % target.name)

## Returns a randomized position instead of the intended destination.
## Call this from movement logic: if char has Vertigo, replace target cell.
func randomize_direction(intended_pos: int, current_pos: int) -> int:
	if target == null or target.level == null:
		return intended_pos
	if not target.level.has_method("is_passable"):
		return intended_pos
	# Pick a random true 8-neighbour instead of the intended cell. Guard against
	# grid edge-wrap: the E/W/diagonal offsets at a column edge land on the
	# opposite edge of an adjacent row, so require the candidate to stay within
	# one column of the current cell (see audit S19 / plant edge-wrap fix).
	var col: int = current_pos % Level.W
	var valid_positions: Array[int] = []
	for offset: int in ConstantsData.DIRS_8:
		var pos: int = current_pos + offset
		if pos < 0 or pos >= Level.LEN:
			continue
		if absi(pos % Level.W - col) > 1:
			continue
		if target.level.is_passable(pos):
			valid_positions.append(pos)
	if valid_positions.is_empty():
		return intended_pos
	return valid_positions[randi() % valid_positions.size()]

func description() -> String:
	return "Dizzy! Movement direction is randomized."
