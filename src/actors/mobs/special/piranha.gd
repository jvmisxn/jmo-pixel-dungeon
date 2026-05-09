class_name Piranha
extends Mob
## Piranhas are water-dwelling enemies that spawn in flooded rooms.
## They move extremely fast in water but cannot leave it.
## High damage, low HP — glass cannons that punish careless water exploration.

func _init() -> void:
	super._init()
	mob_id = "piranha"
	mob_name = "Piranha"
	description = "A vicious fish with razor-sharp teeth. It lurks in the dark waters of the dungeon."
	# High attack/damage, low HP and armor — glass cannon
	setup(10, 20, 0, 4, 10, 0, 2.0)  # Very fast in water
	xp_value = 0  # No XP (they're environmental hazards, not progression enemies)
	max_level = 30
	awareness = 1.0  # Always aware
	aggro_range = 8
	state = AIState.HUNTING  # Always aggressive
	loot_table = [{"item_id": "mystery_meat", "chance": 1.0}]  # Always drop food

# --- Water Restriction ---

## Piranhas can only occupy water tiles.
func _can_move_to(dest_pos: int) -> bool:
	if level == null:
		return false
	if not level.is_passable(dest_pos):
		return false
	# Can only move in water
	return level.get_terrain(dest_pos) == ConstantsData.Terrain.WATER

## Override act_hunting to only chase targets adjacent to or in water.
func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_find_target()
		if target == null:
			state = AIState.WANDERING
			return

	# If adjacent to target, attack
	if is_adjacent(target.pos):
		attack(target)
		return

	# Path toward target, but only through water
	var best_pos: int = _find_water_step_toward(target.pos)
	if best_pos >= 0:
		move_to(best_pos)
	# else: target is out of water reach, wait

func _act_wandering() -> void:
	# Wander randomly through water tiles
	_find_target()
	if target != null:
		state = AIState.HUNTING
		return

	var neighbors: Array[int] = []
	for dir: int in ConstantsData.DIRS_8:
		var next: int = pos + dir
		if _can_move_to(next) and level.find_char_at(next) == null:
			neighbors.append(next)
	if not neighbors.is_empty():
		move_to(neighbors[randi_range(0, neighbors.size() - 1)])

func _act_sleeping() -> void:
	# Piranhas don't really sleep — they're always alert in water
	_find_target()
	if target != null:
		state = AIState.HUNTING
	else:
		state = AIState.WANDERING

## Find the best water tile step toward a target position.
func _find_water_step_toward(dest_pos: int) -> int:
	if level == null:
		return -1
	var best: int = -1
	var best_dist: float = INF
	for dir: int in ConstantsData.DIRS_8:
		var next: int = pos + dir
		if _can_move_to(next) and level.find_char_at(next) == null:
			var d: float = level.distance(next, dest_pos)
			if d < best_dist:
				best_dist = d
				best = next
	return best

## Find nearest visible hero to target.
func _find_target() -> void:
	_acquire_nearest_hero_target()

## Override to scale with depth (SPD piranhas scale).
func scale_to_depth(p_depth: int) -> void:
	@warning_ignore("integer_division")
	var tier: int = 1 + p_depth / 5
	hp = 10 + tier * 5
	hp_max = hp
	ht = hp
	damage_roll_min = 2 + tier * 2
	damage_roll_max = 5 + tier * 3
	attack_skill = 10 + tier * 5

func _on_death(_source: Variant) -> void:
	# Drop loot
	_try_drop_loot()
	# Track stat
	if GameManager:
		GameManager.record_stat("piranhas_slain")
	# Remove from level
	if level:
		level.remove_mob(self)
	if EventBus:
		EventBus.mob_died.emit(self)

func _try_drop_loot() -> void:
	if level == null:
		return
	for entry: Dictionary in loot_table:
		if randf() <= entry.get("chance", 0.0):
			var item: Variant = Generator.create_item(entry["item_id"]) if Generator else null
			if item and level.has_method("drop_item"):
				level.drop_item(pos, item)
