class_name LightningArc
extends RefCounted
## Shared chain-lightning arc flood, mirroring upstream Shocking.arc(): from a
## struck character, chain to every character reachable within `dist` BFS steps
## over non-solid cells; each newly caught character re-arcs with reach 1
## (2 while standing in water and not flying). The attacker is never caught.
## Used by the Shocking weapon enchant; WandOfLightning keeps its own port
## adaptation because it adds a hero-adjacency safety rule on top.


## Returns every character caught by the chain, `defender` first (upstream
## Shocking.arc seeds `affected` with the defender before flooding).
static func chain(lvl: Variant, attacker: Variant, defender: Variant,
		initial_reach: int = 2) -> Array:
	var affected: Array = []
	if lvl == null or not lvl.has_method("find_char_at") or defender == null:
		return affected
	affected.append(defender)
	_arc(lvl, attacker, defender, initial_reach, affected)
	return affected


## One arc hop: collect every not-yet-caught character within `reach` of
## `from_char` breadth-first, then recurse from each (upstream builds
## hitThisArc fully before re-arcing).
static func _arc(lvl: Variant, attacker: Variant, from_char: Variant,
		reach: int, affected: Array) -> void:
	var dist_map: Dictionary = cells_within(lvl, int(from_char.get("pos")), reach)
	var hit_this_arc: Array = []
	for cell: int in dist_map.keys():
		var n: Variant = lvl.find_char_at(cell)
		if n == null or n == attacker or n in affected or n in hit_this_arc:
			continue
		if not bool(n.get("is_alive")):
			continue
		hit_this_arc.append(n)
	for n: Variant in hit_this_arc:
		affected.append(n)
	for n: Variant in hit_this_arc:
		var n_reach: int = 1
		if cell_is_water(lvl, int(n.get("pos"))) and not bool(n.get("flying")):
			n_reach = 2
		_arc(lvl, attacker, n, n_reach, affected)


## BFS step-distance map from `origin` over non-solid cells (8-directional) out
## to `max_dist` steps -- the port's stand-in for SPD's
## PathFinder.buildDistanceMap(origin, not solid, max_dist). Excludes `origin`.
## Wrap-safe via level.adjacent(); falls back to open flooding when the level
## exposes no passability so lightweight test levels still chain.
static func cells_within(lvl: Variant, origin: int, max_dist: int) -> Dictionary:
	var dist_map: Dictionary = {origin: 0}
	var frontier: Array[int] = [origin]
	var has_pass: bool = lvl != null and lvl.has_method("is_passable")
	while not frontier.is_empty():
		var next_frontier: Array[int] = []
		for cell: int in frontier:
			var d: int = int(dist_map[cell])
			if d >= max_dist:
				continue
			for dir: int in ConstantsData.DIRS_8:
				var n: int = cell + dir
				if not ConstantsData.is_valid_pos(n):
					continue
				if not cells_adjacent(lvl, cell, n):
					continue
				if dist_map.has(n):
					continue
				if has_pass and not lvl.is_passable(n):
					continue
				dist_map[n] = d + 1
				next_frontier.append(n)
		frontier = next_frontier
	dist_map.erase(origin)
	return dist_map


## Wrap-safe 8-neighbour adjacency, delegating to level.adjacent() when present.
static func cells_adjacent(lvl: Variant, a: int, b: int) -> bool:
	if lvl != null and lvl.has_method("adjacent"):
		return lvl.adjacent(a, b)
	var ax: int = ConstantsData.pos_to_x(a)
	var ay: int = ConstantsData.pos_to_y(a)
	var bx: int = ConstantsData.pos_to_x(b)
	var by: int = ConstantsData.pos_to_y(b)
	return absi(ax - bx) <= 1 and absi(ay - by) <= 1 and a != b


## Whether a cell is water terrain (which conducts lightning).
static func cell_is_water(lvl: Variant, cell: int) -> bool:
	return lvl != null and lvl.has_method("get_terrain") \
		and lvl.get_terrain(cell) == ConstantsData.Terrain.WATER


## Port stand-in for upstream Char.alignment comparison: the hero and allied
## mobs share one side, everything else is the enemy side.
static func same_alignment(a: Variant, b: Variant) -> bool:
	return _is_hero_side(a) == _is_hero_side(b)


static func _is_hero_side(c: Variant) -> bool:
	if c is Hero:
		return true
	if c is Mob:
		return (c as Mob).is_ally
	return false
