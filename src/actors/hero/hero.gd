class_name Hero
extends Char
## The player character. Handles leveling, hunger, class abilities, input commands.
## Designed for multiplayer: multiple Hero instances can coexist. Actions go through
## a command pattern — never directly mutate game state from input.

const DoorFeature = preload("res://src/levels/features/door.gd")

# --- Signals ---
@warning_ignore("unused_signal")
signal xp_gained(amount: int)
@warning_ignore("unused_signal")
signal level_up(new_level: int)
@warning_ignore("unused_signal")
signal hero_acted(action: Dictionary)

# --- Hero-Specific State ---
var hero_class: int = ConstantsData.HeroClass.WARRIOR
var hero_subclass: int = ConstantsData.HeroSubclass.NONE
var hero_level: int = 1
var xp: int = 0
var xp_to_next: int = 10  # 5 + level * 5
var talent_points_available: int = 0
var talent_levels: Dictionary[String, int] = {}
var belongings: Belongings = null

## Multiplayer peer ID (0 = local/host, >0 = remote player).
var peer_id: int = 0

## The hero's unique name/label for multiplayer.
var hero_name: String = "Hero"

## Action queue for the command pattern. Each action is a Dictionary with
## "type" (String), "target" (int), and optional extra keys.
var _pending_action: Dictionary = {}
var _action_ready: bool = false
var _pending_surprise_attack: bool = false
var _patient_strike_ready: bool = false
var _backup_barrier_ready: bool = true
var _followup_strike_ready: bool = false

## Resting state — when true, hero automatically waits each turn until full HP
## or interrupted by a visible enemy or damage. Matches original Hero.java.
var resting: bool = false

# Override from Char
func _init() -> void:
	super._init()
	is_hero = true
	belongings = Belongings.new(self)

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Initialize hero with a given class and apply starting stats.
func init_class(chosen_class: int) -> void:
	hero_class = chosen_class
	var stats: HeroClassData.StartingStats = HeroClassData.get_starting_stats(chosen_class)
	hp = stats.hp
	hp_max = stats.hp
	ht = stats.hp
	str_val = stats.str_val
	attack_skill = stats.attack_skill
	defense_skill = stats.defense_skill
	damage_roll_min = stats.damage_min
	damage_roll_max = stats.damage_max
	hero_level = 1
	xp = 0
	xp_to_next = ConstantsData.xp_for_level(1)
	talent_points_available = 0
	talent_levels.clear()
	_pending_surprise_attack = false
	_patient_strike_ready = false
	_backup_barrier_ready = true
	_followup_strike_ready = false
	hero_name = HeroClassData.get_class_name_str(chosen_class)
	name = hero_name

	# Apply class-specific permanent buffs
	_apply_class_buffs()

## Apply permanent buffs based on hero class.
func _apply_class_buffs() -> void:
	# All heroes get regeneration and hunger
	var regen: Regeneration = Regeneration.new()
	add_buff(regen)
	var hunger: Hunger = Hunger.new()
	add_buff(hunger)

	match hero_class:
		ConstantsData.HeroClass.WARRIOR:
			# Warrior regenerates faster (handled by modifying regen rate)
			pass
		ConstantsData.HeroClass.ROGUE:
			# Rogue starts with some stealth-related buff
			pass

## Give the hero starting items based on their class.
## Called after init_class() during new game setup.
func give_starting_items() -> void:
	if belongings == null:
		belongings = Belongings.new(self)

	match hero_class:
		ConstantsData.HeroClass.WARRIOR:
			# Worn shortsword + cloth armor + food ration
			var sword: Item = Generator.create_item("worn_shortsword")
			if sword:
				belongings.equip_weapon(sword)
			var cloth: Item = Generator.create_item("cloth_armor")
			if cloth:
				belongings.equip_armor(cloth)
			var food: Item = Generator.create_item("ration")
			if food:
				belongings.add_item(food)

		ConstantsData.HeroClass.MAGE:
			# Mage's staff (worn shortsword) + cloth armor + food ration + scroll of identify
			var staff: Item = Generator.create_item("worn_shortsword")
			if staff:
				belongings.equip_weapon(staff)
			var cloth: Item = Generator.create_item("cloth_armor")
			if cloth:
				belongings.equip_armor(cloth)
			var food: Item = Generator.create_item("ration")
			if food:
				belongings.add_item(food)
			var scroll: Item = Generator.create_item("identify")
			if scroll:
				belongings.add_item(scroll)

		ConstantsData.HeroClass.ROGUE:
			# Dagger + cloth armor + food ration + cloak of shadows
			var dagger: Item = Generator.create_item("dagger")
			if dagger:
				belongings.equip_weapon(dagger)
			var cloth: Item = Generator.create_item("cloth_armor")
			if cloth:
				belongings.equip_armor(cloth)
			var food: Item = Generator.create_item("ration")
			if food:
				belongings.add_item(food)
			var cloak: Item = Generator.create_item("cloak_of_shadows")
			if cloak:
				belongings.equip_artifact(cloak)

		ConstantsData.HeroClass.HUNTRESS:
			# Gloves + spirit bow + cloth armor + food ration
			var gloves: Item = Generator.create_item("gloves")
			if gloves:
				belongings.equip_weapon(gloves)
			var bow: Item = Generator.create_item("spirit_bow")
			if bow:
				belongings.equip_spirit_bow(bow)
			var cloth: Item = Generator.create_item("cloth_armor")
			if cloth:
				belongings.equip_armor(cloth)
			var food: Item = Generator.create_item("ration")
			if food:
				belongings.add_item(food)

		ConstantsData.HeroClass.DUELIST:
			# Rapier + cloth armor + food ration
			var rapier: Item = Generator.create_item("rapier")
			if rapier:
				belongings.equip_weapon(rapier)
			var cloth: Item = Generator.create_item("cloth_armor")
			if cloth:
				belongings.equip_armor(cloth)
			var food: Item = Generator.create_item("ration")
			if food:
				belongings.add_item(food)

	# All classes start with 2 throwing stones
	var stones: Item = Generator.create_item("throwing_stone")
	if stones and "quantity" in stones:
		stones.quantity = 2
	if stones:
		belongings.add_item(stones)

# ---------------------------------------------------------------------------
# Turn System (Command Pattern)
# ---------------------------------------------------------------------------

## Called by TurnManager when it's the hero's turn.
## Sets waiting_for_input = true, then waits for submit_action().
func act() -> void:
	# Hero turn — wait for player input (TurnManager handles this via is_hero flag).
	# Buffs are processed in execute_action() after the player chooses an action.
	#
	# If resting, auto-continue resting each turn (original: Hero.java act() resting branch).
	# Rest is interrupted when HP is full or a new visible enemy appears.
	if resting:
		if hp >= hp_max:
			resting = false
			if MessageLog:
				MessageLog.add_positive("You finish resting.")
		else:
			submit_action({"type": "wait"})

## Submit an action from player input. This is the command pattern entry point.
## Actions: {type: "move", target_pos: int}, {type: "attack", target: Char},
##          {type: "use_item", item: Variant}, {type: "wait"}, etc.
func submit_action(action: Dictionary) -> void:
	_pending_action = action
	_action_ready = true
	execute_action()

## Execute the pending action and end the hero's turn.
func execute_action() -> void:
	if not _action_ready:
		return
	_action_ready = false

	# Process buffs at the start of each hero turn (hunger, regen, poison, etc.).
	# TurnManager pauses before calling act() for heroes, so we must do it here.
	process_buffs()
	var equipped_artifact: Variant = belongings.get_equipped_artifact() if belongings != null else null
	if equipped_artifact != null and equipped_artifact.has_method("on_turn"):
		equipped_artifact.on_turn(self)

	# If the hero died during buff processing (starvation, poison), skip the action
	# but still complete the turn to avoid softlocking the turn system.
	if not is_alive:
		_pending_action = {}
		spend_turn()
		if TurnManager:
			TurnManager.hero_action_complete()
		return

	# Refresh cached speed in TurnManager after buffs may have changed it.
	if TurnManager:
		TurnManager.refresh_speed(self)

	# Check if paralysed (Frozen, Paralysis) — skip action, spend turn
	if paralysed > 0:
		_pending_action = {}
		if MessageLog:
			MessageLog.add_negative("You are paralysed!")
		spend_turn()
		if TurnManager:
			TurnManager.hero_action_complete()
		return

	var action: Dictionary = _pending_action
	_pending_action = {}
	var action_type: String = action.get("type", "")

	# Any non-wait action interrupts resting (original: Hero.java act() sets resting=false)
	if action_type != "wait":
		resting = false
	if action_type != "wait" and action_type != "attack":
		_patient_strike_ready = false
	if action_type != "wait" and action_type != "attack" and action_type != "throw_item":
		_followup_strike_ready = false

	match action_type:
		"move":
			_do_move(action.get("target_pos", -1))
		"attack":
			_do_attack(action.get("target"), action.get("target_pos", -1))
		"search":
			_do_search()
		"throw_item":
			_do_throw_item(action.get("item"), action.get("target_pos", -1))
		"zap_wand":
			_do_zap_wand(action.get("item"), action.get("target_pos", -1))
		"wait":
			_do_wait()
		"use_item":
			_do_use_item(action.get("item"))
		"interact":
			_do_interact(action.get("target_pos", pos))
		"ascend":
			_do_ascend()
		"descend":
			_do_descend()
		_:
			pass  # Unknown action — skip turn

	hero_acted.emit(action)

	# Spend time based on action type. spend_turn() passes the value
	# to TurnManager.spend_energy() which already divides by cached speed,
	# so we pass the RAW action cost here (not pre-divided by speed).
	match action_type:
		"move":
			spend_turn(1.0)
		"attack":
			var atk_delay: float = _get_attack_delay()
			spend_turn(atk_delay)
		"throw_item":
			var throw_delay: float = _get_throw_delay(action.get("item"))
			spend_turn(throw_delay)
		"zap_wand":
			spend_turn(1.0)
		_:
			spend_turn(1.0)

	# Tell TurnManager we're done
	if TurnManager:
		TurnManager.hero_action_complete()

# ---------------------------------------------------------------------------
# Action Implementations
# ---------------------------------------------------------------------------

func _do_move(target_pos: int) -> void:
	if target_pos < 0:
		return
	# Check if rooted
	if has_buff("Rooted"):
		if MessageLog:
			MessageLog.add_warning("You can't move while rooted!")
		return

	# Determine the actual step to take. If already adjacent, move directly.
	# If distant, pick the best adjacent cell toward the target (one step pathfinding).
	var step_pos: int = target_pos
	if not _is_adjacent_pos(pos, target_pos):
		step_pos = _step_toward(target_pos)
		if step_pos < 0:
			return  # No path available

	# Auto-open closed doors when walking into them
	if level and level.has_method("get_terrain"):
		var terrain: int = level.get_terrain(step_pos)
		if terrain == ConstantsData.Terrain.DOOR:
			level.set_terrain(step_pos, ConstantsData.Terrain.OPEN_DOOR)
			if EventBus:
				EventBus.door_opened.emit(step_pos)
			if GameManager:
				GameManager.record_stat("doors_opened")
	if move_to(step_pos):
		if EventBus:
			EventBus.hero_moved.emit(step_pos)
		# Check terrain effects at new position
		_check_terrain_effects()

## Check if two positions are adjacent (Chebyshev distance == 1).
func _is_adjacent_pos(a: int, b: int) -> bool:
	if a == b:
		return false
	var ax: int = ConstantsData.pos_to_x(a)
	var ay: int = ConstantsData.pos_to_y(a)
	var bx: int = ConstantsData.pos_to_x(b)
	var by: int = ConstantsData.pos_to_y(b)
	return absi(ax - bx) <= 1 and absi(ay - by) <= 1

## Find the next step toward target_pos using Godot's AStar2D (C++ optimized).
## Returns the first cell on the shortest path, or -1 if no path exists.
func _step_toward(target_pos: int) -> int:
	if not level:
		return -1
	return level.find_step(pos, target_pos)


func _do_attack(target_or_null: Variant, target_pos_fallback: int = -1) -> void:
	var atk_target: Char = null
	if target_or_null is Char:
		atk_target = target_or_null as Char
	elif target_or_null == null and target_pos_fallback >= 0:
		# Resolve target from position (e.g. when target ref wasn't passed)
		if level:
			var c: Variant = level.find_char_at(target_pos_fallback)
			if c is Char:
				atk_target = c as Char
	if atk_target == null:
		return
	_pending_surprise_attack = invisible > 0 and can_surprise_attack()
	# Check if target is a disguised mimic — reveal it
	if atk_target is Mimic and (atk_target as Mimic).disguised:
		(atk_target as Mimic).reveal()
	attack(atk_target)
	if has_buff("Invisibility"):
		var invis: Node = get_buff("Invisibility")
		if invis is Invisibility:
			(invis as Invisibility).dispel()
	_pending_surprise_attack = false
	_patient_strike_ready = false
	_followup_strike_ready = false

func _do_search() -> void:
	if level == null:
		return
	var door_feature: RefCounted = DoorFeature.new()
	var found: int = int(door_feature.call("search", level, pos))
	var equipped_artifact: Variant = belongings.get_equipped_artifact() if belongings != null else null
	if equipped_artifact != null and equipped_artifact.has_method("on_search"):
		equipped_artifact.on_search()
	if found <= 0 and MessageLog:
		MessageLog.add("You search, but find nothing.")
	_patient_strike_ready = false
	_followup_strike_ready = false

func _do_throw_item(item: Variant, target_pos: int) -> void:
	if item == null or target_pos < 0 or level == null or belongings == null:
		return
	if item != belongings.weapon and item != belongings.get_equipped_spirit_bow() and not belongings.has_item(item):
		return

	if item is Bomb:
		var bomb: Bomb = item as Bomb
		if MessageLog:
			MessageLog.add("You throw the %s." % bomb.item_name)
		if EventBus:
			EventBus.item_used.emit(bomb.get_display_name())
		bomb._start_fuse(_projectile_collision_pos(target_pos), self)
		_consume_thrown_stack_item(item)
		_patient_strike_ready = false
		_followup_strike_ready = false
		return

	var collision_pos: int = _projectile_collision_pos(target_pos)
	var collision_target: Variant = level.find_char_at(collision_pos) if collision_pos >= 0 else null
	var hit_target: Char = collision_target as Char if collision_target is Char and collision_target != self else null
	var hit_landed: bool = false
	if EventBus:
		EventBus.item_used.emit(ConstantsData.get_prop(item, "item_name", "item"))

	if hit_target != null:
		hit_landed = _resolve_ranged_attack(hit_target, item)
	else:
		if MessageLog:
			MessageLog.add("The %s misses." % ConstantsData.get_prop(item, "item_name", "projectile"))

	if item is MissileWeapon and hit_landed:
		var missile: MissileWeapon = item as MissileWeapon
		if missile.has_special_effect():
			missile.apply_special_effect(hit_target)

	if item is MissileWeapon and _should_consume_thrown_item(item):
		_consume_thrown_stack_item(item)

	if item is SpiritBow and hit_landed:
		var followup_level: int = get_talent_level("huntress_followup_strike")
		if hero_class == ConstantsData.HeroClass.HUNTRESS and followup_level > 0:
			_followup_strike_ready = true
	else:
		_followup_strike_ready = false

	_patient_strike_ready = false

func _do_zap_wand(item: Variant, target_pos: int) -> void:
	if item == null or target_pos < 0 or belongings == null:
		return
	if item != belongings.misc and not belongings.has_item(item):
		return
	if item is Wand:
		(item as Wand).zap(self, target_pos)
	_patient_strike_ready = false
	_followup_strike_ready = false

func _projectile_collision_pos(target_pos: int) -> int:
	if level == null:
		return target_pos
	var occupied: Array[bool] = []
	occupied.resize(level.passable.size())
	occupied.fill(false)
	for hero_ref: Char in level.get_heroes():
		if hero_ref != null and hero_ref != self and hero_ref.is_alive:
			occupied[hero_ref.pos] = true
	for mob_ref: Node in level.mobs:
		if mob_ref is Char and mob_ref != self and (mob_ref as Char).is_alive:
			occupied[(mob_ref as Char).pos] = true
	var path: Ballistica = Ballistica.new()
	path.cast(pos, target_pos, level.passable, Ballistica.PROJECTILE, occupied, ConstantsData.WIDTH)
	return path.collision_pos

func _resolve_ranged_attack(target: Char, item: Variant) -> bool:
	if target == null or item == null:
		return false
	var acc_multi: float = 1.0
	if item.has_method("accuracy_factor"):
		acc_multi = item.accuracy_factor(self)
	if not Char.hit(self, target, acc_multi):
		on_attack_miss(target)
		return false

	var damage: int = 1
	if item.has_method("damage_roll"):
		damage = item.damage_roll(self)
	for b: Node in _buffs:
		if b.has_method("modify_damage"):
			damage = b.modify_damage(damage)

	var effective_damage: int = target.defense_proc(self, damage)
	if effective_damage >= 0:
		effective_damage = maxi(effective_damage - target.dr_roll(), 0)
		if target.has_buff("Vulnerable"):
			effective_damage = int(effective_damage * 1.33)
		if item.has_method("proc_enchantment"):
			effective_damage = item.proc_enchantment(self, target, effective_damage)

	target.take_damage(effective_damage, self)
	on_attack_hit(target, effective_damage)
	return true

func _get_throw_delay(item: Variant) -> float:
	if item != null and item.has_method("speed_factor"):
		return item.speed_factor(self)
	return 1.0

func _should_consume_thrown_item(item: Variant) -> bool:
	if item is MissileWeapon and (item as MissileWeapon).does_return():
		return false
	return item is MissileWeapon or item is Bomb

func _consume_thrown_stack_item(item: Variant) -> void:
	if item == null:
		return
	if item.get("quantity") != null:
		item.quantity -= 1
		if item.quantity <= 0:
			belongings.remove_item(item)

func get_auto_ranged_action(target_pos: int) -> Dictionary:
	var ranged_item: Variant = _get_auto_ranged_item(target_pos)
	if ranged_item == null:
		return {}
	return {"type": "throw_item", "item": ranged_item, "target_pos": target_pos}

func _get_auto_ranged_item(target_pos: int) -> Variant:
	if hero_class != ConstantsData.HeroClass.HUNTRESS or belongings == null or level == null:
		return null
	if target_pos < 0 or distance_to(target_pos) > 8:
		return null
	var bow: Item = belongings.get_equipped_spirit_bow()
	if bow == null:
		return null
	if _projectile_collision_pos(target_pos) != target_pos:
		return null
	return bow

## Emit damage signal so game_scene shows floating damage number on the mob.
func on_attack_hit(target_char: Char, damage: int) -> void:
	if EventBus and target_char != null:
		EventBus.mob_damaged.emit(target_char.pos, damage)
	if AudioManager:
		AudioManager.play_sfx("hit")


## Emit miss signal so game_scene shows "0" floating text on the mob.
func on_attack_miss(target_char: Char) -> void:
	if EventBus and target_char != null:
		EventBus.hero_attack_missed.emit(target_char.pos)


func _do_wait() -> void:
	# Silent single-turn wait — hero does not show a message
	if hero_class == ConstantsData.HeroClass.DUELIST and get_talent_level("duelist_patient_strike") > 0:
		_patient_strike_ready = true


## Rest until full HP or interrupted. Matches original Hero.rest(boolean).
## full_rest=false: single wait turn with "..." status. full_rest=true: continuous rest.
func rest(full_rest: bool) -> void:
	if not full_rest:
		# Single wait — show status message on sprite if available
		if MessageLog:
			MessageLog.add("...")
	resting = full_rest
	submit_action({"type": "wait"})


## Called when a new visible enemy is detected while resting. Interrupts rest.
func interrupt() -> void:
	if resting:
		resting = false
		if MessageLog:
			MessageLog.add_warning("Something wakes you!")

func _do_use_item(item: Variant) -> void:
	if item == null:
		return
	if item.has_method("execute"):
		item.execute(self)
	elif item.has_method("use"):
		item.use(self)

func _do_interact(target_pos: int) -> void:
	if level == null:
		return
	# Interact with terrain (open doors, search, pick up items)
	if level.has_method("get_terrain"):
		var terrain: int = level.get_terrain(target_pos)
		match terrain:
			ConstantsData.Terrain.DOOR, ConstantsData.Terrain.LOCKED_DOOR, ConstantsData.Terrain.CRYSTAL_DOOR:
				var door_feature: RefCounted = DoorFeature.new()
				door_feature.call("open", level, target_pos, self)

func _do_ascend() -> void:
	# Level transitions are handled by GameScene._handle_ascend().
	pass

func _do_descend() -> void:
	# Level transitions are handled by GameScene._handle_descend().
	pass

# ---------------------------------------------------------------------------
# Terrain Effects
# ---------------------------------------------------------------------------

## Check the terrain at the hero's current position and apply any effects.
## Called after the hero moves to a new tile.
func _check_terrain_effects() -> void:
	if level == null or not level.has_method("get_terrain"):
		return
	var terrain: int = level.get_terrain(pos)

	match terrain:
		ConstantsData.Terrain.TRAP, ConstantsData.Terrain.SECRET_TRAP:
			# Trigger the trap at this position
			if level.has_method("trigger_trap"):
				level.trigger_trap(pos, self)
			elif MessageLog:
				MessageLog.add_warning("You triggered a trap!")
			# After triggering, the trap becomes inactive
			if level.has_method("set_terrain"):
				level.set_terrain(pos, ConstantsData.Terrain.INACTIVE_TRAP)

		ConstantsData.Terrain.CHASM:
			# Falling into a chasm deals massive damage (usually lethal)
			if MessageLog:
				MessageLog.add_negative("You fall into the chasm!")
			take_damage(hp_max, null)

		ConstantsData.Terrain.WATER:
			# Water extinguishes fire
			if has_buff("Burning"):
				remove_buff_by_id("Burning")
				if MessageLog:
					MessageLog.add("The water extinguishes the flames!")

		ConstantsData.Terrain.HIGH_GRASS:
			# Trampling high grass has a chance to drop seeds/dew
			if level.has_method("set_terrain"):
				level.set_terrain(pos, ConstantsData.Terrain.FURROWED_GRASS)
			# Seed/dew drop handled by level or loot system
			if EventBus:
				EventBus.hero_trampled_grass.emit(pos)
			on_trampled_grass()

		ConstantsData.Terrain.GRASS:
			# Warden subclass gains barkskin from grass
			pass

		ConstantsData.Terrain.EMBERS:
			# Embers can ignite the hero
			if not has_buff("Fire Immunity") and not has_buff("Brimstone"):
				if randf() < 0.5:
					var burning: Burning = Burning.new()
					add_buff(burning)
					if MessageLog:
						MessageLog.add_negative("The hot embers set you ablaze!")

		ConstantsData.Terrain.ENTRANCE:
			# Standing on entrance — ascending is possible
			pass

		ConstantsData.Terrain.EXIT:
			# Standing on exit — descending is possible
			pass

		ConstantsData.Terrain.WELL:
			# Wells can be interacted with (handled by interact action)
			pass

		ConstantsData.Terrain.ALCHEMY:
			# Alchemy pot — interaction handled separately
			pass

		ConstantsData.Terrain.SIGN:
			# Read the sign
			if level.has_method("get_sign_text"):
				var text: String = level.get_sign_text(pos)
				if text != "" and MessageLog:
					MessageLog.add(text)


## Check if the hero has a key of the given type on the current depth.
func has_key(key_type: String) -> bool:
	if belongings == null:
		return false
	for item: Variant in belongings.backpack:
		if item != null and ConstantsData.get_prop(item, "item_id", "") == (key_type + "_key"):
			# Check depth match for iron keys
			if key_type == "iron" and ConstantsData.get_prop(item, "depth", -1) != GameManager.depth:
				continue
			return true
	return false

## Use (consume) a key of the given type from inventory.
func use_key(key_type: String) -> void:
	if belongings == null:
		return
	for item: Variant in belongings.backpack:
		if item != null and ConstantsData.get_prop(item, "item_id", "") == (key_type + "_key"):
			if key_type == "iron" and ConstantsData.get_prop(item, "depth", -1) != GameManager.depth:
				continue
			belongings.remove_item(item)
			if MessageLog:
				MessageLog.add("You use the %s." % ConstantsData.get_prop(item, "item_name", "key"))
			return

## Drop a random item from the backpack (used by Chasm fall).
func drop_random_item() -> void:
	if belongings == null or belongings.backpack.is_empty():
		return
	var idx: int = randi() % belongings.backpack.size()
	var item: Variant = belongings.backpack[idx]
	belongings.remove_item(item)
	if level and level.has_method("drop_item"):
		level.drop_item(pos, item)
	if MessageLog:
		MessageLog.add("You lost your %s!" % ConstantsData.get_prop(item, "item_name", "item"))

# ---------------------------------------------------------------------------
# XP & Leveling
# ---------------------------------------------------------------------------

## Award XP to the hero. Called by mob death, potions, etc.
func earn_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	xp_gained.emit(amount)
	if MessageLog:
		MessageLog.add_positive("+%d XP" % amount)

	# Check for level up(s)
	while xp >= xp_to_next and hero_level < ConstantsData.MAX_HERO_LEVEL:
		xp -= xp_to_next
		hero_level += 1
		xp_to_next = ConstantsData.xp_for_level(hero_level)
		talent_points_available += 1

		# Level up bonuses: +5 HP, +1 attack, +1 defense
		# Original updateHT(true): HP += max(newHT - oldHT, 0); HP = min(HP, HT)
		# Does NOT full heal — only adds the HP gained from the level
		var old_ht: int = ht
		hp_max += 5
		ht += 5
		hp += maxi(ht - old_ht, 0)
		hp = mini(hp, hp_max)
		attack_skill += 1
		defense_skill += 1

		level_up.emit(hero_level)
		if MessageLog:
			MessageLog.add_positive("Welcome to level %d!" % hero_level)
		if AudioManager:
			AudioManager.play_sfx("levelup")
		if EventBus:
			EventBus.hero_stats_changed.emit()
		if GameManager:
			GameManager.add_score(hero_level * 50)

func get_talents() -> Array[TalentData.TalentInfo]:
	return TalentData.get_talents_for(hero_class, hero_subclass)

func get_talent_level(talent_id: String) -> int:
	return talent_levels.get(talent_id, 0)

func can_upgrade_talent(talent_id: String) -> bool:
	if talent_points_available <= 0:
		return false
	var talent: TalentData.TalentInfo = TalentData.get_talent(hero_class, talent_id, hero_subclass)
	if talent == null:
		return false
	return get_talent_level(talent_id) < talent.max_points

func upgrade_talent(talent_id: String) -> bool:
	if not can_upgrade_talent(talent_id):
		return false
	talent_levels[talent_id] = get_talent_level(talent_id) + 1
	talent_points_available -= 1
	if EventBus:
		EventBus.hero_stats_changed.emit()
	if MessageLog:
		var talent: TalentData.TalentInfo = TalentData.get_talent(hero_class, talent_id, hero_subclass)
		if talent != null:
			MessageLog.add_positive("%s improved to %d." % [talent.name, talent_levels[talent_id]])
	return true


func on_item_picked_up(item: Item) -> void:
	if item == null:
		return

	var warrior_hypothesis: int = get_talent_level("warrior_tested_hypothesis")
	if hero_class == ConstantsData.HeroClass.WARRIOR and warrior_hypothesis > 0:
		if item.item_id == "healing" or item.item_id == "identify":
			_maybe_identify_pickup(item, 0.50 * warrior_hypothesis, "Your practical instincts reveal the %s.")

	var mage_intuition: int = get_talent_level("mage_scholars_intuition")
	if hero_class == ConstantsData.HeroClass.MAGE and mage_intuition > 0:
		if item.category == ConstantsData.ItemCategory.SCROLL or item.category == ConstantsData.ItemCategory.WAND:
			_maybe_identify_pickup(item, 0.30 * mage_intuition, "Arcane intuition reveals the %s.")

	var rogue_intuition: int = get_talent_level("rogue_thiefs_intuition")
	if hero_class == ConstantsData.HeroClass.ROGUE and rogue_intuition > 0:
		if item.category == ConstantsData.ItemCategory.RING:
			_maybe_identify_pickup(item, 0.35 * rogue_intuition, "Your thief's intuition reveals the %s.")

	var huntress_intuition: int = get_talent_level("huntress_survivalists_intuition")
	if hero_class == ConstantsData.HeroClass.HUNTRESS and huntress_intuition > 0:
		if item is MissileWeapon or item is SpiritBow:
			_maybe_identify_pickup(item, 0.35 * huntress_intuition, "Your survival instincts reveal the %s.")

	var duelist_intuition: int = get_talent_level("duelist_adventurers_intuition")
	if hero_class == ConstantsData.HeroClass.DUELIST and duelist_intuition > 0:
		if item.category == ConstantsData.ItemCategory.WEAPON or item.category == ConstantsData.ItemCategory.ARMOR:
			_maybe_identify_pickup(item, 0.25 * duelist_intuition, "Your intuition reveals the %s.")


func on_food_eaten(_food: Food, hunger_before: float, hp_before: int, hp_max_before: int) -> void:
	var changed_state: bool = false

	var warrior_meal: int = get_talent_level("warrior_hearty_meal")
	if hero_class == ConstantsData.HeroClass.WARRIOR and warrior_meal > 0:
		if hp_max_before > 0 and float(hp_before) >= float(hp_max_before) * 0.75:
			var barrier: Barrier = add_buff(Barrier.new()) as Barrier
			if barrier != null:
				barrier.set_shield(2 + warrior_meal * 2)
				changed_state = true
			if MessageLog and barrier != null:
				MessageLog.add_positive("A hearty meal fortifies you.")

	var mage_meal: int = get_talent_level("mage_empowering_meal")
	if hero_class == ConstantsData.HeroClass.MAGE and mage_meal > 0:
		var recharge: Recharging = Recharging.new()
		recharge.set_duration(4.0 + 4.0 * mage_meal)
		add_buff(recharge)
		changed_state = true

	var rogue_rations: int = get_talent_level("rogue_cached_rations")
	if hero_class == ConstantsData.HeroClass.ROGUE and rogue_rations > 0:
		var hunger_buff: Variant = get_buff("Hunger")
		if hunger_buff != null and hunger_buff.has_method("satisfy"):
			var bonus_food: float = 50.0 * rogue_rations
			hunger_buff.satisfy(bonus_food)
			changed_state = true
			if hunger_before > 0.0 and MessageLog:
				MessageLog.add_positive("You make the meal last longer.")

	if changed_state and EventBus:
		EventBus.hero_stats_changed.emit()


func on_trampled_grass() -> void:
	if level == null:
		return

	var bounty_level: int = get_talent_level("huntress_natures_bounty")
	var dew_chance: float = 0.18
	var seed_chance: float = 0.0

	if hero_class == ConstantsData.HeroClass.HUNTRESS and bounty_level > 0:
		dew_chance += 0.12 * bounty_level
		seed_chance = 0.10 * bounty_level

	if randf() < clampf(dew_chance, 0.0, 1.0):
		var dew: Dewdrop = Generator.create_item("dewdrop") as Dewdrop
		if dew != null:
			dew.on_pickup(self)
		return

	if seed_chance > 0.0 and randf() < clampf(seed_chance, 0.0, 1.0) and not Generator.SEEDS.is_empty():
		var seed_id: String = Generator.SEEDS[randi_range(0, Generator.SEEDS.size() - 1)]
		var seed_item: Item = Generator.create_item(seed_id)
		if seed_item != null and level.has_method("drop_item"):
			level.drop_item(pos, seed_item)
			if MessageLog:
				MessageLog.add_positive("You find %s in the grass." % seed_item.get_display_name())


func _maybe_identify_pickup(item: Item, chance: float, message_template: String) -> void:
	if item == null or item.is_identified():
		return
	if randf() >= clampf(chance, 0.0, 1.0):
		return
	item.identify()
	if MessageLog:
		MessageLog.add_positive(message_template % item.get_display_name())

func can_surprise_attack() -> bool:
	if belongings != null:
		var weapon: Variant = belongings.get_equipped_weapon()
		if weapon != null and weapon.has_method("can_surprise_attack"):
			return weapon.can_surprise_attack(self)
	return super.can_surprise_attack()

func attack_proc(target_char: Char, damage: int) -> int:
	var result: int = super.attack_proc(target_char, damage)

	var sucker_punch_level: int = get_talent_level("rogue_sucker_punch")
	if hero_class == ConstantsData.HeroClass.ROGUE and sucker_punch_level > 0 and _pending_surprise_attack:
		result = roundi(float(result) * (1.15 + 0.15 * sucker_punch_level))

	var patient_strike_level: int = get_talent_level("duelist_patient_strike")
	if hero_class == ConstantsData.HeroClass.DUELIST and patient_strike_level > 0 and _patient_strike_ready:
		result = roundi(float(result) * (1.10 + 0.15 * patient_strike_level))

	var followup_strike_level: int = get_talent_level("huntress_followup_strike")
	if hero_class == ConstantsData.HeroClass.HUNTRESS and followup_strike_level > 0 and _followup_strike_ready:
		result = roundi(float(result) * (1.10 + 0.15 * followup_strike_level))

	if belongings != null:
		var weapon: Variant = belongings.get_equipped_weapon()
		if weapon != null and weapon.has_method("proc_enchantment"):
			result = weapon.proc_enchantment(self, target_char, result)

	_followup_strike_ready = false
	return maxi(0, result)

func defense_proc(attacker: Char, damage: int) -> int:
	var result: int = super.defense_proc(attacker, damage)
	if result < 0:
		return result
	if belongings != null:
		var armor: Variant = belongings.get_equipped_armor()
		if armor != null and armor.has_method("proc_glyph"):
			result = armor.proc_glyph(enemy, self, result)
	return result

func serialize() -> Dictionary:
	var data: Dictionary = serialize_actor()
	data["hero_class"] = hero_class
	data["hero_subclass"] = hero_subclass
	data["hero_level"] = hero_level
	data["xp"] = xp
	data["xp_to_next"] = xp_to_next
	data["talent_points_available"] = talent_points_available
	data["talent_levels"] = talent_levels.duplicate(true)
	data["hp"] = hp
	data["hp_max"] = hp_max
	data["ht"] = ht
	data["str_val"] = str_val
	data["attack_skill"] = attack_skill
	data["defense_skill"] = defense_skill
	data["damage_roll_min"] = damage_roll_min
	data["damage_roll_max"] = damage_roll_max
	data["armor_value"] = armor_value
	data["is_alive"] = is_alive
	data["base_speed"] = base_speed
	data["hero_name"] = hero_name
	data["patient_strike_ready"] = _patient_strike_ready
	data["backup_barrier_ready"] = _backup_barrier_ready
	data["followup_strike_ready"] = _followup_strike_ready
	data["belongings"] = belongings.serialize() if belongings != null else {}
	return data

func deserialize(data: Dictionary) -> void:
	deserialize_actor(data)
	hero_class = data.get("hero_class", ConstantsData.HeroClass.WARRIOR)
	hero_subclass = data.get("hero_subclass", ConstantsData.HeroSubclass.NONE)
	hero_level = data.get("hero_level", 1)
	xp = data.get("xp", 0)
	xp_to_next = data.get("xp_to_next", ConstantsData.xp_for_level(hero_level))
	talent_points_available = data.get("talent_points_available", 0)
	talent_levels = data.get("talent_levels", {}).duplicate(true)
	hp = data.get("hp", 1)
	hp_max = data.get("hp_max", hp)
	ht = data.get("ht", hp_max)
	str_val = data.get("str_val", 10)
	attack_skill = data.get("attack_skill", 10)
	defense_skill = data.get("defense_skill", 5)
	damage_roll_min = data.get("damage_roll_min", 1)
	damage_roll_max = data.get("damage_roll_max", 4)
	armor_value = data.get("armor_value", 0)
	is_alive = data.get("is_alive", true)
	base_speed = data.get("base_speed", 1.0)
	hero_name = data.get("hero_name", HeroClassData.get_class_name_str(hero_class))
	_pending_surprise_attack = false
	_patient_strike_ready = data.get("patient_strike_ready", false)
	_backup_barrier_ready = data.get("backup_barrier_ready", true)
	_followup_strike_ready = data.get("followup_strike_ready", false)
	name = hero_name
	if belongings == null:
		belongings = Belongings.new(self)
	var belongings_data: Dictionary = data.get("belongings", {})
	if not belongings_data.is_empty():
		belongings.deserialize(belongings_data)

# ---------------------------------------------------------------------------
# Damage & Death Overrides
# ---------------------------------------------------------------------------

## Override take_damage to emit hero_stats_changed so the HP bar updates.
func take_damage(amount: int, source: Variant = null) -> int:
	var hp_before: int = hp
	var actual: int = super.take_damage(amount, source)
	if actual > 0:
		var backup_barrier: int = get_talent_level("mage_backup_barrier")
		if hero_class == ConstantsData.HeroClass.MAGE and backup_barrier > 0 and _backup_barrier_ready:
			var threshold: int = int(ceil(float(hp_max) * 0.5))
			if hp_before > threshold and hp <= threshold:
				var barrier: Barrier = add_buff(Barrier.new()) as Barrier
				if barrier != null:
					barrier.set_shield(2 + backup_barrier * 2)
					_backup_barrier_ready = false
					if MessageLog:
						MessageLog.add_positive("A backup barrier springs into place.")
	if actual > 0 and EventBus:
		EventBus.hero_stats_changed.emit()
	return actual

## Override heal to emit hero_stats_changed so the HP bar updates.
func heal(amount: int) -> void:
	super.heal(amount)
	if hp > int(ceil(float(hp_max) * 0.5)):
		_backup_barrier_ready = true
	if EventBus:
		EventBus.hero_stats_changed.emit()

## Override _on_death to emit the EventBus.hero_died signal so the game
## transitions to the death screen.
func _on_death(source: Variant) -> void:
	super._on_death(source)
	if EventBus:
		EventBus.hero_died.emit()

# ---------------------------------------------------------------------------
# View Distance
# ---------------------------------------------------------------------------

## Return the hero's effective shadowcasting view distance.
## MindVision is handled separately in Level.update_fov() as a mob-overlay,
## not by extending the shadowcast radius (which can't see through walls).
## Blindness disables shadowcasting entirely; sense-only vision is applied
## in Level.update_fov() instead.
func get_view_distance() -> int:
	# Blindness disables normal sight — update_fov handles sense fallback
	if has_buff("Blindness"):
		return 0
	var dist: int = ConstantsData.VIEW_DISTANCE
	# Huntress gets +2 view distance
	if hero_class == ConstantsData.HeroClass.HUNTRESS:
		dist += 2
	# Torch buff adds +2
	if has_buff("Torch"):
		dist += 2
	return dist

## Return true if the hero is considered "sighted" (can use shadowcasting).
## False when blinded or affected by Shadows.
func is_sighted() -> bool:
	return not has_buff("Blindness") and is_alive

# ---------------------------------------------------------------------------
# Attack Delay
# ---------------------------------------------------------------------------

## Return the hero's attack delay based on equipped weapon.
## Original: Hero.attackDelay() = weapon.speedFactor(hero), default 1.0.
## Fast weapons like dagger have < 1.0, slow weapons like glaive > 1.0.
func _get_attack_delay() -> float:
	if belongings:
		var equipped_weapon: Variant = belongings.get_equipped_weapon()
		if equipped_weapon and equipped_weapon.has_method("speed_factor"):
			return equipped_weapon.speed_factor(self)
	return 1.0

# ---------------------------------------------------------------------------
# Damage / Heal Overrides (emit HUD update signals)
# ---------------------------------------------------------------------------

## Override damage_roll to use equipped weapon's damage calculation.
## Original SPD: Hero.damageRoll() delegates to weapon.damageRoll(this).
func damage_roll() -> int:
	if belongings:
		var weapon: Variant = belongings.get_equipped_weapon()
		if weapon and weapon.has_method("damage_roll"):
			var dmg: int = weapon.damage_roll(self)
			# Apply buff modifiers (same as base Char.damage_roll)
			for b: Node in _buffs:
				if b.has_method("modify_damage"):
					dmg = b.modify_damage(dmg)
			return maxi(0, dmg)
	return super.damage_roll()

## Override dr_roll to use equipped armor's DR calculation.
## Original SPD: Hero.drRoll() delegates to armor.DRRoll() + barkskin.
func dr_roll() -> int:
	var dr: int = 0
	# Barkskin bonus (Warden subclass, Earthroot plant)
	var bark_lvl: int = Barkskin.current_level(self)
	if bark_lvl > 0:
		@warning_ignore("integer_division")
		dr += (randi_range(0, bark_lvl) + randi_range(0, bark_lvl)) / 2
	# Use equipped armor's dr_roll if available
	if belongings:
		var equipped_armor: Variant = belongings.get_equipped_armor()
		if equipped_armor and equipped_armor.has_method("dr_roll"):
			dr += equipped_armor.dr_roll()
			return dr
	# Fallback to base armor_value
	var armor: int = effective_armor()
	if armor > 0:
		@warning_ignore("integer_division")
		dr += (randi_range(0, armor) + randi_range(0, armor)) / 2
	return dr

## Override get_speed to include armor speed penalty/bonus.
## Original: Hero.speed() calls super.speed() then multiplies by armor.speedFactor(hero).
func get_speed() -> float:
	var spd: float = super.get_speed()
	if belongings:
		var equipped_armor: Variant = belongings.get_equipped_armor()
		if equipped_armor and equipped_armor.has_method("speed_factor"):
			spd *= equipped_armor.speed_factor(self)
	return maxf(0.1, spd)

## Override accuracy to factor in weapon accuracy and hero level.
## Original: STARTING_ACC * weapon.accuracyFactor(hero) + hero.lvl
func accuracy() -> int:
	var base_acc: float = float(attack_skill) + hero_level
	if belongings:
		var weapon: Variant = belongings.get_equipped_weapon()
		if weapon and weapon.has_method("accuracy_factor"):
			base_acc *= weapon.accuracy_factor(self)
	var acc: int = roundi(base_acc)
	for b: Node in _buffs:
		if b.has_method("modify_accuracy"):
			acc = b.modify_accuracy(acc)
	return acc

## Override evasion to factor in armor evasion and hero level.
## Original: (STARTING_EVA + hero.lvl) * armor.evasionFactor(hero, 1.0)
func evasion() -> int:
	var base_eva: float = float(defense_skill) + hero_level
	if belongings:
		var equipped_armor: Variant = belongings.get_equipped_armor()
		if equipped_armor and equipped_armor.has_method("evasion_factor"):
			# evasion_factor returns a multiplied base with augment bonus
			base_eva = equipped_armor.evasion_factor(self, base_eva)
	var eva: int = roundi(base_eva)
	for b: Node in _buffs:
		if b.has_method("evasion_modifier"):
			eva = b.evasion_modifier(eva)
	return maxi(0, eva)
