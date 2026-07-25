class_name Ripper
extends Mob
## Demon that leaps to attack, dealing bonus damage on the leap strike.

var can_leap: bool = true
const LEAP_BONUS_DAMAGE: int = 12

func _init() -> void:
	super._init()
	mob_id = "ripper"
	mob_name = "Ripper Demon"
	description = "These horrific creatures are the result of the many dwarven corpses in this region being put to use by demonic forces. Rippers are emaciated ghoulish creatures that resemble dwarves, but with broken bodies and long sharp claws made of bone.\n\nRipper demons are not particularly durable, but they are agile and dangerous. They are capable of leaping great distances to quickly reach targets before goring them with their claws."
	setup(55, 22, 12, 10, 24, 8)
	xp_value = 12
	max_level = 27
	awareness = 0.5
	aggro_range = 8
	base_speed = 1.4

func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_set_state(AIState.WANDERING)
		return
	var dist: int = distance_to(target.pos)
	# Leap attack if at range 2-4
	if can_leap and dist >= 2 and dist <= 4 and can_see(target.pos):
		_leap_attack()
		return
	super._act_hunting()

func _leap_attack() -> void:
	if target == null:
		return
	did_visible_action = true
	can_leap = false
	# Move adjacent to target
	for dir: int in ConstantsData.DIRS_8:
		var land_pos: int = target.pos + dir
		if _can_move_to(land_pos):
			pos = land_pos
			# Bonus damage attack
			var dmg: int = damage_roll() + LEAP_BONUS_DAMAGE
			target.take_damage(dmg, self)
			if MessageLog:
				MessageLog.add_negative("The ripper demon swoops at you!")
			return
	# Couldn't find landing spot, move normally
	_move_toward(target.pos)

func act() -> void:
	can_leap = true
	super.act()

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["can_leap"] = can_leap
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	can_leap = bool(data.get("can_leap", can_leap))
