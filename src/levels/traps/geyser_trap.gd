class_name GeyserTrap
extends Trap
## Mirrors Shattered Pixel Dungeon's GeyserTrap: a teal diamond trap that erupts
## a burst of water. On activation it floods a radius-2 footprint with water
## (dousing terrain fire), then for every character on the trap cell and in the
## 8 adjacent cells it strips Burning, knocks the character back two tiles
## (neighbours away from the trap, the centre character in a chosen direction),
## and scalds fiery enemies (fire elementals) for depth-scaled damage - full
## damage at the centre, 0.67x for the pushed neighbours.
##
## Documented divergences from upstream (kept out of this narrow slice, matching
## how earlier trap slices scoped their omissions):
##  - No `throwChar` wall-collision slam damage; knockback simply stops at the
##    first blocking cell.
##  - Hero-specific hazard-avoidance for the centre knockback direction is not
##    modelled (this port has no `Level.avoid` map); the centre character is
##    pushed in the first open direction (or a forced `center_knock_back_direction`).
##  - Water spread uses a Chebyshev radius-2 footprint over floor-like terrain
##    rather than SPD's `buildDistanceMap` over all non-solid cells, and the
##    splash/gas audiovisual effects are not modelled.

const KNOCKBACK: int = 2
const WATER_RADIUS: int = 2
## Chance a distance-2 ring cell also floods (SPD: `Random.Int(3) > 0`).
const RING_FLOOD_CHANCE: float = 2.0 / 3.0
const FIRE_DMG_MIN_BASE: int = 5   # + scalingDepth()
const FIRE_DMG_MAX_BASE: int = 10  # + scalingDepth() * 2
const NEIGHBOUR_DMG_MULT: float = 0.67

## Terrain types the geyser converts to water. Floor-like tiles only, so the
## burst never clobbers stairs, wells, pedestals, doors, walls, other traps, or
## already-flooded cells.
const _FLOODABLE: Array = [
	ConstantsData.Terrain.EMPTY, ConstantsData.Terrain.GRASS,
	ConstantsData.Terrain.HIGH_GRASS, ConstantsData.Terrain.FURROWED_GRASS,
	ConstantsData.Terrain.EMBERS, ConstantsData.Terrain.EMPTY_SP,
]

## -1 = no forced centre knockback direction (SPD `centerKnockBackDirection`).
## When set to a `ConstantsData.DIRS_8` offset, the centre character is pushed
## that way; callers (e.g. a mob-sourced geyser) may set it before activation.
var center_knock_back_direction: int = -1

func _init() -> void:
	trap_name = "geyser trap"
	color = Color(0.0, 0.5, 0.5)  # TEAL
	# Upstream GeyserTrap does NOT set canBeHidden=false, so it spawns hidden
	# like an ordinary trap (unlike DisintegrationTrap). Left at the base
	# `visible = false`; activate()/reveal() surface it on trigger or search.

func _do_effect(triggerer: Variant, level: Level) -> void:
	if level == null:
		return
	# Capture the centre character before flooding (flooding never moves chars).
	var center_char: Variant = level.find_char_at(pos) if level.has_method("find_char_at") else null
	_flood_water(level)
	# Push the 8 neighbours outward (0.67x scald), then the centre character.
	for dir: int in ConstantsData.DIRS_8:
		var npos: int = pos + dir
		if not _valid_step(pos, npos):
			continue
		var ch: Variant = level.find_char_at(npos) if level.has_method("find_char_at") else null
		if ch == null or ch == center_char:
			continue
		_erupt_char(level, ch, npos, NEIGHBOUR_DMG_MULT)
	if center_char != null:
		_erupt_char(level, center_char, pos, 1.0)

# ---------------------------------------------------------------------------
# Water burst
# ---------------------------------------------------------------------------

func _flood_water(level: Level) -> void:
	var cx: int = ConstantsData.pos_to_x(pos)
	var cy: int = ConstantsData.pos_to_y(pos)
	for dy: int in range(-WATER_RADIUS, WATER_RADIUS + 1):
		for dx: int in range(-WATER_RADIUS, WATER_RADIUS + 1):
			var x: int = cx + dx
			var y: int = cy + dy
			if x < 0 or x >= ConstantsData.WIDTH or y < 0 or y >= ConstantsData.HEIGHT:
				continue
			var cell: int = ConstantsData.xy_to_pos(x, y)
			var terr: int = level.terrain_at(cell)
			if not _FLOODABLE.has(terr):
				continue
			# Chebyshev distance: inner cells always flood, the outer ring floods
			# only part of the time (SPD: dist < 2 always, dist == 2 random).
			var cheby: int = maxi(absi(dx), absi(dy))
			if cheby >= WATER_RADIUS and randf() >= RING_FLOOD_CHANCE:
				continue
			level.set_terrain(cell, ConstantsData.Terrain.WATER)

# ---------------------------------------------------------------------------
# Per-character eruption
# ---------------------------------------------------------------------------

func _erupt_char(level: Level, ch: Variant, ch_pos: int, dmg_mult: float) -> void:
	if ch == null or not (ch is Object):
		return
	# The water douses any burning on a living character.
	if _char_alive(ch) and ch.has_method("has_buff") and ch.has_buff("Burning"):
		ch.remove_buff_by_id("Burning")
	# Determine and apply knockback.
	var dir: int = _center_direction(level) if ch_pos == pos else _away_offset(ch_pos)
	if dir != 0:
		_knock_back(ch, ch_pos, dir)
	# Scald fiery enemies (fire elementals). take_damage keeps their fire immunity.
	if _is_fiery(ch) and ch.has_method("take_damage"):
		var depth: int = level.depth if level != null else 0
		var dmg: int = int(round(float(_normal_int_range(
			FIRE_DMG_MIN_BASE + depth, FIRE_DMG_MAX_BASE + depth * 2)) * dmg_mult))
		if dmg > 0:
			ch.take_damage(dmg, self)

func _knock_back(ch: Variant, from_pos: int, dir: int) -> void:
	if not ch.has_method("move_to"):
		return
	var current: int = from_pos
	for _step: int in range(KNOCKBACK):
		var next_pos: int = current + dir
		if not _valid_step(current, next_pos):
			break
		# move_to already rejects impassable/occupied cells.
		if not ch.move_to(next_pos):
			break
		current = next_pos

## Direction offset pushing a neighbour directly away from the trap centre.
func _away_offset(ch_pos: int) -> int:
	var dx: int = signi(ConstantsData.pos_to_x(ch_pos) - ConstantsData.pos_to_x(pos))
	var dy: int = signi(ConstantsData.pos_to_y(ch_pos) - ConstantsData.pos_to_y(pos))
	return dy * ConstantsData.WIDTH + dx

## Knockback direction for a character standing on the trap cell.
func _center_direction(level: Level) -> int:
	if center_knock_back_direction != -1:
		return center_knock_back_direction
	var dirs: Array = ConstantsData.DIRS_8.duplicate()
	dirs.shuffle()
	for dir: int in dirs:
		var target: int = pos + dir
		if _valid_step(pos, target) and (level == null or not level.has_method("is_passable") or level.is_passable(target)):
			return dir
	return 0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## True when [to_pos] is a real in-bounds 8-neighbour of [from_pos] (no row wrap).
func _valid_step(from_pos: int, to_pos: int) -> bool:
	if not ConstantsData.is_valid_pos(to_pos):
		return false
	var fx: int = ConstantsData.pos_to_x(from_pos)
	var fy: int = ConstantsData.pos_to_y(from_pos)
	var tx: int = ConstantsData.pos_to_x(to_pos)
	var ty: int = ConstantsData.pos_to_y(to_pos)
	return absi(tx - fx) <= 1 and absi(ty - fy) <= 1 and to_pos != from_pos

func _char_alive(ch: Variant) -> bool:
	if ch.get("is_alive") != null:
		return bool(ch.is_alive)
	if ch.get("hp") != null:
		return int(ch.hp) > 0
	return true

func _is_fiery(ch: Variant) -> bool:
	if ch.has_method("is_fiery"):
		return bool(ch.is_fiery())
	# This port's only fiery character is the Fire Elemental.
	return ch.get("mob_id") == "elemental"

func _normal_int_range(min_value: int, max_value: int) -> int:
	return int(floor(float(randi_range(min_value, max_value) + randi_range(min_value, max_value)) / 2.0))
