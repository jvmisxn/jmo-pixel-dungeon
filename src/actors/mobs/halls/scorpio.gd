class_name Scorpio
extends Mob
## Ranged stinger attack. Applies cripple and poison. Keeps distance.

var sting_cooldown: int = 0
const STING_INTERVAL: int = 2

func _init() -> void:
	super._init()
	mob_id = "scorpio"
	mob_name = "Scorpio"
	description = "A demonic scorpion that launches venomous stingers."
	setup(70, 20, 14, 10, 24, 12)
	xp_value = 13
	max_level = 27
	awareness = 0.5
	aggro_range = 10
	base_speed = 0.9
	loot_table = [{"item_id": "healing", "chance": 0.2}]

func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_set_state(AIState.WANDERING)
		spend_turn()
		return
	sting_cooldown = maxi(0, sting_cooldown - 1)
	var dist: int = distance_to(target.pos)
	if sting_cooldown <= 0 and dist >= 2 and dist <= 6 and can_see(target.pos):
		_ranged_sting()
		spend_attack()
		return
	if dist <= 2:
		_move_away_from(target.pos)
		spend_move()
		return
	if dist > 6:
		_move_toward(target.pos)
		spend_move()
		return
	spend_turn()

func _ranged_sting() -> void:
	if target == null:
		return
	sting_cooldown = STING_INTERVAL
	var dmg: int = randi_range(10, 18)
	target.take_damage(dmg, self)
	# Apply cripple
	var crip: Cripple = Cripple.new()
	crip.set_duration(4.0)
	target.add_buff(crip)
	# Apply poison
	if randf() < 0.5:
		var p: Poison = Poison.create(4.0)
		target.add_buff(p)
	if MessageLog:
		MessageLog.add_negative("The scorpio stings you from afar!")

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["sting_cooldown"] = sting_cooldown
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	sting_cooldown = int(data.get("sting_cooldown", sting_cooldown))
