class_name AnimatedStatue
extends Mob
## An animated statue that wields an enchanted weapon.
## Extremely tough — these are optional mini-bosses found rarely on any floor.
## They don't pursue far from their spawn point and drop their weapon on death.

## The enchanted weapon this statue wields.
var weapon: Variant = null
## Original spawn position — statues don't wander far from their pedestal.
var spawn_pos: int = -1
## Max wander distance from spawn.
const MAX_WANDER_DIST: int = 4

func _init() -> void:
	super._init()
	mob_id = "animated_statue"
	mob_name = "Animated Statue"
	description = "A stone statue that has been brought to life by powerful magic. It wields an enchanted weapon with deadly skill."
	# Very tanky, strong attack — mini-boss level
	setup(50, 18, 12, 6, 15, 12, 0.8)  # Slow but deadly
	xp_value = 10
	max_level = 30
	awareness = 0.5
	aggro_range = 5
	state = AIState.PASSIVE  # Only attacks when attacked or bumped

## Scale stats and generate weapon based on depth.
func scale_to_depth(p_depth: int) -> void:
	@warning_ignore("integer_division")
	var tier: int = 1 + p_depth / 5
	hp = 30 + tier * 15
	hp_max = hp
	ht = hp
	attack_skill = 12 + tier * 5
	defense_skill = 8 + tier * 3
	damage_roll_min = 4 + tier * 3
	damage_roll_max = 10 + tier * 4
	armor_value = 8 + tier * 3
	xp_value = 6 + tier * 4
	spawn_pos = pos
	# Generate an enchanted weapon for this statue
	_generate_weapon(tier)

## Create a random enchanted weapon appropriate to the tier.
func _generate_weapon(tier: int) -> void:
	if not Generator:
		return
	weapon = Generator.random_weapon_for_tier(tier)
	if weapon == null:
		return
	if "level" in weapon:
		weapon.level = tier
	if weapon.has_method("enchant"):
		weapon.enchant(WeaponEnchantment.random())
	if "cursed" in weapon:
		weapon.cursed = false

## Override damage roll to use weapon if available.
func damage_roll() -> int:
	if weapon and weapon.has_method("get_damage_range"):
		var range_arr: Variant = weapon.get_damage_range()
		if range_arr is Array and range_arr.size() >= 2:
			return randi_range(range_arr[0], range_arr[1])
	return super.damage_roll()

# --- AI ---

func _act_passive() -> void:
	# Passive — just stand there. Wake on taking damage.
	pass

func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_find_nearest_hero()
		if target == null:
			state = AIState.PASSIVE
			return

	# Check distance from spawn — don't chase too far
	if spawn_pos >= 0 and level:
		var dist_from_spawn: float = level.distance(pos, spawn_pos)
		if dist_from_spawn > MAX_WANDER_DIST and not is_adjacent(target.pos):
			# Return to spawn
			_step_toward(spawn_pos)
			return

	# Attack if adjacent
	if is_adjacent(target.pos):
		attack(target)
		return

	# Move toward target
	_step_toward(target.pos)

func _act_wandering() -> void:
	# Statues don't really wander — return to spawn or go passive
	if spawn_pos >= 0 and pos != spawn_pos:
		_step_toward(spawn_pos)
	else:
		state = AIState.PASSIVE

func _act_fleeing() -> void:
	# Statues don't flee
	state = AIState.HUNTING

## Override take_damage to wake up when hit.
func take_damage(dmg: int, source: Variant = null) -> int:
	if state == AIState.PASSIVE or state == AIState.SLEEPING:
		state = AIState.HUNTING
		if source is Char:
			target = source as Char
		if MessageLog:
			MessageLog.add_warning("The statue comes to life!")
	return super.take_damage(dmg, source)

func _find_nearest_hero() -> void:
	_acquire_nearest_hero_target()

## Delegate to base Mob BFS pathfinding instead of greedy approach.
func _step_toward(target_position: int) -> void:
	_move_toward(target_position)

func _on_death(_source: Variant) -> void:
	# Drop the enchanted weapon
	if level:
		if weapon:
			level.drop_item(pos, weapon)
		level.remove_mob(self)
	if EventBus:
		EventBus.mob_died.emit(self)
	if GameManager:
		GameManager.record_stat("enemies_slain")

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["spawn_pos"] = spawn_pos
	if weapon != null and weapon.has_method("serialize"):
		data["weapon"] = weapon.serialize()
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	spawn_pos = int(data.get("spawn_pos", spawn_pos))
	weapon = null
	var weapon_data: Variant = data.get("weapon", null)
	if not (weapon_data is Dictionary):
		return
	var item_data: Dictionary = weapon_data as Dictionary
	var item_id: String = str(item_data.get("item_id", ""))
	if item_id == "":
		return
	var restored_weapon: Variant = Generator.create_item(item_id)
	if restored_weapon != null and restored_weapon.has_method("deserialize"):
		restored_weapon.deserialize(item_data)
		weapon = restored_weapon
