class_name Shaman
extends Mob
## Ranged lightning attack. Applies weakness debuff.

var zap_cooldown: int = 0
const ZAP_INTERVAL: int = 2
const ZAP_DAMAGE_MIN: int = 4
const ZAP_DAMAGE_MAX: int = 12

func _init() -> void:
	super._init()
	mob_id = "shaman"
	mob_name = "Gnoll Shaman"
	description = "An elder gnoll that hurls bolts of lightning."
	setup(35, 14, 8, 3, 10, 6)
	xp_value = 7
	max_level = 18
	awareness = 0.4
	aggro_range = 10

func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_set_state(AIState.WANDERING)
		spend_turn()
		return
	zap_cooldown = maxi(0, zap_cooldown - 1)
	var dist: int = distance_to(target.pos)
	# Zap at range
	if zap_cooldown <= 0 and dist >= 2 and dist <= 6 and can_see(target.pos):
		_zap()
		spend_attack()
		return
	# If too close, try to back up
	if dist <= 1:
		_move_away_from(target.pos)
		spend_move()
		return
	# Move closer if out of range
	if dist > 6:
		_move_toward(target.pos)
		spend_move()
		return
	spend_turn()

func _zap() -> void:
	did_visible_action = true
	if target == null:
		return
	zap_cooldown = ZAP_INTERVAL
	var dmg: int = randi_range(ZAP_DAMAGE_MIN, ZAP_DAMAGE_MAX)
	target.take_damage(dmg, self)
	if MessageLog:
		MessageLog.add_negative("The shaman zaps you with lightning!")
	# Apply weakness
	if randf() < 0.4:
		var weak: Weakness = Weakness.new()
		target.add_buff(weak)
