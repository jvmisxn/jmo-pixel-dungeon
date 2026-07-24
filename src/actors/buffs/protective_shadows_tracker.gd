class_name ProtectiveShadowsTracker
extends Buff
## Rogue talent effect: while invisible, slowly builds a Barrier.
## Original: Talent.ProtectiveShadowsTracker — gains barrier every 2/1 turns
## up to a max of 3/5 shielding at 1/2 talent points, detaching once the
## hero is no longer invisible or no longer has the talent.

var barrier_inc: float = 0.5

func _init() -> void:
	buff_id = "ProtectiveShadowsTracker"
	buff_name = "Protective Shadows"
	buff_type = BuffType.POSITIVE
	duration = -1
	show_in_ui = false

func on_attach() -> void:
	# Save restore appends buffs without merging, and restoring Invisibility
	# spawns a fresh tracker; drop any older instance so only one ticks.
	if target == null or not target.has_method("get_buffs"):
		return
	for other: Node in target.get_buffs():
		if other != self and other is ProtectiveShadowsTracker:
			target.remove_buff(other)

func on_turn() -> void:
	if target == null:
		return
	var points: int = 0
	if target.has_method("get_talent_level"):
		points = mini(target.get_talent_level("rogue_protective_shadows"), 2)
	if points > 0 and target.invisible > 0:
		var barrier: Barrier = target.get_buff("Barrier") as Barrier
		if barrier == null:
			barrier = target.add_buff(Barrier.new()) as Barrier
		if barrier == null:
			return
		if barrier.get_shielding() < 1 + 2 * points:
			barrier_inc += 0.5 * points
		if barrier_inc >= 1.0:
			barrier_inc = 0.0
			barrier.inc_shield(1)
		else:
			barrier.inc_shield(0)  # resets barrier decay
	else:
		target.remove_buff(self)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["barrier_inc"] = barrier_inc
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	barrier_inc = float(data.get("barrier_inc", 0.5))
