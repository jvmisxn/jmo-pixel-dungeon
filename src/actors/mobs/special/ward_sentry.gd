class_name WardSentry
extends Mob
## A stationary magical sentry conjured by the Wand of Warding. It never moves;
## each turn it zaps the nearest visible hostile mob within range for the wand's
## bolt damage. Immune to the hero's own attacks (via the Mob ally mechanism)
## and grants no XP. Stronger sentries come from a higher-level wand.

## Bolt damage range, seeded from the conjuring wand's get_damage(level).
var zap_min: int = 2
var zap_max: int = 5
## How far the sentry can strike (with line of sight).
var zap_range: int = 4
var _saved_ally_hero_actor_id: int = -1

func _init() -> void:
	super._init()
	mob_id = "sentry"
	mob_name = "Warding Sentry"
	description = "A conjured node of protective magic. It cannot move, but " \
		+ "zaps any enemy that strays within range."
	setup(8, 0, 1000, 0, 0, 0, 1.0)  # High evasion, no melee — it only zaps
	xp_value = 0
	max_level = 30
	awareness = 1.0
	aggro_range = 8
	is_ally = true
	state = AIState.HUNTING

## Seed HP, damage and range from the wand that created this sentry.
func configure(hero: Char, wand_level: int, dmg_min: int, dmg_max: int) -> void:
	ally_hero = hero
	zap_min = dmg_min
	zap_max = dmg_max
	zap_range = 3 + wand_level
	hp = 8 + wand_level * 8
	hp_max = hp
	ht = hp

func act() -> void:
	if not is_alive:
		deactivate()
		return
	process_buffs()
	if TurnManager:
		TurnManager.refresh_speed(self)
	if paralysed > 0:
		spend_turn()
		return
	var enemy: Mob = _find_nearest_enemy_mob()
	if enemy != null and distance_to(enemy.pos) <= zap_range and can_see(enemy.pos):
		_zap(enemy)
	# Sentries are rooted: they never move, only wait between zaps.
	spend_turn()

func _zap(enemy: Mob) -> void:
	var dmg: int = randi_range(zap_min, zap_max)
	target = enemy
	target_pos = enemy.pos
	did_visible_action = true
	last_visible_action = "attack"
	last_visible_target_pos = enemy.pos
	enemy.take_damage(dmg, self)
	if MessageLog:
		MessageLog.add("The warding sentry zaps the %s for %d damage." \
			% [enemy.mob_name if enemy.get("mob_name") else "enemy", dmg])

func _on_death(_source: Variant) -> void:
	if MessageLog:
		MessageLog.add_info("The warding sentry fades away.")
	if level != null and level.has_method("remove_mob"):
		level.remove_mob(self)
	if TurnManager:
		TurnManager.remove_actor(self)
	destroy()

## Conjure a sentry on the level and register it with the turn system.
static func spawn_at(spawn_pos: int, p_level: Variant, hero: Char,
		wand_level: int, dmg_min: int, dmg_max: int) -> Variant:
	var sentry: Variant = load("res://src/actors/mobs/special/ward_sentry.gd").new()
	sentry.pos = spawn_pos
	sentry.level = p_level
	sentry.configure(hero, wand_level, dmg_min, dmg_max)
	if p_level != null and p_level.has_method("add_mob"):
		p_level.add_mob(sentry)
	if TurnManager:
		TurnManager.add_actor(sentry)
	return sentry

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["zap_min"] = zap_min
	data["zap_max"] = zap_max
	data["zap_range"] = zap_range
	data["ally_hero_actor_id"] = ally_hero.actor_id if ally_hero != null else -1
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	zap_min = int(data.get("zap_min", zap_min))
	zap_max = int(data.get("zap_max", zap_max))
	zap_range = int(data.get("zap_range", zap_range))
	_saved_ally_hero_actor_id = int(data.get("ally_hero_actor_id", -1))
	ally_hero = null

func resolve_post_load(level_ref: Level) -> void:
	if _saved_ally_hero_actor_id < 0 or level_ref == null:
		return
	var heroes: Array[Char] = level_ref.get_heroes() if level_ref.has_method("get_heroes") else []
	for hero_ref: Char in heroes:
		if hero_ref != null and is_instance_valid(hero_ref) and hero_ref.actor_id == _saved_ally_hero_actor_id:
			ally_hero = hero_ref
			break
	_saved_ally_hero_actor_id = -1
