class_name Chasm
extends RefCounted
## Chasm interaction logic. Chasms can be fallen into (taking damage and
## descending a floor) or crossed with levitation.

## Damage dealt when falling into a chasm.
const MIN_FALL_DAMAGE: int = 1

# ---------------------------------------------------------------------------
# Chasm Actions
# ---------------------------------------------------------------------------

## Check if a character can cross a chasm cell (requires levitation).
static func can_cross(actor: Variant) -> bool:
	if actor == null:
		return false
	if actor.get("flying") == true:
		return true
	if actor.has_method("has_buff") and actor.has_buff("Levitation"):
		return true
	return false

## SPD scales fall damage against max HP and current HP fraction. At full HP
## the damage is about maxHP/12; at low HP it approaches maxHP/6.
static func fall_damage(actor: Variant) -> int:
	if actor == null:
		return 0
	var max_hp: int = int(actor.get("ht")) if actor.get("ht") != null else int(actor.get("hp_max"))
	var hp: int = int(actor.get("hp")) if actor.get("hp") != null else max_hp
	if max_hp <= 0:
		return MIN_FALL_DAMAGE
	var hp_fraction: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var divisor: float = 6.0 + 6.0 * hp_fraction
	return maxi(MIN_FALL_DAMAGE, roundi(float(max_hp) / divisor))

## Apply landing damage after the floor transition has completed.
static func apply_landing_damage(actor: Variant, _level: Level = null) -> int:
	var damage: int = fall_damage(actor)
	if actor != null and actor.has_method("take_damage"):
		actor.take_damage(damage, "chasm")
		if actor.get("is_alive") == true and actor.has_method("add_buff"):
			var bleed: Bleeding = Bleeding.create(float(damage))
			actor.add_buff(bleed)
	if MessageLog:
		MessageLog.add_negative("You crash into the floor below!")
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
