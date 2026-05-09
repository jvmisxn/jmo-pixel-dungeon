class_name GnollTrickster
extends Mob
## Gnoll Trickster: throws items at the hero from range, flees when hero is adjacent.

var throw_cooldown: int = 0
const THROW_INTERVAL: int = 2
const THROW_RANGE: int = 5
const THROW_DAMAGE_MIN: int = 2
const THROW_DAMAGE_MAX: int = 8

func _init() -> void:
	super._init()
	mob_id = "gnoll_trickster"
	mob_name = "Gnoll Trickster"
	description = "A cunning gnoll that hurls darts and traps from afar, fleeing when cornered."
	setup(20, 12, 4, 1, 6, 2, 1.2)
	xp_value = 4
	max_level = 9
	awareness = 0.5
	aggro_range = 10
	loot_table = [
		{"item_id": "curare_dart", "chance": 0.25},
		{"item_id": "paralytic_dart", "chance": 0.15},
	]

func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_set_state(AIState.WANDERING)
		spend_turn()
		return

	throw_cooldown = maxi(0, throw_cooldown - 1)
	var dist: int = distance_to(target.pos)

	# If adjacent, flee
	if dist <= 1:
		_move_away_from(target.pos)
		spend_move()
		return

	# If in throw range and can see, throw
	if throw_cooldown <= 0 and dist >= 2 and dist <= THROW_RANGE and can_see(target.pos):
		_throw_at_target()
		spend_attack()
		return

	# Otherwise kite: stay at range 3-4
	if dist < 3:
		_move_away_from(target.pos)
		spend_move()
	elif dist > THROW_RANGE:
		_move_toward(target.pos)
		spend_move()
	else:
		spend_turn()

func _throw_at_target() -> void:
	if target == null:
		return
	throw_cooldown = THROW_INTERVAL
	var dmg: int = randi_range(THROW_DAMAGE_MIN, THROW_DAMAGE_MAX)
	target.take_damage(dmg, self)
	# Random chance to apply a debuff
	if randf() < 0.3:
		var p: Poison = Poison.create(3.0)
		target.add_buff(p)
		if MessageLog:
			MessageLog.add_negative("The gnoll trickster hits you with a poison dart!")
	else:
		if MessageLog:
			MessageLog.add_negative("The gnoll trickster throws a dart at you!")

func should_flee() -> bool:
	# Trickster always wants to flee from melee range
	if target and is_adjacent(target.pos):
		return true
	return hp < hp_max / 3

func scale_to_depth(p_depth: int) -> void:
	var scale: int = maxi(0, p_depth - 2)
	hp = 20 + scale * 3
	hp_max = hp
	ht = hp
	damage_roll_min = 1 + scale
	damage_roll_max = 6 + scale
	attack_skill = 12 + scale * 2
	defense_skill = 4 + scale
