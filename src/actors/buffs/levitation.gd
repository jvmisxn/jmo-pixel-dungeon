class_name Levitation
extends Buff
## Allows floating over chasms and traps. Immune to gripping/rooted.

const BASE_DURATION: float = 20.0

func _init() -> void:
	buff_id = "Levitation"
	buff_name = "Levitating"
	is_debuff = false
	duration = BASE_DURATION
	time_left = BASE_DURATION
	icon_color = Color(0.8, 0.8, 1.0)

func description() -> String:
	return "Floating above the ground. Immune to traps and chasms."

## Upstream Levitation.detach(): target.flying = false then
## Dungeon.level.occupyCell(target) — a char whose levitation ends while over
## a chasm falls in immediately (hero descends, mob dies to the fall). The
## buff is unindexed before on_detach runs, so `Chasm.can_cross` here only
## stays true for chars with another flight source.
func on_detach() -> void:
	if target == null or not is_instance_valid(target):
		return
	var lvl: Variant = target.get("level")
	if lvl == null or not (lvl is Level):
		return
	var p: int = int(target.get("pos"))
	if not Chasm.is_chasm(lvl, p):
		return
	if Chasm.can_cross(target):
		return
	if target is Hero:
		if MessageLog:
			MessageLog.add_negative("You are no longer levitating and plunge into the chasm!")
		if EventBus and EventBus.has_signal("hero_fell"):
			EventBus.hero_fell.emit(target)
		else:
			Chasm.apply_landing_damage(target, lvl)
	else:
		Chasm.mob_fall(target)
