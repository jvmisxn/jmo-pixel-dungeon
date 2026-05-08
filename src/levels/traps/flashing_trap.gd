class_name FlashingTrap
extends Trap
## Blinds the victim and all nearby characters.

func _init() -> void:
	trap_name = "flashing trap"
	color = Color(1.0, 1.0, 0.8)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A blinding flash of light!")

	# Blind the triggerer
	_apply_blindness(triggerer, level)

	# Blind all characters in adjacent cells
	for dir: int in ConstantsData.DIRS_8:
		var adj: int = pos + dir
		if adj >= 0 and adj < Level.LEN:
			var mob: Variant = level.mob_at(adj)
			if mob != null:
				_apply_blindness(mob, level)

func _apply_blindness(target: Variant, level: Level) -> void:
	if target == null:
		return
	if target.has_method("add_buff"):
		var blind: Blindness = Blindness.new()
		@warning_ignore("integer_division")
		var dur: float = 5.0 + float(level.depth) / 2.0
		blind.duration = dur
		blind.time_left = dur
		target.add_buff(blind)
	# Also apply vertigo for disorientation
	if target.has_method("add_buff"):
		var vert: Vertigo = Vertigo.new()
		vert.duration = 3.0
		vert.time_left = 3.0
		target.add_buff(vert)
