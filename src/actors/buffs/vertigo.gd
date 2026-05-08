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
	# Pick a random adjacent cell instead of the intended one
	var width: int = target.level.width if target.level.get("width") else 32
	var offsets: Array[int] = [-1, 1, -width, width, -width - 1, -width + 1, width - 1, width + 1]
	var valid_positions: Array[int] = []
	for offset in offsets:
		var pos: int = current_pos + offset
		if pos >= 0 and target.level.has_method("is_passable"):
			if target.level.is_passable(pos):
				valid_positions.append(pos)
	if valid_positions.is_empty():
		return intended_pos
	return valid_positions[randi() % valid_positions.size()]

func description() -> String:
	return "Dizzy! Movement direction is randomized."
