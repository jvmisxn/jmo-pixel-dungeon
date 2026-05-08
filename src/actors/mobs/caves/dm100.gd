class_name DM100
extends Mob
## DM-100: A small dwarven automaton that fires lightning zaps at range.
## Mechanical mob — drops metal shards.

var zap_cooldown: int = 0
const ZAP_INTERVAL: int = 2
const ZAP_DAMAGE_MIN: int = 4
const ZAP_DAMAGE_MAX: int = 10
const ZAP_RANGE: int = 6

func _init() -> void:
	super._init()
	mob_id = "dm100"
	mob_name = "DM-100"
	description = "A small dwarven automaton that fires bolts of electricity."
	setup(30, 16, 8, 4, 10, 6, 0.9)
	xp_value = 7
	max_level = 18
	awareness = 0.5
	aggro_range = 8
	loot_table = [
		{"item_id": "metal_shard", "chance": 0.3},
		{"item_id": "gold", "chance": 0.4},
	]

func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_set_state(AIState.WANDERING)
		return

	zap_cooldown = maxi(0, zap_cooldown - 1)
	var dist: int = distance_to(target.pos)

	# Zap at range
	if zap_cooldown <= 0 and dist >= 2 and dist <= ZAP_RANGE and can_see(target.pos):
		_zap()
		return

	# If too close, back up slightly
	if dist <= 1:
		_move_away_from(target.pos)
		return

	# Move closer if out of range
	if dist > ZAP_RANGE:
		_move_toward(target.pos)

func _zap() -> void:
	did_visible_action = true
	if target == null:
		return
	zap_cooldown = ZAP_INTERVAL
	var dmg: int = randi_range(ZAP_DAMAGE_MIN, ZAP_DAMAGE_MAX)
	target.take_damage(dmg, self)
	if MessageLog:
		MessageLog.add_negative("The DM-100 zaps you with lightning!")
	# Chance to apply paralysis briefly
	if randf() < 0.2:
		var para: Paralysis = Paralysis.new()
		target.add_buff(para)

func scale_to_depth(p_depth: int) -> void:
	var scale: int = maxi(0, p_depth - 10)
	hp = 30 + scale * 4
	hp_max = hp
	ht = hp
	damage_roll_min = 4 + scale
	damage_roll_max = 10 + scale * 2
	attack_skill = 16 + scale * 2
	defense_skill = 8 + scale
