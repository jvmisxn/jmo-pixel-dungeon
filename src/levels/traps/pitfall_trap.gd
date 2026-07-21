class_name PitfallTrap
extends Trap
## Drops the victim to the next level (only effective in caves-like areas).

func _init() -> void:
	trap_name = "pitfall trap"
	color = Color(0.4, 0.3, 0.2)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if triggerer == null:
		return

	# Upstream PitfallTrap refuses to function where there is nowhere to drop:
	# boss levels, past the last droppable depth, or in side branches
	# (`if (Dungeon.bossLevel() || Dungeon.depth > 25 || Dungeon.branch != 0)`).
	# The trap still fires and is consumed, but nothing falls — this prevents a
	# pitfall from cheesing a boss encounter or dropping past the final depth.
	if _pit_is_sealed():
		if MessageLog:
			MessageLog.add("The ground is too solid for a pitfall trap to work here.")
		return

	if MessageLog:
		MessageLog.add_negative("The floor crumbles beneath you!")

	if Chasm.can_cross(triggerer):
		return

	if triggerer.get("is_hero") == true:
		if EventBus and EventBus.has_signal("hero_fell"):
			EventBus.hero_fell.emit(triggerer)
		else:
			Chasm.apply_landing_damage(triggerer, level)
	elif triggerer.has_method("die"):
		triggerer.die("pitfall trap")

## Whether the pitfall has nowhere to drop to (boss level or final depth), in
## which case it fires but drops nothing — mirrors SPD's boss/`depth > 25` guard.
## Branch checks are omitted: this port has no level side-branches.
func _pit_is_sealed() -> bool:
	if GameManager == null:
		return false
	if GameManager.has_method("is_boss_depth") and GameManager.is_boss_depth():
		return true
	return GameManager.depth >= ConstantsData.MAX_DEPTH
