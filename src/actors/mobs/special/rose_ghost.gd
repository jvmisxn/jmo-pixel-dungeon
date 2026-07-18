class_name RoseGhost
extends Mob
## Allied ghost summoned by the Dried Rose artifact.
## Follows the hero and attacks nearby hostile mobs on the current floor.

var source_artifact: Variant = null

func _init() -> void:
	super._init()
	mob_id = "rose_ghost"
	mob_name = "Ghost"
	description = "A loyal spirit bound to a dried rose."
	setup(20, 12, 8, 3, 7, 1, 1.0)
	xp_value = 0
	max_level = 30
	awareness = 1.0
	aggro_range = 8
	is_ally = true  # So other allies don't target it
	state = AIState.HUNTING
	flying = true

func configure(hero: Char, artifact_ref: Variant) -> void:
	ally_hero = hero
	source_artifact = artifact_ref
	if artifact_ref != null:
		var artifact_level: int = int(artifact_ref.get("level")) if artifact_ref.get("level") != null else 0
		var saved_hp_max: int = int(artifact_ref.get("ghost_hp_max")) if artifact_ref.get("ghost_hp_max") != null else 20
		hp_max = maxi(12, saved_hp_max)
		ht = hp_max
		hp = clampi(int(artifact_ref.get("ghost_hp")) if artifact_ref.get("ghost_hp") != null else hp_max, 1, hp_max)
		attack_skill = 12 + artifact_level * 2
		defense_skill = 8 + artifact_level
		damage_roll_min = 3 + artifact_level
		damage_roll_max = 7 + artifact_level * 2
		armor_value = maxi(1, artifact_level / 2)

func act() -> void:
	if not is_alive:
		deactivate()
		return

	process_buffs()
	if TurnManager:
		TurnManager.refresh_speed(self)

	if has_buff("Paralysis"):
		spend_turn()
		return

	var nearest_enemy: Mob = _find_nearest_enemy()
	if nearest_enemy != null:
		target = nearest_enemy
		target_pos = nearest_enemy.pos
		if is_adjacent(nearest_enemy.pos):
			attack(nearest_enemy)
			spend_attack()
			return
		_move_toward(nearest_enemy.pos)
		spend_move()
		return

	if ally_hero != null and ally_hero.is_alive:
		target = null
		target_pos = ally_hero.pos
		if not is_adjacent(ally_hero.pos):
			_move_toward(ally_hero.pos)
			spend_move()
			return

	_wander()
	spend_move()

func _find_nearest_enemy() -> Mob:
	var mob_list: Array = []
	if level == null:
		return null
	if level.has_method("get_mobs"):
		mob_list = level.get_mobs()
	elif level.get("mobs") != null:
		mob_list = level.mobs

	var best: Mob = null
	var best_dist: int = 999
	for node: Variant in mob_list:
		if node == self or not (node is Mob):
			continue
		var mob: Mob = node as Mob
		if not mob.is_alive:
			continue
		if mob is NPC:
			continue
		var other_id: String = str(mob.get("mob_id"))
		if other_id in ["rose_ghost", "sheep", "elemental"]:
			continue
		var dist: int = distance_to(mob.pos)
		if dist <= aggro_range and dist < best_dist and can_see(mob.pos):
			best = mob
			best_dist = dist
	return best

func _on_death(_source: Variant) -> void:
	if source_artifact != null:
		source_artifact.ghost_summoned = false
		source_artifact.summoned_ghost_actor_id = -1
		source_artifact.current_ghost = null
		source_artifact.ghost_hp = 0
	if level != null and level.has_method("remove_mob"):
		level.remove_mob(self)
	if TurnManager:
		TurnManager.remove_actor(self)
	destroy()

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["ally_hero_actor_id"] = ally_hero.actor_id if ally_hero != null else -1
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)

static func spawn_at(spawn_pos: int, p_level: Variant, hero: Char, artifact_ref: Variant) -> Variant:
	var ghost: RoseGhost = RoseGhost.new()
	ghost.pos = spawn_pos
	ghost.level = p_level
	ghost.configure(hero, artifact_ref)
	if p_level != null and p_level.has_method("add_mob"):
		p_level.add_mob(ghost)
	if TurnManager:
		TurnManager.add_actor(ghost)
	return ghost
