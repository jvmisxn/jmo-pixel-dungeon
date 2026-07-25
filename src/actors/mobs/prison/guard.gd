class_name Guard
extends Mob
## Chains the hero toward itself, then attacks. Tough prison enforcer.

func _init() -> void:
	super._init()
	mob_id = "guard"
	mob_name = "Prison Guard"
	description = "Once keepers of the prison, these guards have long since become no different than the inmates. They shamble like zombies, brainlessly roaming through the halls in search of anything out of place, like you!\n\nThey carry chains around their hip, possibly used to pull in enemies to close range."
	setup(40, 16, 8, 4, 12, 7)
	xp_value = 6
	max_level = 14
	awareness = 0.4
	aggro_range = 8
	loot_table = [{"item_id": "iron_key", "chance": 0.15}]

func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_set_state(AIState.WANDERING)
		spend_turn()
		return
	# If at range 2-3, try to chain pull
	var dist: int = distance_to(target.pos)
	if dist >= 2 and dist <= 4 and can_see(target.pos) and randf() < 0.4:
		_chain_pull()
		spend_attack()
		return
	super._act_hunting()

func _chain_pull() -> void:
	if target == null:
		return
	did_visible_action = true
	# Pull target one cell closer
	if MessageLog:
		MessageLog.add_warning("The guard yanks you with chains!")
	# Move target toward guard
	var dx: int = ConstantsData.pos_to_x(pos) - ConstantsData.pos_to_x(target.pos)
	var dy: int = ConstantsData.pos_to_y(pos) - ConstantsData.pos_to_y(target.pos)
	var step_x: int = signi(dx)
	var step_y: int = signi(dy)
	var pull_pos: int = target.pos + step_x + step_y * ConstantsData.WIDTH
	if _can_move_to(pull_pos) or pull_pos == pos:
		if pull_pos != pos:
			target.pos = pull_pos
	# Apply cripple
	var crip: Cripple = Cripple.new()
	crip.set_duration(2.0)
	target.add_buff(crip)
