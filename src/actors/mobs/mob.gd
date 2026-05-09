class_name Mob
extends Char
## Base class for all enemy mobs. Provides AI state machine, aggro, loot, XP.

# --- AI States ---
enum AIState { SLEEPING, WANDERING, HUNTING, FLEEING, PASSIVE }

# --- Signals ---
@warning_ignore("unused_signal")
signal state_changed(new_state: AIState)

# --- Mob Identity ---
var mob_id: String = "mob"
var mob_name: String = "Mob"
var description: String = ""

# --- AI ---
var state: AIState = AIState.SLEEPING
var target: Char = null  # Currently chasing
var target_pos: int = -1  # Last known target position
var awareness: float = 0.1  # Chance to wake up per turn when hero is in view
var aggro_range: int = 8  # Max range to begin hunting

# --- Loot & XP ---
var xp_value: int = 1
var loot_table: Array[Dictionary] = []  # [{item_id: String, chance: float}]
var max_level: int = 30  # Hero level at which this mob gives 0 XP

# --- Properties (e.g. "UNDEAD", "BOSS", "DEMONIC") and resistances ---
@warning_ignore("unused_private_class_variable")
var _properties: Array[String] = []
@warning_ignore("unused_private_class_variable")
var _resistances: Array[String] = []
@warning_ignore("unused_private_class_variable")
var _immunities: Array[String] = []

# --- Movement ---
@warning_ignore("unused_private_class_variable")
var _path: Array[int] = []

## Set to true during act() when the mob does something the player should see
## (moves, attacks, opens a door). TurnManager checks this to decide whether
## to add a visual delay and refresh the screen.
var did_visible_action: bool = false
var last_visible_action: String = ""
var last_visible_target_pos: int = -1

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func _init() -> void:
	super._init()
	is_hero = false

## Configure base mob stats. Subclasses call this in _init or override directly.
func setup(p_hp: int, p_atk: int, p_def: int, p_dmg_min: int, p_dmg_max: int, p_armor: int, p_speed: float = 1.0) -> void:
	hp = p_hp
	hp_max = p_hp
	ht = p_hp
	attack_skill = p_atk
	defense_skill = p_def
	damage_roll_min = p_dmg_min
	damage_roll_max = p_dmg_max
	armor_value = p_armor
	base_speed = p_speed

# ---------------------------------------------------------------------------
# Turn System — timing helpers matching original Mob.java
# ---------------------------------------------------------------------------

## Attack delay. Base is 1.0; Adrenaline reduces by 1.5x.
## Subclasses override for fast/slow attackers (e.g., Thief: 0.5).
func attack_delay() -> float:
	var delay: float = 1.0
	if has_buff("Adrenaline"):
		delay /= 1.5
	return delay

## Spend time for a movement action. TurnManager.spend_energy already
## divides by the actor's cached speed, so pass raw cost of 1.0.
func spend_move() -> void:
	spend_turn(1.0)

## Spend time for an attack action: cost = attack_delay().
func spend_attack() -> void:
	spend_turn(attack_delay())

func act() -> void:
	# Safety: skip dead mobs that haven't been cleaned up from TurnManager
	if not is_alive:
		deactivate()
		return

	did_visible_action = false
	last_visible_action = ""
	last_visible_target_pos = -1
	process_buffs()
	# Refresh cached speed in TurnManager after buffs may have changed it.
	if TurnManager:
		TurnManager.refresh_speed(self)

	# Terror/Dread force fleeing state (original: checked before state machine)
	if has_buff("Terror") or has_buff("Dread"):
		_set_state(AIState.FLEEING)

	# Check if paralysed (Paralysis buff, Frozen buff, or any other source)
	# Original uses the paralysed counter, not specific buff checks
	if paralysed > 0:
		spend_turn()
		return

	match state:
		AIState.SLEEPING:
			_act_sleeping()
		AIState.WANDERING:
			_act_wandering()
		AIState.HUNTING:
			_act_hunting()
		AIState.FLEEING:
			_act_fleeing()
		AIState.PASSIVE:
			_act_passive()
	# NOTE: spend_turn() is no longer called here. Each state handler is
	# responsible for calling spend_turn() or spend_move() / spend_attack()
	# to match the original's per-action timing.

# ---------------------------------------------------------------------------
# AI State Behaviors
# ---------------------------------------------------------------------------

func _act_sleeping() -> void:
	# Check if hero is visible and roll detection (original Sleeping.detectionChance)
	# Sleeping detection: 1 / (distance + stealth) — harder to detect than wandering
	var heroes: Array[Char] = _find_visible_heroes()
	if heroes.is_empty():
		spend_turn()
		return
	var hero: Char = heroes[0]
	var dist: float = float(distance_to(hero.pos))
	var hero_stealth: float = hero.stealth() if hero.has_method("stealth") else 0.0
	var detection_chance: float = 1.0 / (dist + hero_stealth)
	if randf() < detection_chance:
		_wake_up(hero)
		spend_turn()  # original: spend(TIME_TO_WAKE_UP) which is 1f
	else:
		spend_turn()

func _act_wandering() -> void:
	# Check for heroes — with stealth detection roll matching original
	# Wandering.detectionChance: 1 / (distance/2 + stealth)
	var heroes: Array[Char] = _find_visible_heroes()
	if not heroes.is_empty():
		var hero: Char = heroes[0]
		var dist: float = float(distance_to(hero.pos))
		var hero_stealth: float = hero.stealth() if hero.has_method("stealth") else 0.0
		var detection_chance: float = 1.0 / (dist / 2.0 + hero_stealth)
		if randf() < detection_chance:
			_set_state(AIState.HUNTING)
			target = hero
			target_pos = target.pos
			if MessageLog:
				MessageLog.add_info("The %s notices you!" % mob_name)
			spend_turn()
			return
	# Wander randomly — movement costs 1/speed()
	_wander()
	spend_move()

func _act_hunting() -> void:
	# Validate target
	if target == null or not target.is_alive:
		target = null
		if target_pos >= 0 and pos != target_pos:
			_move_toward(target_pos)
			spend_move()
			return
		_set_state(AIState.WANDERING)
		spend_turn()
		return

	# Check flee condition (low HP, special behavior)
	if should_flee():
		_set_state(AIState.FLEEING)
		spend_turn()
		return

	# Check amok — attack nearest regardless
	if has_buff("Amok"):
		var nearest: Char = _find_nearest_char()
		if nearest:
			target = nearest

	# If adjacent, attack — costs attack_delay()
	if is_adjacent(target.pos):
		attack(target)
		spend_attack()
		return

	# Check if can still see target
	if can_see(target.pos):
		target_pos = target.pos
	elif pos == target_pos:
		# Reached last known position, lost the target
		_set_state(AIState.WANDERING)
		target = null
		target_pos = -1
		spend_turn()
		return

	# Move toward target — costs 1/speed()
	_move_toward(target_pos)
	spend_move()

func _act_fleeing() -> void:
	# Flee from the hero/threat
	if target == null or not target.is_alive:
		_set_state(AIState.WANDERING)
		spend_turn()
		return
	_move_away_from(target.pos)
	spend_move()

	# Stop fleeing if far enough and can't see target
	if not can_see(target.pos) and distance_to(target.pos) > aggro_range:
		_set_state(AIState.WANDERING)
		target = null

func _act_passive() -> void:
	# Do nothing (stationary mobs, NPCs)
	spend_turn()

# ---------------------------------------------------------------------------
# AI Helpers
# ---------------------------------------------------------------------------

func _wake_up(threat: Char) -> void:
	_set_state(AIState.HUNTING)
	target = threat
	target_pos = threat.pos
	if MessageLog:
		MessageLog.add_info("The %s notices you!" % mob_name)

func _set_state(new_state: AIState) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(new_state)

func _find_visible_heroes() -> Array[Char]:
	var heroes: Array[Char] = []
	if level == null:
		return heroes
	if not level.has_method("get_heroes"):
		# Fallback: check GameManager
		if GameManager and GameManager.hero and GameManager.hero is Char:
			var h: Char = GameManager.hero as Char
			if h.is_alive and can_see(h.pos):
				heroes.append(h)
		return heroes
	# Multiplayer-ready: check all heroes
	var all_heroes: Array[Char] = level.get_heroes()
	for h: Char in all_heroes:
		if h.is_alive and can_see(h.pos):
			heroes.append(h)
	return heroes

func _find_nearest_char() -> Char:
	if level == null:
		return null
	var best: Char = null
	var best_dist: int = 999
	# Check heroes
	var heroes: Array[Char] = _find_visible_heroes()
	for h: Char in heroes:
		var d: int = distance_to(h.pos)
		if d < best_dist:
			best_dist = d
			best = h
	# Could also check other mobs for amok
	return best

## Convenience: find nearest hero within aggro_range and set as target.
## Consolidates the duplicated _find_nearest_hero() pattern from special mobs.
func _acquire_nearest_hero_target() -> void:
	var nearest: Char = _find_nearest_char()
	if nearest != null and distance_to(nearest.pos) <= aggro_range:
		target = nearest
		target_pos = nearest.pos
		if state != AIState.HUNTING:
			_set_state(AIState.HUNTING)

func _wander() -> void:
	# Pick a random adjacent passable cell
	var options: Array[int] = []
	for dir: int in ConstantsData.DIRS_8:
		var next_pos: int = pos + dir
		if _can_move_to(next_pos):
			options.append(next_pos)
	if options.is_empty():
		return
	var chosen: int = options[randi() % options.size()]
	move_to(chosen)

func _move_toward(target_position: int) -> void:
	# BFS pathfinding — find the shortest path and take one step.
	# Mobs need proper pathfinding to navigate corridors and L-shaped tunnels.
	var step: int = _bfs_step_toward(target_position)
	if step >= 0 and step != pos:
		move_to(step)

## Pathfinding using Godot's AStar2D (C++ optimized).
## Returns the first step on the shortest path to target, or -1 if no path.
func _bfs_step_toward(target_position: int) -> int:
	if level == null:
		return -1
	return level.find_step(pos, target_position)

func _move_away_from(threat_pos: int) -> void:
	# Flee by picking the passable adjacent cell that maximises distance
	# from the threat. Greedy is fine for fleeing — getting stuck doesn't
	# matter much because the mob just stays put (still out of harm's way).
	var best_pos: int = pos
	var best_dist: float = 0.0
	for dir: int in ConstantsData.DIRS_8:
		var next_pos: int = pos + dir
		if not _can_move_to(next_pos):
			continue
		var dx: int = ConstantsData.pos_to_x(next_pos) - ConstantsData.pos_to_x(threat_pos)
		var dy: int = ConstantsData.pos_to_y(next_pos) - ConstantsData.pos_to_y(threat_pos)
		var dist: float = sqrt(float(dx * dx + dy * dy))
		if dist > best_dist:
			best_dist = dist
			best_pos = next_pos

	if best_pos != pos:
		move_to(best_pos)

func _can_move_to(target_position: int) -> bool:
	if not ConstantsData.is_valid_pos(target_position):
		return false
	if level and level.has_method("is_passable"):
		if not level.is_passable(target_position):
			return false
	if level and level.has_method("find_char_at"):
		if level.find_char_at(target_position) != null:
			return false
	return true

## Whether this mob should flee from combat. Base returns false — no flee behavior.
## Only specific mob subclasses (Spinner, etc.) override with custom flee conditions.
## Original Mob.java has no base flee logic; only Terror/Dread buffs trigger fleeing.
func should_flee() -> bool:
	return false

## Drop loot on death based on the loot table.
func _drop_loot() -> void:
	if level == null:
		return
	for entry: Dictionary in loot_table:
		var chance: float = entry.get("chance", 0.0)
		if randf() < chance:
			var item_id: String = entry.get("item_id", "")
			if item_id.is_empty():
				continue
			var item: Variant = Generator.create_item(item_id) if Generator else null
			if item != null and level.has_method("drop_item"):
				level.drop_item(pos, item)

# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------

## Override take_damage to wake sleeping mobs and trigger flee checks.
func take_damage(dmg: int, source: Variant = null) -> int:
	var actual: int = super.take_damage(dmg, source)
	if actual > 0 and is_alive:
		# Wake up if sleeping
		if state == AIState.SLEEPING:
			if source is Char:
				_wake_up(source as Char)
			else:
				_set_state(AIState.WANDERING)
		# Check if should flee after taking damage
		if state == AIState.HUNTING and should_flee():
			_set_state(AIState.FLEEING)
	return actual

## Override on_move to open doors when mobs walk through them.
## Also marks that the mob did something visible this turn.
func on_move(old_pos: int, new_pos: int) -> void:
	super.on_move(old_pos, new_pos)
	did_visible_action = true
	last_visible_action = "move"
	last_visible_target_pos = new_pos
	# Check if the mob stepped onto a closed door — open it
	if level:
		var terrain: int = level.terrain_at(new_pos)
		if terrain == ConstantsData.Terrain.DOOR:
			level.set_terrain(new_pos, ConstantsData.Terrain.OPEN_DOOR)
			if EventBus:
				EventBus.door_opened.emit(new_pos)

func on_attack_hit(target_char: Char, damage: int) -> void:
	did_visible_action = true
	last_visible_action = "attack"
	last_visible_target_pos = target_char.pos if target_char != null else -1
	if target_char.is_hero and EventBus:
		EventBus.hero_damaged.emit(damage, self)

func on_attack_miss(target_char: Char) -> void:
	did_visible_action = true
	last_visible_action = "attack"
	last_visible_target_pos = target_char.pos if target_char != null else -1

func _on_death(_source: Variant) -> void:
	# Check Soul Mark (Warlock subclass)
	if has_buff("SoulMark"):
		var mark: Node = get_buff("SoulMark")
		if mark.has_method("on_marked_death"):
			mark.on_marked_death(self)
	# Drop loot
	_drop_loot()
	# Grant XP to the hero (with over-level cap matching original)
	if GameManager and GameManager.hero and GameManager.hero.is_alive:
		var hero_ref: Node = GameManager.hero
		var hero_lvl: int = hero_ref.get("hero_level") if hero_ref.get("hero_level") != null else 1
		if hero_lvl > max_level:
			pass  # No XP when hero is over-leveled
		elif hero_ref.has_method("earn_xp"):
			hero_ref.earn_xp(xp_value)
	# Emit death signals
	if EventBus:
		EventBus.mob_died.emit(self)
		EventBus.mob_defeated.emit(pos, mob_name)
	# Log death
	if MessageLog:
		MessageLog.add("The %s dies." % mob_name)
	# Remove from level
	if level and level.has_method("remove_mob"):
		level.remove_mob(self)
	# Free the node
	destroy()

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

## Alert this mob — wake it up and set to hunting state.
func alert(alert_pos: int = -1) -> void:
	if not is_alive:
		return
	if alert_pos >= 0:
		target_pos = alert_pos
	var heroes: Array[Char] = _find_visible_heroes()
	if not heroes.is_empty():
		target = heroes[0]
		target_pos = target.pos
	else:
		target = null
	if state == AIState.SLEEPING or state == AIState.PASSIVE or state == AIState.WANDERING:
		_set_state(AIState.HUNTING)
	var sprite_ref: Variant = get("sprite")
	if sprite_ref != null and is_instance_valid(sprite_ref) and sprite_ref.has_method("show_alert"):
		sprite_ref.show_alert()

## Set mob state by string name (for traps and external callers).
func set_mob_state(state_name: String) -> void:
	match state_name.to_lower():
		"hunting":
			_set_state(AIState.HUNTING)
		"sleeping":
			_set_state(AIState.SLEEPING)
		"wandering":
			_set_state(AIState.WANDERING)
		"fleeing":
			_set_state(AIState.FLEEING)
		"passive":
			_set_state(AIState.PASSIVE)

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["_class"] = get_script().resource_path
	data["mob_id"] = mob_id
	data["mob_name"] = mob_name
	data["description"] = description
	data["state"] = AIState.keys()[state]
	data["target_pos"] = target_pos
	data["hp"] = hp
	data["hp_max"] = hp_max
	data["ht"] = ht
	data["shielding"] = shielding
	data["str_val"] = str_val
	data["base_speed"] = base_speed
	data["attack_skill"] = attack_skill
	data["defense_skill"] = defense_skill
	data["damage_roll_min"] = damage_roll_min
	data["damage_roll_max"] = damage_roll_max
	data["armor_value"] = armor_value
	data["is_alive"] = is_alive
	data["flying"] = flying
	data["invisible"] = invisible
	data["paralysed"] = paralysed
	data["xp_value"] = xp_value
	data["max_level"] = max_level
	data["awareness"] = awareness
	data["aggro_range"] = aggro_range
	data["buffs"] = _serialize_buffs()
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize_actor(data)
	mob_id = data.get("mob_id", mob_id)
	mob_name = data.get("mob_name", mob_name)
	description = data.get("description", description)
	var state_name: String = str(data.get("state", AIState.keys()[AIState.SLEEPING]))
	set_mob_state(state_name)
	target = null
	target_pos = int(data.get("target_pos", -1))
	hp = int(data.get("hp", hp))
	hp_max = int(data.get("hp_max", hp_max))
	ht = int(data.get("ht", ht))
	shielding = int(data.get("shielding", 0))
	str_val = int(data.get("str_val", str_val))
	base_speed = float(data.get("base_speed", base_speed))
	attack_skill = int(data.get("attack_skill", attack_skill))
	defense_skill = int(data.get("defense_skill", defense_skill))
	damage_roll_min = int(data.get("damage_roll_min", damage_roll_min))
	damage_roll_max = int(data.get("damage_roll_max", damage_roll_max))
	armor_value = int(data.get("armor_value", armor_value))
	is_alive = bool(data.get("is_alive", is_alive))
	flying = bool(data.get("flying", flying))
	invisible = int(data.get("invisible", invisible))
	paralysed = int(data.get("paralysed", paralysed))
	xp_value = int(data.get("xp_value", xp_value))
	max_level = int(data.get("max_level", max_level))
	awareness = float(data.get("awareness", awareness))
	aggro_range = int(data.get("aggro_range", aggro_range))
	_deserialize_buffs(data.get("buffs", []))
