class_name SummonedElemental
extends Mob
## Temporary allied elemental created by Summon Elemental.
## Hunts nearby enemies, otherwise follows the hero for a limited duration.

var elemental_kind: String = "fire"
var turns_left: int = 12
var _saved_ally_hero_actor_id: int = -1

func _init() -> void:
	super._init()
	mob_id = "elemental"
	mob_name = "Elemental"
	description = "A summoned elemental spirit bound to aid you for a short time."
	setup(18, 16, 8, 4, 9, 1, 1.1)
	xp_value = 0
	max_level = 30
	awareness = 1.0
	aggro_range = 8
	is_ally = true  # So other allies (corrupted mobs, sentries) don't target it
	state = AIState.HUNTING

func configure(hero: Char, kind: String, depth: int) -> void:
	ally_hero = hero
	elemental_kind = kind
	if elemental_kind == "frost":
		mob_name = "Frost Elemental"
		description = "A frigid summoned spirit that slows whatever it strikes."
	else:
		elemental_kind = "fire"
		mob_name = "Fire Elemental"
		description = "A blazing summoned spirit that scorches whatever it strikes."

	var tier: int = maxi(1, int(ceil(float(depth) / 5.0)))
	hp = 14 + tier * 8
	hp_max = hp
	ht = hp
	attack_skill = 12 + tier * 4
	defense_skill = 6 + tier * 2
	damage_roll_min = 3 + tier * 2
	damage_roll_max = 7 + tier * 3
	armor_value = tier
	base_speed = 1.0 + float(tier) * 0.05
	turns_left = 10 + tier * 2

func act() -> void:
	if not is_alive:
		deactivate()
		return

	act_buffs()
	if TurnManager:
		TurnManager.refresh_speed(self)

	turns_left -= 1
	if turns_left < 0:
		if MessageLog:
			MessageLog.add_info("The %s dissipates." % mob_name.to_lower())
		if level != null and level.has_method("remove_mob"):
			level.remove_mob(self)
		if TurnManager:
			TurnManager.remove_actor(self)
		destroy()
		return

	if has_buff("Paralysis"):
		spend_turn()
		return

	var nearest_enemy: Mob = _find_nearest_enemy()
	if nearest_enemy != null:
		target = nearest_enemy
		target_pos = nearest_enemy.pos
		if is_adjacent(nearest_enemy.pos):
			attack(nearest_enemy)
		else:
			_move_toward(nearest_enemy.pos)
	elif ally_hero != null and ally_hero.is_alive:
		target = null
		target_pos = ally_hero.pos
		if not is_adjacent(ally_hero.pos):
			_move_toward(ally_hero.pos)
	else:
		_wander()

	spend_turn()

func on_attack_hit(target_char: Char, _damage: int) -> void:
	super.on_attack_hit(target_char, _damage)
	if target_char == null or not target_char.has_method("add_buff"):
		return
	if elemental_kind == "frost":
		var chill: Cripple = Cripple.new()
		chill.set_duration(4.0)
		target_char.add_buff(chill)
	else:
		var burn: Burning = Burning.new()
		target_char.add_buff(burn)

func take_damage(dmg: int, source: Variant = null) -> int:
	if source is Hero:
		return 0
	if elemental_kind == "fire" and source is Burning:
		return 0
	return super.take_damage(dmg, source)

func _find_nearest_enemy() -> Mob:
	if level == null or not level.has_method("get_mobs"):
		return null
	var best: Mob = null
	var best_dist: int = 999
	var mobs: Array = level.get_mobs()
	for node: Variant in mobs:
		if node == self:
			continue
		if not (node is Mob):
			continue
		var mob: Mob = node as Mob
		if not mob.is_alive:
			continue
		if mob is Bee or mob is Sheep or mob.get("mob_id") == "elemental":
			continue
		var dist: int = distance_to(mob.pos)
		if dist <= aggro_range and dist < best_dist and can_see(mob.pos):
			best = mob
			best_dist = dist
	return best

func _on_death(_source: Variant) -> void:
	if level != null and level.has_method("remove_mob"):
		level.remove_mob(self)
	if TurnManager:
		TurnManager.remove_actor(self)
	destroy()

static func spawn_at(spawn_pos: int, p_level: Variant, hero: Char, kind: String, depth: int) -> Variant:
	var elemental: SummonedElemental = SummonedElemental.new()
	elemental.pos = spawn_pos
	elemental.level = p_level
	elemental.configure(hero, kind, depth)
	if p_level != null and p_level.has_method("add_mob"):
		p_level.add_mob(elemental)
	if TurnManager:
		TurnManager.add_actor(elemental)
	return elemental

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["elemental_kind"] = elemental_kind
	data["turns_left"] = turns_left
	data["ally_hero_actor_id"] = ally_hero.actor_id if ally_hero != null else -1
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	elemental_kind = str(data.get("elemental_kind", elemental_kind))
	turns_left = int(data.get("turns_left", turns_left))
	_saved_ally_hero_actor_id = int(data.get("ally_hero_actor_id", -1))
	ally_hero = null
	if elemental_kind == "frost":
		mob_name = "Frost Elemental"
		description = "A frigid summoned spirit that slows whatever it strikes."
	else:
		elemental_kind = "fire"
		mob_name = "Fire Elemental"
		description = "A blazing summoned spirit that scorches whatever it strikes."

func resolve_post_load(level_ref: Level) -> void:
	if _saved_ally_hero_actor_id < 0 or level_ref == null:
		return
	var heroes: Array[Char] = level_ref.get_heroes() if level_ref.has_method("get_heroes") else []
	for hero_ref: Char in heroes:
		if hero_ref != null and is_instance_valid(hero_ref) and hero_ref.actor_id == _saved_ally_hero_actor_id:
			ally_hero = hero_ref
			break
	_saved_ally_hero_actor_id = -1
