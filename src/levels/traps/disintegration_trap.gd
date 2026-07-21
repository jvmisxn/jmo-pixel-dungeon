class_name DisintegrationTrap
extends Trap
## Mirrors Shattered Pixel Dungeon's DisintegrationTrap: a visible City trap
## that fires a death ray at the closest character it can aim at.

const DAMAGE_MIN: int = 30
const DAMAGE_MAX: int = 50
const MIN_RANGE: int = 6

func _init() -> void:
	trap_name = "disintegration trap"
	color = Color(0.55, 0.0, 0.75)
	visible = true

func _do_effect(triggerer: Variant, level: Level) -> void:
	var target: Variant = level.find_char_at(pos) if level != null and level.has_method("find_char_at") else triggerer
	if target == null and triggerer is Object and triggerer.get("pos") == pos:
		target = triggerer
	if target == null:
		target = _find_closest_aimable_char(level)
	if target == null or not target.has_method("take_damage"):
		return
	target.take_damage(_roll_damage(level), self)

func _roll_damage(level: Level) -> int:
	var depth_bonus: int = level.depth if level != null else 0
	return _normal_int_range(DAMAGE_MIN, DAMAGE_MAX) + depth_bonus

func _normal_int_range(min_value: int, max_value: int) -> int:
	return int(floor(float(randi_range(min_value, max_value) + randi_range(min_value, max_value)) / 2.0))

func _find_closest_aimable_char(level: Level) -> Variant:
	if level == null:
		return null
	var chars: Array = _level_chars(level)
	if chars.is_empty():
		return null
	var range_limit: float = float(maxi(MIN_RANGE, int(level.get("view_distance") if level.get("view_distance") != null else ConstantsData.VIEW_DISTANCE))) + 0.5
	var best: Variant = null
	var best_dist: float = INF
	for ch: Variant in chars:
		if ch == null or not (ch is Object):
			continue
		if ch.get("pos") == null or not _char_is_alive(ch):
			continue
		var dist: float = float(Ballistica.distance(pos, int(ch.pos)))
		if ch.get("invisible") != null and int(ch.invisible) > 0:
			dist = maxf(dist, range_limit)
		if dist > range_limit:
			continue
		if not _can_aim_at(level, int(ch.pos), chars):
			continue
		if dist < best_dist or (is_equal_approx(dist, best_dist) and best is Hero):
			best = ch
			best_dist = dist
	return best

func _level_chars(level: Level) -> Array:
	var chars: Array = []
	if level.has_method("get_heroes"):
		chars.append_array(level.get_heroes())
	if level.has_method("get_mobs"):
		chars.append_array(level.get_mobs())
	return chars

func _char_is_alive(ch: Variant) -> bool:
	if ch.get("is_alive") != null:
		return bool(ch.is_alive)
	if ch.get("hp") != null:
		return int(ch.hp) > 0
	return true

func _can_aim_at(level: Level, target_pos: int, chars: Array) -> bool:
	var passable_map: Array[bool] = level.passable if level.get("passable") != null and not level.passable.is_empty() else _open_passable()
	var occupied: Array[bool] = []
	occupied.resize(passable_map.size())
	occupied.fill(false)
	for ch: Variant in chars:
		if ch is Object and ch.get("pos") != null:
			var cpos: int = int(ch.pos)
			if cpos >= 0 and cpos < occupied.size():
				occupied[cpos] = true
	var bolt := Ballistica.new()
	bolt.cast(pos, target_pos, passable_map, Ballistica.PROJECTILE, occupied, ConstantsData.WIDTH, level.map if level.get("map") != null else [])
	return bolt.collision_pos == target_pos

func _open_passable() -> Array[bool]:
	var passable_map: Array[bool] = []
	passable_map.resize(ConstantsData.LENGTH)
	passable_map.fill(true)
	return passable_map
