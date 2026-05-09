class_name Warlock
extends Mob
## Ranged dark bolt attack. Heals from dealing damage.

var bolt_cooldown: int = 0
const BOLT_INTERVAL: int = 2
const BOLT_DAMAGE_MIN: int = 10
const BOLT_DAMAGE_MAX: int = 18

func _init() -> void:
	super._init()
	mob_id = "warlock"
	mob_name = "Dwarf Warlock"
	description = "A dwarven sorcerer that drains life with dark magic."
	setup(50, 18, 10, 6, 14, 8)
	xp_value = 10
	max_level = 22
	awareness = 0.5
	aggro_range = 10

func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_set_state(AIState.WANDERING)
		return
	bolt_cooldown = maxi(0, bolt_cooldown - 1)
	var dist: int = distance_to(target.pos)
	if bolt_cooldown <= 0 and dist >= 2 and dist <= 8 and can_see(target.pos):
		_dark_bolt()
		spend_attack()
		return
	if dist <= 1:
		_move_away_from(target.pos)
		spend_move()
		return
	if dist > 8:
		_move_toward(target.pos)
		spend_move()
		return
	# In range but bolt on cooldown — wait
	spend_turn()

func _dark_bolt() -> void:
	did_visible_action = true
	if target == null:
		return
	bolt_cooldown = BOLT_INTERVAL
	var dmg: int = randi_range(BOLT_DAMAGE_MIN, BOLT_DAMAGE_MAX)
	target.take_damage(dmg, self)
	@warning_ignore("integer_division")
	heal(dmg / 3)
	if MessageLog:
		MessageLog.add_negative("The warlock blasts you with dark magic!")
	# Chance to apply weakness
	if randf() < 0.3:
		var weak: Weakness = Weakness.new()
		weak.set_duration(10.0)
		target.add_buff(weak)
