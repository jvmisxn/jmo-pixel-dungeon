class_name KnockBack
extends RefCounted
## Shared forced-movement push mirroring upstream Char.throwChar traversal for
## simple knockback effects (Repulsion glyph, Elastic enchant). Chasm cells are
## AVOID terrain upstream, so forced movement can enter them: flying chars sail
## over, grounded chars fall in (Chasm.force_fall). Movement stops at the map
## edge, solid terrain, or another character (no wall-slam damage here — that
## is a Blast Wave-specific effect).

## Push `ch` up to `distance` cells directly away from `from_pos`.
## Returns true if the char moved at least one cell.
static func throw_char(ch: Variant, from_pos: int, distance: int, lvl: Variant = null) -> bool:
	if ch == null or not is_instance_valid(ch) or ch.get("pos") == null:
		return false
	if lvl == null:
		lvl = ch.get("level")
	if lvl == null:
		return false
	var start_pos: int = ch.pos
	var dx: int = signi(ConstantsData.pos_to_x(start_pos) - ConstantsData.pos_to_x(from_pos))
	var dy: int = signi(ConstantsData.pos_to_y(start_pos) - ConstantsData.pos_to_y(from_pos))
	if dx == 0 and dy == 0:
		return false
	var current_pos: int = start_pos
	for _step: int in range(distance):
		var nx: int = ConstantsData.pos_to_x(current_pos) + dx
		var ny: int = ConstantsData.pos_to_y(current_pos) + dy
		if nx < 0 or nx >= ConstantsData.WIDTH or ny < 0 or ny >= ConstantsData.HEIGHT:
			break
		var next_pos: int = ConstantsData.xy_to_pos(nx, ny)
		if lvl.has_method("find_char_at") and lvl.find_char_at(next_pos) != null:
			break
		if lvl.has_method("terrain_at") \
				and lvl.terrain_at(next_pos) == ConstantsData.Terrain.CHASM:
			var prev_pos: int = current_pos
			ch.pos = next_pos
			if ch.has_method("on_move"):
				ch.on_move(prev_pos, next_pos)
			current_pos = next_pos
			if Chasm.can_cross(ch):
				continue
			Chasm.force_fall(ch, lvl if lvl is Level else null)
			return true
		if lvl.has_method("is_passable") and not lvl.is_passable(next_pos):
			break
		if ch.has_method("move_to"):
			ch.move_to(next_pos)
		else:
			ch.pos = next_pos
		current_pos = next_pos
	return current_pos != start_pos
