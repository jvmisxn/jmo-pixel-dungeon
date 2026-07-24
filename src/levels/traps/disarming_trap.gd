class_name DisarmingTrap
extends Trap
## Throws an uncursed hero weapon away; animated statues are destroyed.

const MIN_WEAPON_THROW_DISTANCE: int = 10
const MAX_WEAPON_THROW_DISTANCE: int = 20
const MAX_THROW_CELL_TRIES: int = 50

func _init() -> void:
	trap_name = "disarming trap"
	color = Color(0.8, 0.6, 0.2)

func _do_effect(triggerer: Variant, level: Level) -> void:
	if MessageLog:
		MessageLog.add("A force knocks your weapon away!")

	if triggerer == null or level == null:
		return
	if triggerer is Mob and (triggerer as Mob).mob_id == "animated_statue":
		(triggerer as Mob).die(self)
		return
	if not (triggerer is Hero):
		return
	if triggerer.get("flying") == true:
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
	if weapon.get("cursed") == true:
		return

	var drop_pos: int = _random_weapon_drop_cell(level)
	if drop_pos < 0:
		return

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

func _random_weapon_drop_cell(level: Level) -> int:
	for _try: int in range(MAX_THROW_CELL_TRIES):
		var cell: int = level.random_passable_cell()
		if cell < 0:
			return -1
		var distance: int = level.distance(pos, cell)
		if distance >= MIN_WEAPON_THROW_DISTANCE and distance <= MAX_WEAPON_THROW_DISTANCE:
			return cell
	return -1
