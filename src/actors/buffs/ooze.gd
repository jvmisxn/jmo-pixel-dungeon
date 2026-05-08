class_name Ooze
extends Buff
## Ooze debuff: deals depth-scaling damage per turn. Washed off by water.
## Original: 1+depth/5 dmg at depth>5, 1 at depth 5, 50% chance of 1 at depth<5.

const DURATION: float = 20.0

var left: float = DURATION
var acted: bool = false

func _init() -> void:
	buff_id = "Ooze"
	buff_name = "Caustic Ooze"
	buff_type = BuffType.NEGATIVE
	duration = -1.0  # managed by 'left'
	time_left = -1.0
	icon_color = Color(0.2, 0.6, 0.1)

func set_duration_value(new_left: float) -> void:
	left = new_left
	acted = false

func extend(extra: float) -> void:
	left += extra

func on_turn() -> void:
	if target == null:
		return

	# Water washes off ooze if it has already acted
	if acted and _is_in_water() and not _is_flying():
		if target:
			target.remove_buff(self)
		return

	if target.is_alive:
		acted = true
		var depth: int = 1
		if GameManager:
			depth = maxi(1, GameManager.depth)
		@warning_ignore("integer_division")
		var dmg: int = 1
		if depth > 5:
			dmg = 1 + depth / 5
		elif depth < 5:
			dmg = 1 if randf() < 0.5 else 0
		if dmg > 0:
			target.take_damage(dmg, self, "caustic")
			if MessageLog:
				MessageLog.add_negative("The caustic ooze eats at %s! (%d dmg)" % [target.mob_name, dmg])

	left -= 1.0
	if left <= 0.0:
		if target:
			target.remove_buff(self)

func _is_in_water() -> bool:
	if target == null:
		return false
	var pos: int = target.pos
	if pos < 0:
		return false
	if target.get("level") != null:
		var lvl: Variant = target.level
		if lvl and lvl.has_method("get_terrain"):
			return lvl.get_terrain(pos) == ConstantsData.Terrain.WATER
	return false

func _is_flying() -> bool:
	if target == null:
		return false
	if target.has_method("is_flying"):
		return target.is_flying()
	return false

func description() -> String:
	return "Caustic ooze clings to the target, dealing damage each turn. Standing in water washes it off."
