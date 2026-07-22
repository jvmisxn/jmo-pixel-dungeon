class_name Chasm
extends RefCounted
## Chasm interaction logic. Chasms can be fallen into (taking damage and
## descending a floor) or crossed with levitation.

## Damage dealt when falling into a chasm.
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

## SPD's Chasm.heroLand damage is based on the hero's current HP, not a flat
## fraction of max HP: max(HP/2, NormalIntRange(HP/2, HT/4)).
static func fall_damage(actor: Variant) -> int:
	if actor == null:
		return 0
	var current_hp: int = int(actor.get("hp")) if actor.get("hp") != null else 0
	var max_hp: int = _max_hp(actor)
	if current_hp <= 0 or max_hp <= 0:
		return 1
	var min_damage: int = maxi(1, current_hp / 2)
	var max_damage: int = maxi(min_damage, max_hp / 4)
	var roll: int = (randi_range(min_damage, max_damage) + randi_range(min_damage, max_damage)) / 2
	return maxi(min_damage, roll)

## Apply landing damage after the floor transition has completed.
static func apply_landing_damage(actor: Variant, _level: Level = null) -> int:
	var damage: int = fall_damage(actor)
	if actor != null and actor.has_method("take_damage"):
		if actor.has_method("add_buff"):
			actor.add_buff(Cripple.new())
			var bleed: Bleeding = Bleeding.new()
			bleed.set_level(fall_bleed_level(actor))
			actor.add_buff(bleed)
		actor.take_damage(damage, "chasm")
	if MessageLog:
		MessageLog.add_negative("You crash into the floor below!")
	return damage

## SPD bleeding after a fall is inversely scaled to current HP:
## round(HT / (6 + 6 * HP / HT)).
static func fall_bleed_level(actor: Variant) -> float:
	if actor == null:
		return 0.0
	var max_hp: int = _max_hp(actor)
	if max_hp <= 0:
		return 0.0
	var current_hp: int = maxi(0, int(actor.get("hp")) if actor.get("hp") != null else max_hp)
	return roundf(float(max_hp) / (6.0 + (6.0 * (float(current_hp) / float(max_hp)))))

static func _max_hp(actor: Variant) -> int:
	if actor == null:
		return 0
	return int(actor.get("ht")) if actor.get("ht") != null else int(actor.get("hp_max"))

## SPD's `Chasm.mobFall`: a non-flying mob caught by a chasm/pitfall does NOT
## descend to the next floor -- it dies to the fall. Only living mobs are
## affected (already-dead mobs are left alone).
static func mob_fall(mob: Variant) -> void:
	if mob == null or not is_instance_valid(mob):
		return
	if mob.get("is_alive") == false:
		return
	if mob.has_method("die"):
		mob.die("chasm")

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
