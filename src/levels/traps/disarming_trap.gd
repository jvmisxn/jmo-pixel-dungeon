class_name DisarmingTrap
extends Trap
## Knocks the hero's weapon to a random nearby cell.

func _init() -> void:
	trap_name = "disarming trap"
	color = Color(0.8, 0.6, 0.2)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A force knocks your weapon away!")

	if triggerer == null:
		return

	# Try to disarm the equipped melee weapon. Weapons live on Belongings, not
	# directly on the Hero, so check there first (SPD disarms belongings.weapon).
	var belongings: Variant = triggerer.get("belongings")
	var weapon: Variant = null
	if belongings != null and belongings.has_method("get_equipped_weapon"):
		weapon = belongings.get_equipped_weapon()
	elif triggerer.has_method("get_weapon"):
		weapon = triggerer.get_weapon()
	elif triggerer.get("weapon") != null:
		weapon = triggerer.weapon

	if weapon == null:
		if MessageLog:
			MessageLog.add("You have nothing to disarm.")
		return

	# Find a random nearby passable cell to throw the weapon to
	var candidates: Array[int] = []
	for dir: int in ConstantsData.DIRS_8:
		var adj: int = pos + dir
		if adj >= 0 and adj < Level.LEN and level.is_passable(adj):
			candidates.append(adj)

	if candidates.is_empty():
		return

	var drop_pos: int = candidates[randi() % candidates.size()]

	# Unequip and drop
	if belongings != null and belongings.has_method("unequip"):
		belongings.unequip("weapon")
	elif triggerer.has_method("unequip_weapon"):
		triggerer.unequip_weapon()

	if level.has_method("drop_item"):
		level.drop_item(drop_pos, weapon)
	elif level.has_method("add_heap"):
		level.add_heap(weapon, drop_pos)

	if MessageLog:
		MessageLog.add_negative("Your weapon was thrown away!")
