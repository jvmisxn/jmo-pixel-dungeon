class_name Wraith
extends Mob
## Wraith: Spawns from tombstones. Passes through walls.
## Can only be damaged by enchanted or upgraded weapons.
## Very low HP but high evasion.

func _init() -> void:
	super._init()
	mob_id = "wraith"
	mob_name = "Wraith"
	description = "A spectral undead that phases through walls. Only enchanted or upgraded weapons can harm it."
	setup(8, 14, 14, 2, 6, 0, 1.0)  # Low HP, high evasion, no armor
	xp_value = 5
	max_level = 20
	awareness = 1.0  # Always aware
	aggro_range = 12
	state = AIState.HUNTING  # Immediately aggressive when spawned

## Wraiths can move through walls.
func _can_move_to(target_position: int) -> bool:
	if not ConstantsData.is_valid_pos(target_position):
		return false
	# Can pass through walls — only check for other characters
	if level and level.has_method("find_char_at"):
		if level.find_char_at(target_position) != null:
			return false
	return true

## Override BFS to allow passing through walls.
func _bfs_step_toward(target_position: int) -> int:
	if level == null:
		return -1
	var queue: Array[int] = [pos]
	var came_from: Dictionary[int, int] = {pos: -1}
	var head: int = 0
	var max_steps: int = 512

	while head < queue.size() and head < max_steps:
		var current: int = queue[head]
		head += 1
		if current == target_position:
			break
		for dir: int in ConstantsData.DIRS_8:
			var next_pos: int = current + dir
			if came_from.has(next_pos):
				continue
			if not ConstantsData.is_valid_pos(next_pos):
				continue
			# Wraiths ignore wall passability — only avoid occupied cells
			if next_pos != target_position and level.find_char_at(next_pos) != null:
				continue
			came_from[next_pos] = current
			queue.append(next_pos)

	if not came_from.has(target_position):
		return -1
	var step: int = target_position
	while came_from.get(step, -1) != pos:
		step = came_from[step]
		if step < 0:
			return -1
	return step

## Override take_damage to check for enchanted/upgraded weapons.
func take_damage(dmg: int, source: Variant = null) -> int:
	# If the source is the hero, check weapon
	if source is Hero:
		var hero: Hero = source as Hero
		var weapon: Variant = hero.belongings.get_weapon() if hero.belongings else null
		if weapon:
			# Allow damage if weapon is upgraded or enchanted
			var upgraded: bool = false
			if weapon.has_method("get_level"):
				upgraded = weapon.get_level() > 0
			var enchanted: bool = false
			if weapon.has_method("is_enchanted"):
				enchanted = weapon.is_enchanted()
			if upgraded or enchanted:
				return super.take_damage(dmg, source)
		# Non-upgraded, non-enchanted weapon: immune
		if MessageLog:
			MessageLog.add_info("The wraith is immune to mundane weapons!")
		return 0
	# Non-hero damage sources (traps, magic, etc.) always work
	return super.take_damage(dmg, source)

## Wraiths never flee.
func should_flee() -> bool:
	return false

func scale_to_depth(p_depth: int) -> void:
	@warning_ignore("integer_division")
	var tier: int = 1 + p_depth / 5
	hp = 5 + tier * 3
	hp_max = hp
	ht = hp
	damage_roll_min = 1 + tier * 2
	damage_roll_max = 4 + tier * 3
	attack_skill = 10 + tier * 4
	defense_skill = 10 + tier * 4
	xp_value = 3 + tier * 2

## Static factory: spawn a wraith at a position (from tombstone).
static func spawn_at(spawn_pos: int, p_level: Variant, depth: int) -> Wraith:
	var w: Wraith = Wraith.new()
	w.pos = spawn_pos
	w.level = p_level
	w.scale_to_depth(depth)
	if p_level and p_level.has_method("add_mob"):
		p_level.add_mob(w)
	if TurnManager:
		TurnManager.add_actor(w)
	if MessageLog:
		MessageLog.add_warning("A wraith emerges from the grave!")
	return w
