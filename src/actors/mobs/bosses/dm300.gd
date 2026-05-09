class_name DM300
extends Mob
## Third boss (depth 15). Heavy melee, toxic gas, pylon mechanic.

var gas_cooldown: int = 0
var pylons_active: int = 3
var charge_cooldown: int = 0
const GAS_INTERVAL: int = 4
const CHARGE_INTERVAL: int = 6

func _init() -> void:
	super._init()
	mob_id = "dm300"
	mob_name = "DM-300"
	description = "A colossal dwarven war machine. It vents toxic gas and charges its targets."
	setup(300, 24, 12, 15, 35, 18)
	xp_value = 60
	max_level = 20
	awareness = 1.0
	aggro_range = 99
	base_speed = 0.7
	state = AIState.HUNTING

func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_find_hero_target()
		if target == null:
			spend_turn()
			return

	gas_cooldown = maxi(0, gas_cooldown - 1)
	charge_cooldown = maxi(0, charge_cooldown - 1)

	# Supercharged when pylons active (heals)
	if pylons_active > 0:
		heal(pylons_active)

	var dist: int = distance_to(target.pos)

	# Charge attack at range
	if charge_cooldown <= 0 and dist >= 3 and dist <= 6:
		_charge_attack()
		spend_attack()
		return

	# Gas vent when adjacent
	if gas_cooldown <= 0 and dist <= 2:
		_vent_gas()
		spend_turn()
		return

	if is_adjacent(target.pos):
		attack(target)
		spend_attack()
	else:
		_move_toward(target.pos)
		spend_move()

func _charge_attack() -> void:
	charge_cooldown = CHARGE_INTERVAL
	did_visible_action = true
	if target == null:
		return
	# Move adjacent and deal extra damage
	for dir: int in ConstantsData.DIRS_8:
		var land: int = target.pos + dir
		if _can_move_to(land):
			pos = land
			var dmg: int = damage_roll() + 10
			target.take_damage(dmg, self)
			# Stun (paralysis)
			var para: Paralysis = Paralysis.new()
			para.set_duration(2.0)
			target.add_buff(para)
			if MessageLog:
				MessageLog.add_negative("DM-300 charges at you!")
			return
	_move_toward(target.pos)

func _vent_gas() -> void:
	gas_cooldown = GAS_INTERVAL
	did_visible_action = true
	if MessageLog:
		MessageLog.add_warning("DM-300 vents toxic gas!")
	for dir: int in ConstantsData.DIRS_8:
		var adj_pos: int = pos + dir
		if level and level.has_method("find_char_at"):
			var victim: Variant = level.find_char_at(adj_pos)
			if victim and victim is Char:
				var p: Poison = Poison.create(6.0)
				(victim as Char).add_buff(p)

func destroy_pylon() -> void:
	pylons_active = maxi(0, pylons_active - 1)
	if MessageLog:
		MessageLog.add_positive("A pylon is destroyed! (%d remaining)" % pylons_active)

func _find_hero_target() -> void:
	var heroes: Array[Char] = _find_visible_heroes()
	if not heroes.is_empty():
		target = heroes[0]

func _on_death(source: Variant) -> void:
	if MessageLog:
		MessageLog.add_positive("DM-300 collapses! The caves shake as a path opens.")
	if level and level.has_method("unlock_exit"):
		level.unlock_exit()
	super._on_death(source)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["gas_cooldown"] = gas_cooldown
	data["pylons_active"] = pylons_active
	data["charge_cooldown"] = charge_cooldown
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	gas_cooldown = int(data.get("gas_cooldown", gas_cooldown))
	pylons_active = int(data.get("pylons_active", pylons_active))
	charge_cooldown = int(data.get("charge_cooldown", charge_cooldown))
