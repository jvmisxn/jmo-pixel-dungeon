class_name PitfallTrap
extends Trap
## Collapses a 3x3 area of floor into the level below, one turn after it fires.
## Mirrors Shattered Pixel Dungeon's `PitfallTrap`.

func _init() -> void:
	trap_name = "pitfall trap"
	color = Color(0.4, 0.3, 0.2)

func _do_effect(triggerer: Variant, level: Level) -> void:
	# Upstream PitfallTrap refuses to function where there is nowhere to drop:
	# boss levels, past the last droppable depth, or in side branches
	# (`if (Dungeon.bossLevel() || Dungeon.depth > 25 || Dungeon.branch != 0)`).
	# The trap still fires and is consumed, but nothing falls — this prevents a
	# pitfall from cheesing a boss encounter or dropping past the final depth.
	# Branch checks are omitted: this port has no level side-branches.
	if _pit_is_sealed():
		if MessageLog:
			MessageLog.add("The ground is too solid for a pitfall trap to work here.")
		return

	# Upstream does NOT drop anyone the instant the trap fires. It attaches a
	# one-turn `DelayedPit` buff to the hero, recording the 3x3 open footprint
	# around the trap, and the floor collapses on the buff's next act — so the
	# hero AND any adjacent mob standing over the crumbling area a turn later all
	# fall together, with the hero dropping last. Attach to the hero when one
	# exists (as upstream); fall back to the triggering char so a hero-less floor
	# still collapses on schedule.
	var host: Variant = null
	if triggerer != null and is_instance_valid(triggerer) and triggerer.get("is_hero") == true:
		host = triggerer
	if host == null and GameManager != null:
		host = GameManager.get_primary_hero()
	if (host == null or not is_instance_valid(host)) and triggerer != null and is_instance_valid(triggerer):
		host = triggerer
	if host == null or not is_instance_valid(host):
		return

	var pit: DelayedPit = DelayedPit.new()
	pit.positions = Blob.blast_cells(level, pos, 1)
	pit.pit_depth = int(GameManager.depth) if GameManager != null else 0
	if host.has_method("add_buff"):
		host.add_buff(pit)
	elif host.has_method("add_child"):
		host.add_child(pit)
	else:
		pit.free()
		return

	if MessageLog:
		MessageLog.add_negative("The floor crumbles beneath you!")

## Whether the pitfall has nowhere to drop to (boss level or final depth), in
## which case it fires but drops nothing — mirrors SPD's boss/`depth > 25` guard.
## Branch checks are omitted: this port has no level side-branches.
func _pit_is_sealed() -> bool:
	if GameManager == null:
		return false
	if GameManager.has_method("is_boss_depth") and GameManager.is_boss_depth():
		return true
	return GameManager.depth >= ConstantsData.MAX_DEPTH
