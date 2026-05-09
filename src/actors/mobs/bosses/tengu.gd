class_name Tengu
extends Mob
## Second boss (depth 10). Teleports around, throws shurikens, sets traps.

var teleport_cooldown: int = 0
const TELEPORT_INTERVAL: int = 3
var phase: int = 1  # Phase 2 at half HP

func _init() -> void:
	super._init()
	mob_id = "tengu"
	mob_name = "Tengu"
	description = "A masked assassin who guards the prison. Master of traps and stealth."
	setup(160, 20, 15, 6, 14, 8)
	xp_value = 40
	max_level = 15
	awareness = 1.0
	aggro_range = 99
	base_speed = 1.3
	state = AIState.HUNTING

func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_find_hero_target()
		if target == null:
			return

	teleport_cooldown = maxi(0, teleport_cooldown - 1)

	# Phase transition
	@warning_ignore("integer_division")
	if phase == 1 and hp <= hp_max / 2:
		phase = 2
		_teleport_away()
		if MessageLog:
			MessageLog.add_warning("Tengu becomes more aggressive!")
		return

	# Throw shuriken at range
	var dist: int = distance_to(target.pos)
	if dist >= 2 and dist <= 6 and can_see(target.pos):
		_throw_shuriken()
		# Teleport away after attacking
		if teleport_cooldown <= 0:
			_teleport_away()
		return

	# If adjacent, melee then teleport
	if is_adjacent(target.pos):
		attack(target)
		if teleport_cooldown <= 0:
			_teleport_away()
		return

	_move_toward(target.pos)

func _throw_shuriken() -> void:
	did_visible_action = true
	if target == null:
		return
	var dmg: int = randi_range(4, 10)
	if phase == 2:
		dmg += 4
	target.take_damage(dmg, self)
	if MessageLog:
		MessageLog.add_negative("Tengu hurls a shuriken!")

func _teleport_away() -> void:
	teleport_cooldown = TELEPORT_INTERVAL
	did_visible_action = true
	if level == null:
		return
	for _attempt: int in range(30):
		var random_pos: int = randi_range(0, ConstantsData.LENGTH - 1)
		if level.has_method("is_passable") and level.is_passable(random_pos):
			if level.has_method("find_char_at") and level.find_char_at(random_pos) == null:
				var dist_from_hero: int = 0
				if target:
					var dx: int = absi(ConstantsData.pos_to_x(random_pos) - ConstantsData.pos_to_x(target.pos))
					var dy: int = absi(ConstantsData.pos_to_y(random_pos) - ConstantsData.pos_to_y(target.pos))
					dist_from_hero = maxi(dx, dy)
				if dist_from_hero >= 3:
					pos = random_pos
					return

func _find_hero_target() -> void:
	var heroes: Array[Char] = _find_visible_heroes()
	if not heroes.is_empty():
		target = heroes[0]

func _on_death(source: Variant) -> void:
	if MessageLog:
		MessageLog.add_positive("Tengu is defeated! The prison gates open.")
	if level and level.has_method("unlock_exit"):
		level.unlock_exit()
	super._on_death(source)
