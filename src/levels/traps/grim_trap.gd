class_name GrimTrap
extends Trap
## Visible Halls trap that fires a shadow bolt at the character on its cell, or
## the closest aimable character in range. Mirrors Shattered Pixel Dungeon's
## GrimTrap damage model; audiovisual/badge side effects are omitted.

const MIN_RANGE: int = 6

func _init() -> void:
	trap_name = "grim trap"
	color = Color(0.2, 0.2, 0.2)
	visible = true

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A deadly glyph pulses with shadow!")

	var target: Variant = level.find_char_at(pos) if level != null and level.has_method("find_char_at") else triggerer
	if target == null and triggerer is Object and triggerer.get("pos") == pos:
		target = triggerer
	if target == null:
		target = _find_closest_aimable_char(level)
	if target == null or not target.has_method("take_damage"):
		return

	target.take_damage(_grim_damage(target), self)

func _grim_damage(target: Variant) -> int:
	var max_hp: int = int(target.ht) if target is Object and target.get("ht") != null else 0
	var cur_hp: int = int(target.hp) if target is Object and target.get("hp") != null else 0
	var damage: int = roundi(float(max_hp) / 2.0 + float(cur_hp) / 2.0)
	if target is Hero:
		damage = mini(damage, int(floor(float(max_hp) * 0.9)))
	return damage

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
		var dist: float = _true_distance(pos, int(ch.pos))
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

func _true_distance(from_pos: int, to_pos: int) -> float:
	var dx: float = float(ConstantsData.pos_to_x(from_pos) - ConstantsData.pos_to_x(to_pos))
	var dy: float = float(ConstantsData.pos_to_y(from_pos) - ConstantsData.pos_to_y(to_pos))
	return sqrt(dx * dx + dy * dy)

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
