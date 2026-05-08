class_name Hero
extends Char
## The player character. Handles leveling, hunger, class abilities, input commands.
## Designed for multiplayer: multiple Hero instances can coexist. Actions go through
## a command pattern — never directly mutate game state from input.

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
var belongings: Belongings = null

## Multiplayer peer ID (0 = local/host, >0 = remote player).
var peer_id: int = 0

## The hero's unique name/label for multiplayer.
var hero_name: String = "Hero"

## Action queue for the command pattern. Each action is a Dictionary with
## "type" (String), "target" (int), and optional extra keys.
var _pending_action: Dictionary[String, Variant] = {}
var _action_ready: bool = false

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
			var scroll: Item = Generator.create_item("scroll_of_identify")
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
				belongings.add_item(bow)
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

	# Any non-wait action interrupts resting (original: Hero.java act() sets resting=false)
	if action.get("type", "") != "wait":
		resting = false

	match action.get("type", ""):
		"move":
			_do_move(action.get("target_pos", -1))
		"attack":
			_do_attack(action.get("target"), action.get("target_pos", -1))
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

	# Spend time based on action type. Original: movement costs 1/speed(),
	# attacks cost attackDelay()/speed(), wait costs 1.
	var action_type: String = action.get("type", "")
	match action_type:
		"move":
			spend_turn(1.0 / get_speed())
		"attack":
			var atk_delay: float = _get_attack_delay()
			spend_turn(atk_delay / get_speed())
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

## Find the next step toward target_pos using BFS pathfinding.
## Returns the first cell on the shortest path, or -1 if no path exists.
## BFS guarantees the shortest path and handles concave rooms, corridors, etc.
func _step_toward(target_pos: int) -> int:
	if not level:
		return -1

	# BFS from hero's current position to target_pos.
	# We track the "came_from" predecessor so we can trace back to the first step.
	var queue: Array[int] = [pos]
	var came_from: Dictionary[int, int] = {pos: -1}  # pos -> predecessor pos
	var head: int = 0

	while head < queue.size():
		var current: int = queue[head]
		head += 1

		if current == target_pos:
			break

		for dir: int in ConstantsData.DIRS_8:
			var next_pos: int = current + dir
			if came_from.has(next_pos):
				continue
			if not ConstantsData.is_valid_pos(next_pos):
				continue
			# Check passability — allow doors (hero auto-opens them)
			if not level.is_passable(next_pos):
				if level.has_method("get_terrain"):
					var terrain: int = level.get_terrain(next_pos)
					if terrain != ConstantsData.Terrain.DOOR:
						continue
				else:
					continue
			# Don't path through occupied cells (except the target itself,
			# which may have an enemy the hero wants to walk toward)
			if next_pos != target_pos and level.find_char_at(next_pos) != null:
				continue
			came_from[next_pos] = current
			queue.append(next_pos)

	# No path found
	if not came_from.has(target_pos):
		return -1

	# Trace back from target to find the first step after hero's pos
	var step: int = target_pos
	while came_from.get(step, -1) != pos:
		step = came_from[step]
		if step < 0:
			return -1
	return step

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
	# Break invisibility on attack
	if has_buff("Invisibility"):
		var invis: Node = get_buff("Invisibility")
		if invis is Invisibility:
			(invis as Invisibility).dispel()
	# Check if target is a disguised mimic — reveal it
	if atk_target is Mimic and (atk_target as Mimic).disguised:
		(atk_target as Mimic).reveal()
	attack(atk_target)

func _do_wait() -> void:
	# Silent single-turn wait — hero does not show a message
	pass


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
			ConstantsData.Terrain.DOOR:
				level.set_terrain(target_pos, ConstantsData.Terrain.OPEN_DOOR)
				if EventBus:
					EventBus.door_opened.emit(target_pos)
				if MessageLog:
					MessageLog.add("You open the door.")
			ConstantsData.Terrain.LOCKED_DOOR:
				# Check for key in inventory
				var key: Variant = belongings.find_item_by_id("iron_key")
				if key:
					belongings.remove_item(key)
					level.set_terrain(target_pos, ConstantsData.Terrain.OPEN_DOOR)
					if MessageLog:
						MessageLog.add("You unlock the door.")
				else:
					if MessageLog:
						MessageLog.add_warning("The door is locked.")

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
# Damage / Heal Overrides (emit HUD update signals)
# ---------------------------------------------------------------------------

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
