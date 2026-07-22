class_name DelayedPit
extends Buff
## One-turn-delayed pit collapse scheduled by PitfallTrap, mirroring Shattered
## Pixel Dungeon's `PitfallTrap.DelayedPit`.
##
## Upstream a pitfall does NOT drop anyone the instant it fires. It attaches this
## buff to the hero (delay 1), recording the 3x3 open footprint around the trap;
## one game-turn later the buff acts and every non-flying character still standing
## on a footprint cell falls together. Mobs die to the fall (`Chasm.mob_fall`);
## the hero drops LAST via the shared `hero_fell` descent path so the level swap
## does not cut short the mob drops.
##
## Documented divergences from upstream (kept out of this narrow slice): item
## heaps in the footprint are not dropped to the floor below (this port has no
## `Dungeon.dropToChasm` fallen-item pipeline), there is no immovable-neutral or
## ally-ignore filtering (the port lacks those char properties), and there are no
## PitfallParticle/collapse audiovisual effects.

## Footprint cells that collapse when this buff acts.
var positions: Array[int] = []
## Depth the pit was armed on; the collapse is cancelled if the hero has since
## changed floors, matching upstream's depth/branch guard.
var pit_depth: int = 0

func _init() -> void:
	buff_id = "DelayedPit"
	buff_name = "Collapsing Floor"
	buff_type = BuffType.NEUTRAL
	# Fires on the owner's next buff tick, then expires (one-turn warning delay).
	duration = 1.0
	time_left = 1.0
	revive_persists = true

func on_turn() -> void:
	_collapse()

## Drop every non-flying character still on a footprint cell. Runs off the live
## level so a character that walked into (or out of) the crumbling area during the
## warning turn is caught (or spared) exactly as upstream's per-cell `findChar`.
##
## The owner hero (this buff's target, as upstream) is resolved directly rather
## than through the level's char index so the collapse is robust even when the
## hero is not registered in `GameManager.heroes`; mobs are scanned from the live
## `level.mobs` list. Co-op secondary heroes are not dropped here (single-hero
## fall handoff only) -- a documented divergence for this narrow slice.
func _collapse() -> void:
	# The hero left the floor before the pit finished collapsing -- do nothing.
	if GameManager != null and int(GameManager.depth) != pit_depth:
		return
	var level: Variant = _resolve_level()
	if level == null or not is_instance_valid(level):
		return

	var footprint: Dictionary = {}
	for cell: int in positions:
		footprint[cell] = true

	# Mobs standing over the collapse die to the fall (upstream Chasm.mobFall).
	if level.get("mobs") != null:
		for mob: Variant in (level.mobs as Array).duplicate():
			if mob == null or not is_instance_valid(mob) or mob.get("pos") == null:
				continue
			if not footprint.has(int(mob.get("pos"))):
				continue
			if not _cell_open(level, int(mob.get("pos"))):
				continue
			if Chasm.can_cross(mob):
				continue
			Chasm.mob_fall(mob)

	# The hero falls LAST, after every mob in the footprint has dropped.
	var hero: Variant = _resolve_hero()
	if hero == null or not is_instance_valid(hero) or hero.get("pos") == null:
		return
	if Chasm.can_cross(hero):
		return
	var hero_pos: int = int(hero.get("pos"))
	if not footprint.has(hero_pos) or not _cell_open(level, hero_pos):
		return
	if EventBus and EventBus.has_signal("hero_fell"):
		EventBus.hero_fell.emit(hero)
	else:
		Chasm.apply_landing_damage(hero, level)

## Resolve the level the collapse acts on: the owner's level (reliable in tests
## and co-op), falling back to the global current level.
func _resolve_level() -> Variant:
	if target != null and is_instance_valid(target):
		var owner_level: Variant = target.get("level")
		if owner_level != null and is_instance_valid(owner_level):
			return owner_level
	if GameManager != null:
		return GameManager.current_level
	return null

## Resolve the hero the pit drops: the owner when it is the hero (as upstream),
## otherwise the primary hero.
func _resolve_hero() -> Variant:
	if target != null and is_instance_valid(target) and target.get("is_hero") == true:
		return target
	if GameManager != null:
		return GameManager.get_primary_hero()
	return null

## An in-bounds, non-solid cell the collapse can still open.
func _cell_open(level: Variant, cell: int) -> bool:
	if not ConstantsData.is_valid_pos(cell):
		return false
	if level.has_method("is_passable"):
		return level.is_passable(cell)
	return true

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["positions"] = positions.duplicate()
	data["pit_depth"] = pit_depth
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	pit_depth = int(data.get("pit_depth", pit_depth))
	positions.clear()
	var saved: Variant = data.get("positions", [])
	if saved is Array:
		for value: Variant in saved:
			positions.append(int(value))
