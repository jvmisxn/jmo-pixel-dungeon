class_name Eye
extends Mob
## Evil eye. Fires a devastating beam attack in a straight line.

var beam_cooldown: int = 0
const BEAM_INTERVAL: int = 3
const BEAM_DAMAGE: int = 30

func _init() -> void:
	super._init()
	mob_id = "eye"
	mob_name = "Evil Eye"
	description = "A floating eye that fires a disintegration beam."
	setup(75, 22, 12, 10, 20, 8)
	xp_value = 13
	max_level = 27
	awareness = 0.6
	aggro_range = 12
	base_speed = 0.8

func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_set_state(AIState.WANDERING)
		return
	beam_cooldown = maxi(0, beam_cooldown - 1)
	var dist: int = distance_to(target.pos)
	# Fire beam at range if on same row/col/diagonal
	if beam_cooldown <= 0 and dist >= 2 and can_see(target.pos) and _is_aligned(target.pos):
		_fire_beam()
		return
	# Move to get alignment
	_move_toward(target.pos)

func _is_aligned(target_position: int) -> bool:
	var x1: int = ConstantsData.pos_to_x(pos)
	var y1: int = ConstantsData.pos_to_y(pos)
	var x2: int = ConstantsData.pos_to_x(target_position)
	var y2: int = ConstantsData.pos_to_y(target_position)
	return x1 == x2 or y1 == y2 or absi(x2 - x1) == absi(y2 - y1)

func _fire_beam() -> void:
	if target == null:
		return
	beam_cooldown = BEAM_INTERVAL
	target.take_damage(BEAM_DAMAGE, self)
	if MessageLog:
		MessageLog.add_negative("The evil eye fires a death beam!")
