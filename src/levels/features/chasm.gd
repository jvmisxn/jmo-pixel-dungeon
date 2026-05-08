class_name Chasm
extends RefCounted
## Chasm interaction logic. Chasms can be fallen into (taking damage and
## descending a floor) or crossed with levitation.

## Damage dealt when falling into a chasm.
const FALL_DAMAGE_MIN: int = 5
const FALL_DAMAGE_PER_DEPTH: int = 2

# ---------------------------------------------------------------------------
# Chasm Actions
# ---------------------------------------------------------------------------

## Check if a character can cross a chasm cell (requires levitation).
static func can_cross(actor: Variant) -> bool:
	if actor == null:
		return false
	# Check for levitation buff
	if actor.has_method("has_buff") and actor.has_buff("levitation"):
		return true
	return false

## Handle falling into a chasm. Returns the damage dealt.
static func fall(actor: Variant, level: Level) -> int:
	if actor == null:
		return 0

	var damage: int = FALL_DAMAGE_MIN + level.depth * FALL_DAMAGE_PER_DEPTH

	if MessageLog:
		MessageLog.add("You fall into the chasm!")

	# Apply damage
	if actor.has_method("take_damage"):
		actor.take_damage(damage, "chasm")

	# Drop equipped items chance
	if actor.has_method("drop_random_item") and randf() < 0.25:
		actor.drop_random_item()

	return damage

## Check if a position is a chasm.
static func is_chasm(level: Level, pos: int) -> bool:
	return level.terrain_at(pos) == ConstantsData.Terrain.CHASM

## Find safe landing positions around a chasm (for teleportation recovery).
static func find_safe_landing(level: Level, around_pos: int) -> int:
	for dir: int in ConstantsData.DIRS_8:
		var adj: int = around_pos + dir
		if adj >= 0 and adj < Level.LEN and level.is_passable(adj):
			return adj
	return level.random_passable_cell()
