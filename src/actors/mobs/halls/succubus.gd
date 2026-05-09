class_name Succubus
extends Mob
## Charms heroes, teleports away when threatened, heals on charm damage.

func _init() -> void:
	super._init()
	mob_id = "succubus"
	mob_name = "Succubus"
	description = "A demonic temptress that charms her victims."
	setup(60, 24, 16, 12, 22, 10)
	xp_value = 12
	max_level = 27
	awareness = 0.5
	aggro_range = 8
	base_speed = 1.3

func on_attack_hit(target_char: Char, damage: int) -> void:
	super.on_attack_hit(target_char, damage)
	# Charm on hit
	if randf() < 0.4:
		var c: Charm = Charm.create(actor_id, 5.0)
		target_char.add_buff(c)
		heal(damage)
		if MessageLog:
			MessageLog.add_negative("The succubus charms you!")

func should_flee() -> bool:
	@warning_ignore("integer_division")
	return hp < hp_max / 4

func act() -> void:
	if should_flee() and state == AIState.HUNTING:
		# Teleport away instead of normal flee
		_teleport_away()
		_set_state(AIState.FLEEING)
		spend_turn()
		return
	super.act()

func _teleport_away() -> void:
	did_visible_action = true
	if level == null:
		return
	for _attempt: int in range(20):
		var random_pos: int = randi_range(0, ConstantsData.LENGTH - 1)
		if level.has_method("is_passable") and level.is_passable(random_pos):
			if level.has_method("find_char_at") and level.find_char_at(random_pos) == null:
				pos = random_pos
				if MessageLog:
					MessageLog.add_info("The succubus vanishes in a puff of smoke!")
				return
