class_name Bee
extends Mob
## Bee: Ally mob spawned from a thrown honeypot.
## Attacks nearby enemies and follows the hero.

var ally_hero: Char = null  # The hero this bee follows
var pot_pos: int = -1  # Position the honeypot shattered (bee returns here if no enemies)

func _init() -> void:
	super._init()
	mob_id = "bee"
	mob_name = "Golden Bee"
	description = "A loyal bee that fights alongside you, stinging nearby enemies."
	setup(10, 14, 6, 2, 6, 0, 1.5)  # Fast, low HP
	xp_value = 0  # Ally — no XP
	max_level = 30
	awareness = 1.0
	aggro_range = 10
	state = AIState.HUNTING  # Always active

## Initialize the bee as an ally of the hero.
func set_ally(hero: Char, origin_pos: int) -> void:
	ally_hero = hero
	pot_pos = origin_pos
	target = null  # Will find enemies on its own

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

	# Find nearest enemy mob
	var enemy: Mob = _find_nearest_enemy()
	if enemy:
		target = enemy
		if is_adjacent(enemy.pos):
			attack(enemy)
		else:
			_move_toward(enemy.pos)
	elif ally_hero and ally_hero.is_alive:
		# No enemies — follow the hero
		if not is_adjacent(ally_hero.pos):
			_move_toward(ally_hero.pos)
	else:
		# No hero, no enemies — wander near pot position
		if pot_pos >= 0 and distance_to(pot_pos) > 3:
			_move_toward(pot_pos)
		else:
			_wander()

	spend_turn()

## Find the nearest hostile mob visible to the bee.
func _find_nearest_enemy() -> Mob:
	if level == null:
		return null
	var best: Mob = null
	var best_dist: int = 999
	var mobs: Array[Node] = level.get_mobs() if level.has_method("get_mobs") else [] as Array[Node]
	for m: Node in mobs:
		if m == self:
			continue
		if m is Mob and (m as Mob).is_alive:
			var mob: Mob = m as Mob
			# Don't attack other bees
			if mob.mob_id == "bee":
				continue
			var d: int = distance_to(mob.pos)
			if d < best_dist and d <= aggro_range and can_see(mob.pos):
				best_dist = d
				best = mob
	return best

## Bees are allies — hero attacks should not target them.
## Override take_damage to ignore hero damage.
func take_damage(dmg: int, source: Variant = null) -> int:
	if source is Hero:
		return 0  # Immune to hero damage
	return super.take_damage(dmg, source)

func _on_death(source: Variant) -> void:
	if MessageLog:
		MessageLog.add_info("The golden bee dies.")
	if EventBus:
		EventBus.mob_died.emit(self)
	if level and level.has_method("remove_mob"):
		level.remove_mob(self)
	destroy()

func scale_to_depth(p_depth: int) -> void:
	@warning_ignore("integer_division")
	var tier: int = 1 + p_depth / 5
	hp = 8 + tier * 4
	hp_max = hp
	ht = hp
	damage_roll_min = 2 + tier * 2
	damage_roll_max = 6 + tier * 3
	attack_skill = 12 + tier * 4
	defense_skill = 4 + tier * 2

## Static factory: spawn a bee from a broken honeypot.
static func spawn_at(spawn_pos: int, p_level: Variant, hero: Char, depth: int) -> Bee:
	var b: Bee = Bee.new()
	b.pos = spawn_pos
	b.level = p_level
	b.set_ally(hero, spawn_pos)
	b.scale_to_depth(depth)
	if p_level and p_level.has_method("add_mob"):
		p_level.add_mob(b)
	if TurnManager:
		TurnManager.add_actor(b)
	if MessageLog:
		MessageLog.add_positive("A golden bee emerges from the honeypot!")
	return b
