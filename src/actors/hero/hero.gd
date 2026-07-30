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
var talent_levels: Dictionary[String, int] = {}
var belongings: Belongings = null

## Multiplayer peer ID (0 = local/host, >0 = remote player).
var peer_id: int = 0

## The hero's unique name/label for multiplayer.
var hero_name: String = "Hero"
## Online owner peer id for this hero slot. `1` is the host in Godot ENet.
var owner_peer_id: int = 1
## Stable slot index inside the party for multiplayer routing.
var hero_slot_index: int = 0
var last_visible_action: String = ""
var last_visible_target_pos: int = -1

## Action queue for the command pattern. Each action is a Dictionary with
## "type" (String), "target" (int), and optional extra keys.
var _pending_action: Dictionary = {}
var _action_ready: bool = false
var _pending_surprise_attack: bool = false
var _patient_strike_ready: bool = false
var _backup_barrier_ready: bool = true
var _followup_strike_ready: bool = false
## Set by _do_interact when an Ally Warp swap ran: upstream warps are instant,
## so the interact action costs no time that turn.
var _interact_was_free: bool = false
## Time cost of the current weapon-ability action: 0 when refused or when the
## strike killed (upstream cleave kills are instant via hero.next()), else the
## attack delay. Consumed by the spend match after _do_weapon_ability.
var _ability_spend: float = 0.0

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
	talent_levels.clear()
	_pending_surprise_attack = false
	_patient_strike_ready = false
	_backup_barrier_ready = true
	_followup_strike_ready = false
	hero_name = HeroClassData.get_class_name_str(chosen_class)
	name = hero_name

	# Apply class-specific permanent buffs
	_apply_class_buffs()

## Apply buffs every hero starts with. Upstream HeroClass.initHero() attaches
## no class-specific spawn passives; class perks live in their real systems
## (broken seal shield, cloak of shadows, search radius, talents).
func _apply_class_buffs() -> void:
	var regen: Regeneration = Regeneration.new()
	add_buff(regen)
	var hunger: Hunger = Hunger.new()
	add_buff(hunger)
	# Duelist starts with the weapon-ability charge pool
	# (upstream HeroClass.initHero: new MeleeWeapon.Charger().attachTo(hero)).
	if hero_class == ConstantsData.HeroClass.DUELIST:
		add_buff(WeaponCharger.new())

## Give the hero starting items based on their class.
## Called after init_class() during new game setup.
func give_starting_items() -> void:
	if belongings == null:
		belongings = Belongings.new(self)

	match hero_class:
		ConstantsData.HeroClass.WARRIOR:
			# Worn shortsword + cloth armor with broken seal + food ration
			var sword: Item = Generator.create_item("worn_shortsword")
			if sword:
				belongings.equip_weapon(sword)
			var cloth: Item = Generator.create_item("cloth_armor")
			if cloth:
				if cloth is Armor:
					(cloth as Armor).affix_seal()
				belongings.equip_armor(cloth)
				# Original: Armor.activate() affixes WarriorShield on equip.
				add_buff(WarriorShield.new())
			var food: Item = Generator.create_item("ration")
			if food:
				belongings.add_item(food)

		ConstantsData.HeroClass.MAGE:
			# Mage's staff (imbued with Wand of Magic Missile) + cloth armor + food ration + scroll of identify
			var staff: Item = Generator.create_item("mages_staff")
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
	last_visible_action = ""
	last_visible_target_pos = -1

	# Process buffs at the start of each hero turn (hunger, regen, poison, etc.).
	# TurnManager pauses before calling act() for heroes, so we must do it here.
	# act_buffs() burns buff time by shared game-time, so Haste/Slow change how often
	# the hero acts, not how fast their timed effects expire.
	act_buffs()
	var equipped_artifact: Variant = belongings.get_equipped_artifact() if belongings != null else null
	if equipped_artifact != null and equipped_artifact.has_method("on_turn"):
		equipped_artifact.on_turn(self)
	_light_cloak_recharge()

	# If the hero died during buff processing (starvation, poison), skip the action
	# but still complete the turn to avoid softlocking the turn system.
	if not is_alive:
		_pending_action = {}
		spend_turn()
		if TurnManager:
			TurnManager.hero_action_complete(self)
		return

	if belongings != null:
		belongings.recharge_wands(1)

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
			TurnManager.hero_action_complete(self)
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
			_do_attack(action.get("target"), action.get("target_pos", -1), action.get("blink_pos", -1))
		"search":
			_do_search()
		"throw_item":
			_do_throw_item(action.get("item"), action.get("target_pos", -1),
				action.get("sniper_special", false))
		"zap_wand":
			_do_zap_wand(action.get("item"), action.get("target_pos", -1))
		"weapon_ability":
			_do_weapon_ability(action.get("item"), action.get("target_pos", -1))
		"monk_ability":
			_do_monk_ability(str(action.get("kind", "")), action.get("target_pos", -1))
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
		"chasm_jump":
			_do_chasm_jump(action.get("target_pos", -1))
		_:
			pass  # Unknown action — skip turn

	hero_acted.emit(action)

	# Spend time based on action type. TurnManager divides by get_speed(), so
	# non-movement actions are pre-scaled back up to keep movement-only speed
	# effects (Ring of Haste, armor speed, Cripple) out of attack/zap/search costs.
	match action_type:
		"move":
			spend_turn(1.0)
		"attack":
			var atk_delay: float = _get_attack_delay()
			spend_turn(atk_delay)
		"throw_item":
			# Sniper-special bow flags must survive until the delay is read
			# (a NONE-augment special shot costs 0 time), then reset.
			var throw_delay: float = _get_throw_delay(action.get("item"))
			spend_turn(throw_delay)
			var thrown: Variant = action.get("item")
			if thrown is SpiritBow:
				var thrown_bow: SpiritBow = thrown as SpiritBow
				thrown_bow.sniper_special = false
				thrown_bow.sniper_special_bonus = 0.0
				thrown_bow.sniper_special_distance = 0
		"zap_wand":
			spend_turn(_get_non_movement_action_delay())
		"weapon_ability", "monk_ability":
			# Refused abilities and kills are free (upstream hero.next()).
			if _ability_spend > 0.0:
				spend_turn(_ability_spend)
			_ability_spend = 0.0
		"interact":
			# Ally Warp swaps are instant (upstream warps spend no time).
			if not _interact_was_free:
				spend_turn(_get_non_movement_action_delay())
			_interact_was_free = false
		_:
			spend_turn(_get_non_movement_action_delay())

	# Warden Barkskin talent (upstream Hero.act() tail): ending a turn while
	# standing in furrowed grass refreshes decaying barkskin armor.
	_apply_barkskin_talent()

	# Tell TurnManager we're done
	if TurnManager:
		TurnManager.hero_action_complete(self)

## Warden Barkskin talent (upstream Hero.act() tail): standing in furrowed
## grass at end of turn calls Barkskin.conditionallyAppend(lvl*points/2, 1),
## so the barkskin refreshes each turn spent in the furrow and decays by 1
## per turn once the hero leaves it.
func _apply_barkskin_talent() -> void:
	var points: int = get_talent_level("warden_barkskin")
	if points <= 0 or level == null or not is_alive:
		return
	if level.get_terrain(pos) != ConstantsData.Terrain.FURROWED_GRASS:
		return
	@warning_ignore("integer_division")
	Barkskin.conditionally_append(self, (hero_level * points) / 2, 1)

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
		last_visible_action = "move"
		last_visible_target_pos = step_pos
		if EventBus:
			EventBus.hero_moved_detailed.emit(self, step_pos)
			var focused_hero: Variant = GameManager.get_local_hero() if GameManager and GameManager.has_method("get_local_hero") else (GameManager.hero if GameManager else null)
			if focused_hero == self:
				EventBus.hero_moved.emit(step_pos)
		# Check terrain effects at new position
		_check_terrain_effects()

## Voluntary chasm jump (upstream Chasm.heroJump): the input layer has already
## shown the confirm prompt, so this action is the confirmed leap. Re-validate
## that the tapped cell is still an adjacent chasm and the hero can actually
## fall (rooted heroes can't step off, flying heroes glide over), then descend
## via the shared Chasm fall path.
func _do_chasm_jump(target_pos: int) -> void:
	if target_pos < 0 or level == null:
		return
	if not _is_adjacent_pos(pos, target_pos):
		return
	if level.terrain_at(target_pos) != ConstantsData.Terrain.CHASM:
		return
	if Chasm.can_cross(self) or has_buff("Rooted"):
		return
	last_visible_action = "move"
	last_visible_target_pos = target_pos
	Chasm.jump_fall(self, level)

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


func _do_attack(target_or_null: Variant, target_pos_fallback: int = -1, blink_pos: int = -1) -> void:
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
	# Prepared Assassin blink-attack (upstream Preparation.doAction): teleport
	# to the chosen cell beside the target, then strike as one action.
	if blink_pos >= 0 and not _is_adjacent_pos(pos, atk_target.pos) and move_to(blink_pos):
		if EventBus:
			EventBus.hero_moved_detailed.emit(self, blink_pos)
			var focused_hero: Variant = GameManager.get_local_hero() if GameManager and GameManager.has_method("get_local_hero") else (GameManager.hero if GameManager else null)
			if focused_hero == self:
				EventBus.hero_moved.emit(blink_pos)
		_check_terrain_effects()
	last_visible_action = "attack"
	last_visible_target_pos = atk_target.pos
	# Surprise applies whenever the target is unaware of us (invisible, or a mob
	# that is sleeping/wandering/out-of-sight), not only while we are invisible.
	_pending_surprise_attack = can_surprise_attack() and atk_target.is_surprised_by(self)
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

## Duelist weapon ability (upstream MeleeWeapon.execute AC_ABILITY guards +
## Sword.cleaveAbility): refusals cost no time (_ability_spend stays 0), a
## landed strike is a guaranteed hit (upstream INFINITE_ACCURACY) with the
## weapon's flat ability damage boost. A kill makes the ability instant and
## opens the CleaveTracker free-recast window unless one was already open;
## a non-kill strike costs the attack delay and closes any open window.
## Monk subclass ability fueled by MonkEnergy. Ported: Flurry, Focus, Dash,
## Dragon Kick.
## Upstream MonkEnergy.MonkAbility.Flurry.doAbility: two unarmed strikes at
## 1.5x damage with infinite accuracy, instant (hero.next()), once per turn
## via FlurryCooldownTracker, costing 1 energy.
func _do_monk_ability(kind: String, target_pos: int) -> void:
	_ability_spend = 0.0
	if hero_subclass != ConstantsData.HeroSubclass.MONK or level == null:
		return
	var energy: MonkEnergy = get_buff("MonkEnergy") as MonkEnergy
	if kind == "focus":
		_do_focus_ability(energy)
		return
	if kind == "dash":
		_do_dash_ability(energy, target_pos)
		return
	if kind == "dragon_kick":
		_do_dragon_kick_ability(energy, target_pos)
		return
	if kind == "meditate":
		_do_meditate_ability(energy)
		return
	if kind != "flurry":
		return
	if energy == null or energy.energy < 1.0:
		if MessageLog:
			MessageLog.add_warning("You don't have enough energy for that ability.")
		return
	if has_buff("FlurryCooldownTracker"):
		if MessageLog:
			MessageLog.add_warning("You can only use flurry once per turn.")
		return
	if target_pos < 0 or target_pos >= level.visible.size() or not level.visible[target_pos]:
		if MessageLog:
			MessageLog.add_warning("You can't target that.")
		return
	var char_at: Variant = level.find_char_at(target_pos)
	if not (char_at is Char) or char_at == self:
		if MessageLog:
			MessageLog.add_warning("You can't target that.")
		return
	var enemy: Char = char_at as Char
	if not enemy.is_alive or distance_to(enemy.pos) > 1:
		if MessageLog:
			MessageLog.add_warning("That target is out of reach.")
		return
	last_visible_action = "attack"
	last_visible_target_pos = enemy.pos
	if enemy is Mimic and (enemy as Mimic).disguised:
		(enemy as Mimic).reveal()
	var tracker: UnarmedAbilityTracker = \
			add_buff(UnarmedAbilityTracker.new()) as UnarmedAbilityTracker
	attack(enemy, 1.5, 0.0, 1.0e9)
	if enemy.is_alive:
		attack(enemy, 1.5, 0.0, 1.0e9)
	if tracker != null:
		remove_buff(tracker)
	energy.ability_used(1.0)
	add_buff(FlurryCooldownTracker.new())
	if has_buff("Invisibility"):
		var invis: Node = get_buff("Invisibility")
		if invis is Invisibility:
			(invis as Invisibility).dispel()
	# Flurry is instant (upstream hero.next()); _ability_spend stays 0.

## Monk Focus (upstream MonkEnergy.MonkAbility.Focus): 2 energy, no target,
## applies FocusBuff which parries the next incoming attack. Costs 1 turn,
## or is instant while abilities are empowered (energy near cap, boosted by
## Monastic Vigor). Refused for free if already focused or short on energy.
func _do_focus_ability(energy: MonkEnergy) -> void:
	if energy == null or energy.energy < 2.0:
		if MessageLog:
			MessageLog.add_warning("You don't have enough energy for that ability.")
		return
	if has_buff("FocusBuff"):
		if MessageLog:
			MessageLog.add_warning("You are already focused.")
		return
	add_buff(FocusBuff.new())
	if not energy.abilities_empowered():
		_ability_spend = 1.0
	energy.ability_used(2.0)

## Monk Dash (upstream MonkEnergy.MonkAbility.Dash): 3 energy, dash to an
## empty cell within range 4 (8 while abilities are empowered) along a clear
## projectile line. Instant (hero.next() upstream, so _ability_spend stays
## 0); rooted heroes, out-of-range, occupied, or blocked cells refuse free.
func _do_dash_ability(energy: MonkEnergy, target_pos: int) -> void:
	if energy == null or energy.energy < 3.0:
		if MessageLog:
			MessageLog.add_warning("You don't have enough energy for that ability.")
		return
	if target_pos < 0 or target_pos >= level.passable.size():
		return
	if has_buff("Rooted"):
		if MessageLog:
			MessageLog.add_warning("You can't move while rooted!")
		return
	var dash_range: int = 4
	if energy.abilities_empowered():
		dash_range += 4
	if distance_to(target_pos) > dash_range:
		if MessageLog:
			MessageLog.add_warning("That location is too far away.")
		return
	if level.find_char_at(target_pos) != null:
		if MessageLog:
			MessageLog.add_warning("You can't dash into an occupied cell.")
		return
	var occupied: Array[bool] = []
	occupied.resize(level.passable.size())
	occupied.fill(false)
	for hero_ref: Char in level.get_heroes():
		if hero_ref != null and hero_ref != self and hero_ref.is_alive:
			occupied[hero_ref.pos] = true
	for mob_ref: Node in level.mobs:
		if mob_ref is Char and mob_ref != self and (mob_ref as Char).is_alive:
			occupied[(mob_ref as Char).pos] = true
	var dash: Ballistica = Ballistica.new()
	dash.cast(pos, target_pos, level.passable, Ballistica.PROJECTILE, occupied,
		ConstantsData.WIDTH)
	if dash.collision_pos != target_pos or not level.passable[target_pos]:
		if MessageLog:
			MessageLog.add_warning("You can't dash there.")
		return
	pos = target_pos
	last_visible_action = "move"
	last_visible_target_pos = target_pos
	if EventBus:
		EventBus.hero_moved_detailed.emit(self, target_pos)
		var focused_hero: Variant = GameManager.get_local_hero() if GameManager and GameManager.has_method("get_local_hero") else (GameManager.hero if GameManager else null)
		if focused_hero == self:
			EventBus.hero_moved.emit(target_pos)
	_check_terrain_effects()
	energy.ability_used(3.0)
	# Dash is instant (upstream hero.next()); _ability_spend stays 0.

## Monk Dragon Kick (upstream MonkEnergy.MonkAbility.DragonKick): 4 energy,
## one guaranteed unarmed strike at 6x damage (9x while empowered). If the
## strike didn't move the target it is knocked back 6 cells and paralyzed
## for min(6, cells moved); while empowered every other adjacent enemy is
## knocked back the same way. Costs the attack delay; refusals are free.
func _do_dragon_kick_ability(energy: MonkEnergy, target_pos: int) -> void:
	if energy == null or energy.energy < 4.0:
		if MessageLog:
			MessageLog.add_warning("You don't have enough energy for that ability.")
		return
	if target_pos < 0 or target_pos >= level.visible.size() or not level.visible[target_pos]:
		if MessageLog:
			MessageLog.add_warning("You can't target that.")
		return
	var char_at: Variant = level.find_char_at(target_pos)
	if not (char_at is Char) or char_at == self:
		if MessageLog:
			MessageLog.add_warning("You can't target that.")
		return
	var enemy: Char = char_at as Char
	if not enemy.is_alive or distance_to(enemy.pos) > 1:
		if MessageLog:
			MessageLog.add_warning("That target is out of reach.")
		return
	last_visible_action = "attack"
	last_visible_target_pos = enemy.pos
	if enemy is Mimic and (enemy as Mimic).disguised:
		(enemy as Mimic).reveal()
	var empowered: bool = energy.abilities_empowered()
	var tracker: UnarmedAbilityTracker = \
			add_buff(UnarmedAbilityTracker.new()) as UnarmedAbilityTracker
	var old_pos: int = enemy.pos
	attack(enemy, 9.0 if empowered else 6.0, 0.0, 1.0e9)
	if is_instance_valid(enemy) and enemy.pos == old_pos:
		_dragon_kick_knock(enemy)
	if empowered:
		for mob_ref: Node in level.mobs:
			if mob_ref is Mob and mob_ref != enemy and not (mob_ref is NPC) \
					and not (mob_ref as Mob).is_ally and (mob_ref as Mob).is_alive \
					and is_adjacent((mob_ref as Mob).pos):
				_dragon_kick_knock(mob_ref as Char)
	if tracker != null:
		remove_buff(tracker)
	if has_buff("Invisibility"):
		var invis: Node = get_buff("Invisibility")
		if invis is Invisibility:
			(invis as Invisibility).dispel()
	energy.ability_used(4.0)
	_ability_spend = _get_attack_delay()

## Push one Dragon Kick victim 6 cells away from the hero, then paralyze it
## for min(6, cells actually moved) turns (upstream WandOfBlastWave.throwChar
## + Paralysis of trajectory.dist). Chasm falls are handled by KnockBack.
func _dragon_kick_knock(victim: Char) -> void:
	var before: int = victim.pos
	KnockBack.throw_char(victim, pos, 6, level)
	if not is_instance_valid(victim) or not victim.is_alive:
		return
	var moved: int = mini(6, maxi(
		absi(ConstantsData.pos_to_x(before) - ConstantsData.pos_to_x(victim.pos)),
		absi(ConstantsData.pos_to_y(before) - ConstantsData.pos_to_y(victim.pos))))
	if moved > 0:
		var para: Paralysis = Paralysis.new()
		para.duration = float(moved)
		para.time_left = para.duration
		victim.add_buff(para)

## Monk Meditate (upstream MonkEnergy.MonkAbility.Meditate): 5 energy, no
## target. Cleanses all negative buffs (upstream skips AllyBuff and
## LostInventory; the local Corruption port is POSITIVE-typed, so the
## buff_type filter matches), then spends 5 turns meditating. When the
## meditation ends the hero's wands recharge rapidly for 8 turns
## (MeditateTracker.on_detach). While abilities are empowered the hero also
## gradually heals round(missing HP / 5) and takes only 20% damage until
## the meditation ends (MeditateResistance). Refusals are free.
func _do_meditate_ability(energy: MonkEnergy) -> void:
	if energy == null or energy.energy < 5.0:
		if MessageLog:
			MessageLog.add_warning("You don't have enough energy for that ability.")
		return
	for b: Node in get_buffs().duplicate():
		if b is Buff and (b as Buff).buff_type == Buff.BuffType.NEGATIVE:
			remove_buff(b)
	add_buff(MeditateTracker.new())
	if energy.abilities_empowered():
		var to_heal: int = roundi(float(hp_max - hp) / 5.0)
		if to_heal > 0:
			var healing: Healing = add_buff(Healing.new()) as Healing
			if healing != null:
				healing.set_heal(to_heal, 0.0, 1)
		add_buff(MeditateResistance.new())
	energy.ability_used(5.0)
	# Upstream spends 5 constant ticks (5x wait actions).
	_ability_spend = 5.0

func _do_weapon_ability(item: Variant, target_pos: int) -> void:
	_weapon_ability_body(item, target_pos)
	# before_ability_used set the transient attacking-weapon override; every
	# ability path resolves synchronously above (upstream afterAbilityUsed
	# nulls Belongings.abilityWeapon).
	if belongings != null:
		belongings.ability_weapon = null

func _weapon_ability_body(item: Variant, target_pos: int) -> void:
	_ability_spend = 0.0
	if not (item is MeleeWeapon) or belongings == null or level == null or target_pos < 0:
		return
	var weapon: MeleeWeapon = item as MeleeWeapon
	# The Champion off-hand weapon's ability is usable too (upstream
	# KindOfWeapon.isEquipped covers wep and secondWep).
	if (belongings.weapon != weapon and belongings.second_wep != weapon) \
			or hero_class != ConstantsData.HeroClass.DUELIST \
			or not weapon.has_duelist_ability():
		return
	if str_val < weapon.get_str_requirement():
		if MessageLog:
			MessageLog.add_warning("You are too weak to use your weapon's ability effectively.")
		return
	var charger: WeaponCharger = get_buff("WeaponCharger") as WeaponCharger
	var charge_use: float = weapon.ability_charge_use(self)
	if charger == null or float(charger.charges) + charger.partial_charge < charge_use:
		if MessageLog:
			MessageLog.add_warning("Your weapon doesn't have enough charge for that ability.")
		return
	# Greataxe Retribution is only usable below half HP (upstream
	# Greataxe.duelistAbility refuses when HP/HT >= 0.5, for free).
	if weapon.ability_kind() == "retribution" and hp * 2 >= hp_max:
		if MessageLog:
			MessageLog.add_warning("You can only use retribution while below half health.")
		return
	if weapon.ability_kind() == "guard":
		_do_guard_ability(weapon, charge_use)
		return
	if weapon.ability_kind() == "sword_dance":
		_do_sword_dance_ability(weapon, charge_use)
		return
	if weapon.ability_kind() == "defensive_stance":
		_do_defensive_stance_ability(weapon, charge_use)
		return
	if weapon.ability_kind() == "spin":
		_do_spin_ability(weapon, charge_use)
		return
	if weapon.ability_kind() == "sneak":
		_do_sneak_ability(weapon, target_pos, charge_use)
		return
	if weapon.ability_kind() == "lunge":
		_do_lunge_ability(weapon, target_pos, charge_use)
		return
	var char_at: Variant = level.find_char_at(target_pos)
	if not (char_at is Char) or char_at == self \
			or target_pos >= level.visible.size() or not level.visible[target_pos]:
		if MessageLog:
			MessageLog.add_warning("You can't target that.")
		return
	var enemy: Char = char_at as Char
	if not enemy.is_alive or distance_to(enemy.pos) > weapon.get_reach():
		if MessageLog:
			MessageLog.add_warning("Your weapon can't reach that target.")
		return
	# Spike only works at reach, never adjacent (upstream Spear.spikeAbility
	# refuses when Dungeon.level.adjacent(hero.pos, enemy.pos)).
	if weapon.ability_kind() == "spike" and distance_to(enemy.pos) <= 1:
		if MessageLog:
			MessageLog.add_warning("That target is too close to spike.")
		return
	last_visible_action = "attack"
	last_visible_target_pos = enemy.pos
	if enemy is Mimic and (enemy as Mimic).disguised:
		(enemy as Mimic).reveal()
	var ability_kind: String = weapon.ability_kind()
	weapon.before_ability_used(self, charge_use)
	var dmg_boost: int = weapon.ability_damage_boost()
	# Heavy blow's bonus damage only applies against surprised targets
	# (upstream Mace.heavyBlowAbility zeroes dmgBoost when the mob is aware).
	if ability_kind == "heavy_blow" and enemy is Mob \
			and not (enemy as Mob).is_surprised_by(self):
		dmg_boost = 0
	# Combo strike's flat boost is per recent hit and consumes the tracker
	# (upstream Sai.comboStrikeAbility); zero recent hits means no bonus.
	# The strike itself then feeds a fresh tracker hit via on_attack_hit.
	if ability_kind == "combo_strike":
		var combo: ComboStrikeTracker = get_buff("ComboStrikeTracker") as ComboStrikeTracker
		var recent_hits: int = 0
		if combo != null:
			recent_hits = combo.hits
			remove_buff(combo)
		dmg_boost *= recent_hits
	# Runic slash boosts the enchant proc chance for this one strike
	# (upstream RunicBlade.duelistAbility attaches RunicSlashTracker with
	# a 3 + 0.5*lvl bonus; the proc roll or post-strike cleanup consumes it).
	if ability_kind == "runic_slash":
		var slash: RunicSlashTracker = add_buff(RunicSlashTracker.new()) as RunicSlashTracker
		if slash != null:
			slash.boost = weapon.runic_slash_boost()
	var enemy_pos_before: int = enemy.pos
	attack(enemy, 1.0, float(dmg_boost), 1.0e9)
	if has_buff("Invisibility"):
		var invis: Node = get_buff("Invisibility")
		if invis is Invisibility:
			(invis as Invisibility).dispel()
	if ability_kind == "heavy_blow":
		# Upstream heavy blow always costs the attack delay and dazes a
		# surviving target; kills have no follow-up window.
		if enemy.is_alive:
			enemy.add_buff(Daze.new())
		_ability_spend = _get_attack_delay()
	elif ability_kind == "spike":
		# Upstream Spear.spikeAbility knocks a surviving target back one cell
		# (unless something already moved it) and always costs the attack
		# delay; kills open no free-recast window.
		if enemy.is_alive and enemy.pos == enemy_pos_before:
			KnockBack.throw_char(enemy, pos, 1, level)
		_ability_spend = _get_attack_delay()
	elif ability_kind == "combo_strike":
		# Upstream Sai.comboStrikeAbility always spends the attack delay;
		# kills open no free-recast window.
		_ability_spend = _get_attack_delay()
	elif ability_kind == "runic_slash":
		# Upstream RunicBlade detaches any unconsumed tracker after the
		# strike and always spends the attack delay; kills open no
		# free-recast window.
		var slash_left: Buff = get_buff("RunicSlashTracker")
		if slash_left != null:
			remove_buff(slash_left)
		_ability_spend = _get_attack_delay()
	elif ability_kind == "retribution":
		# Upstream Greataxe: the strike is instantaneous if it kills
		# (hero.next()); a surviving target costs the attack delay. Kills
		# open no free-recast window.
		if enemy.is_alive:
			_ability_spend = _get_attack_delay()
	else:
		var tracker: Buff = get_buff("CleaveTracker")
		if not enemy.is_alive:
			if tracker != null:
				remove_buff(tracker)
			else:
				add_buff(CleaveTracker.new())
		else:
			_ability_spend = _get_attack_delay()
			if tracker != null:
				remove_buff(tracker)
	_patient_strike_ready = false
	_followup_strike_ready = false

## Rapier Lunge (upstream Rapier.lungeAbility): dash to the open neighbor
## cell nearest the target (true distance), then land a guaranteed strike
## with the flat boost, costing the attack delay. Only works on targets
## exactly one cell beyond weapon reach; rooted heroes, too-close/too-far
## targets, and blocked dash cells refuse for free. The Duelist may lunge
## at a non-visible cell: the dash happens, and if no enemy is attackable
## afterwards the charge and a move turn are spent without an ability use.
func _do_lunge_ability(weapon: MeleeWeapon, target_pos: int, charge_use: float) -> void:
	var char_at: Variant = level.find_char_at(target_pos)
	var enemy: Char = char_at as Char
	if target_pos < level.visible.size() and level.visible[target_pos] \
			and (enemy == null or enemy == self or not enemy.is_alive):
		if MessageLog:
			MessageLog.add_warning("You can't target that.")
		return
	if has_buff("Rooted"):
		if MessageLog:
			MessageLog.add_warning("You can't move while rooted!")
		return
	var dist: int = distance_to(target_pos)
	if dist < 2 or dist - 1 > weapon.get_reach():
		if MessageLog:
			MessageLog.add_warning("Your weapon can't reach that target.")
		return
	var lunge_cell: int = -1
	var best_true_dist: float = 1.0e9
	for neighbor: int in Pathfinder.get_neighbors(pos, ConstantsData.WIDTH, level.passable.size()):
		if not level.passable[neighbor] or level.find_char_at(neighbor) != null:
			continue
		if Ballistica.distance(neighbor, target_pos) > weapon.get_reach():
			continue
		var nx: int = ConstantsData.pos_to_x(neighbor) - ConstantsData.pos_to_x(target_pos)
		var ny: int = ConstantsData.pos_to_y(neighbor) - ConstantsData.pos_to_y(target_pos)
		var true_dist: float = sqrt(float(nx * nx + ny * ny))
		if lunge_cell == -1 or true_dist < best_true_dist:
			lunge_cell = neighbor
			best_true_dist = true_dist
	if lunge_cell == -1:
		if MessageLog:
			MessageLog.add_warning("Your weapon can't reach that target.")
		return
	pos = lunge_cell
	last_visible_action = "move"
	last_visible_target_pos = lunge_cell
	if EventBus:
		EventBus.hero_moved_detailed.emit(self, lunge_cell)
		var focused_hero: Variant = GameManager.get_local_hero() if GameManager and GameManager.has_method("get_local_hero") else (GameManager.hero if GameManager else null)
		if focused_hero == self:
			EventBus.hero_moved.emit(lunge_cell)
	_check_terrain_effects()
	if enemy != null and enemy.is_alive and enemy != self \
			and distance_to(enemy.pos) <= weapon.get_reach():
		last_visible_action = "attack"
		last_visible_target_pos = enemy.pos
		if enemy is Mimic and (enemy as Mimic).disguised:
			(enemy as Mimic).reveal()
		weapon.before_ability_used(self, charge_use)
		attack(enemy, 1.0, float(weapon.ability_damage_boost()), 1.0e9)
		if has_buff("Invisibility"):
			var invis: Node = get_buff("Invisibility")
			if invis is Invisibility:
				(invis as Invisibility).dispel()
		_ability_spend = _get_attack_delay()
	else:
		# Upstream: spends the charge but otherwise does not count as an
		# ability use; costs a movement turn.
		var charger: WeaponCharger = get_buff("WeaponCharger") as WeaponCharger
		if charger != null:
			charger.partial_charge -= 1.0
			while charger.partial_charge < 0.0 and charger.charges > 0:
				charger.charges -= 1
				charger.partial_charge += 1.0
		if MessageLog:
			MessageLog.add_warning("Your lunge found no target.")
		_ability_spend = 1.0 / get_speed()
	_patient_strike_ready = false
	_followup_strike_ready = false

## Shield-family Guard (upstream RoundShield.guardAbility): enter a guard
## stance that blocks all incoming attacks for the family duration
## (RoundShield 5+lvl, Greatshield 3+lvl turns), spending one turn. Re-casts
## prolong the stance and reset the blocked marker.
func _do_guard_ability(weapon: MeleeWeapon, charge_use: float) -> void:
	weapon.before_ability_used(self, charge_use)
	var existing: Variant = get_buff("GuardTracker")
	if existing is GuardTracker:
		(existing as GuardTracker).postpone(float(weapon.guard_duration()))
		(existing as GuardTracker).has_blocked = false
	else:
		var guard: GuardTracker = GuardTracker.new()
		guard.set_duration(float(weapon.guard_duration()))
		add_buff(guard)
	if MessageLog:
		MessageLog.add("You raise your shield into a guard stance.")
	_ability_spend = 1.0
	_patient_strike_ready = false
	_followup_strike_ready = false

## Scimitar Sword Dance (upstream Scimitar.duelistAbility): prolong the
## SwordDance stance for 3+lvl turns (one fewer than the displayed 4+lvl
## because the ability is instant), granting 1.5x accuracy and +0.6 attack
## speed. Using the ability spends no time (upstream hero.next()).
func _do_sword_dance_ability(weapon: MeleeWeapon, charge_use: float) -> void:
	weapon.before_ability_used(self, charge_use)
	var existing: Variant = get_buff("SwordDance")
	if existing is SwordDance:
		(existing as SwordDance).postpone(float(weapon.sword_dance_turns()))
	else:
		var dance: SwordDance = SwordDance.new()
		dance.set_duration(float(weapon.sword_dance_turns()))
		add_buff(dance)
	if MessageLog:
		MessageLog.add("You begin a sword dance!")
	_patient_strike_ready = false
	_followup_strike_ready = false

## Quarterstaff Defensive Stance (upstream Quarterstaff.duelistAbility):
## prolong the DefensiveStance buff for 3+lvl turns (one fewer than the
## displayed 4+lvl because the ability is instant), tripling evasion while
## active. Using the ability spends no time (upstream hero.next()).
func _do_defensive_stance_ability(weapon: MeleeWeapon, charge_use: float) -> void:
	weapon.before_ability_used(self, charge_use)
	var existing: Variant = get_buff("DefensiveStance")
	if existing is DefensiveStance:
		(existing as DefensiveStance).postpone(float(weapon.defensive_stance_turns()))
	else:
		var stance: DefensiveStance = DefensiveStance.new()
		stance.set_duration(float(weapon.defensive_stance_turns()))
		add_buff(stance)
	if MessageLog:
		MessageLog.add("You shift into a defensive stance.")
	_patient_strike_ready = false
	_followup_strike_ready = false

## Flail Spin (upstream Flail.duelistAbility): wind up the flail, stacking
## up to 3 spins on a 3-turn SpinAbilityTracker that every cast re-prolongs.
## The first spin costs a charge; re-spins while the tracker is active are
## free (baseChargeUse 0). Winding up spends one turn; a fourth spin
## refuses for free. The next flail attack releases the spins (see attack).
func _do_spin_ability(weapon: MeleeWeapon, charge_use: float) -> void:
	var spin: SpinAbilityTracker = get_buff("SpinAbilityTracker") as SpinAbilityTracker
	if spin != null and spin.spins >= 3:
		if MessageLog:
			MessageLog.add_warning("Your flail is already at full spin!")
		return
	weapon.before_ability_used(self, charge_use)
	if spin == null:
		spin = add_buff(SpinAbilityTracker.new()) as SpinAbilityTracker
	if spin != null:
		spin.spins += 1
		spin.postpone(3.0)
		if MessageLog:
			MessageLog.add("You spin your flail faster!")
	_ability_spend = 1.0
	_patient_strike_ready = false
	_followup_strike_ready = false

## Dagger-family Sneak (upstream Dagger.sneakAbility): blink to an empty,
## visible cell reachable within the family range, gain Invisibility for
## (2+lvl)-1 turns (one fewer because the ability is instant), and land on
## the tile normally (traps, water, grass). Refusals cost nothing; the whole
## ability is instant so _ability_spend stays 0.
func _do_sneak_ability(weapon: MeleeWeapon, target_pos: int, charge_use: float) -> void:
	if has_buff("Rooted"):
		if MessageLog:
			MessageLog.add_warning("You can't move while rooted!")
		return
	if target_pos >= level.visible.size() or not level.visible[target_pos] \
			or _sneak_step_distance(target_pos) > weapon.ability_target_range():
		if MessageLog:
			MessageLog.add_warning("You can't reach that position.")
		return
	if level.find_char_at(target_pos) != null:
		if MessageLog:
			MessageLog.add_warning("You can't sneak into an occupied cell.")
		return
	weapon.before_ability_used(self, charge_use)
	var invis_turns: float = float(weapon.sneak_invis_turns() - 1)
	var invis: Variant = get_buff("Invisibility")
	if invis is Invisibility:
		(invis as Invisibility).postpone(invis_turns)
	else:
		var new_invis: Invisibility = Invisibility.new()
		new_invis.set_duration(invis_turns)
		add_buff(new_invis)
	pos = target_pos
	last_visible_action = "move"
	last_visible_target_pos = target_pos
	if EventBus:
		EventBus.hero_moved_detailed.emit(self, target_pos)
		var focused_hero: Variant = GameManager.get_local_hero() if GameManager and GameManager.has_method("get_local_hero") else (GameManager.hero if GameManager else null)
		if focused_hero == self:
			EventBus.hero_moved.emit(target_pos)
	_check_terrain_effects()
	_patient_strike_ready = false
	_followup_strike_ready = false

## Uniform-cost 8-way BFS step distance from the hero over passable tiles
## (upstream PathFinder.buildDistanceMap used by Dagger.sneakAbility counts
## diagonal steps as 1). Returns a large value when unreachable.
func _sneak_step_distance(target_pos: int) -> int:
	if target_pos == pos:
		return 0
	if target_pos < 0 or target_pos >= level.passable.size() \
			or not level.passable[target_pos]:
		return 9999
	var dist: Dictionary = {pos: 0}
	var queue: Array[int] = [pos]
	var head: int = 0
	while head < queue.size():
		var current: int = queue[head]
		head += 1
		for neighbor: int in Pathfinder.get_neighbors(current, ConstantsData.WIDTH, level.passable.size()):
			if dist.has(neighbor) or not level.passable[neighbor]:
				continue
			dist[neighbor] = int(dist[current]) + 1
			if neighbor == target_pos:
				return int(dist[neighbor])
			queue.append(neighbor)
	return 9999

func _do_search() -> void:
	if level == null:
		return
	last_visible_action = "search"
	last_visible_target_pos = pos
	var door_feature: RefCounted = DoorFeature.new()
	var search_radius: int = 2 if hero_class == ConstantsData.HeroClass.ROGUE else 1
	# Upstream Hero.search: Wide Search adds +1 radius; at exactly +1 the
	# expanded area has rounded corners, at +2 the full square is searched.
	var wide_search: int = get_talent_level("rogue_wide_search")
	if wide_search > 0:
		search_radius += 1
	var found: int = int(door_feature.call("search", level, pos, search_radius, wide_search == 1))
	var equipped_artifact: Variant = belongings.get_equipped_artifact() if belongings != null else null
	if equipped_artifact != null and equipped_artifact.has_method("on_search"):
		equipped_artifact.on_search()
	if found <= 0 and MessageLog:
		MessageLog.add("You search, but find nothing.")
	_patient_strike_ready = false
	_followup_strike_ready = false

func _do_throw_item(item: Variant, target_pos: int, sniper_special: bool = false) -> void:
	if item == null or target_pos < 0 or level == null or belongings == null:
		return
	if item != belongings.weapon and item != belongings.get_equipped_spirit_bow() and not belongings.has_item(item):
		return
	last_visible_action = "throw_item"
	last_visible_target_pos = target_pos

	_try_improvised_projectiles(item, level.find_char_at(_projectile_collision_pos(target_pos)))

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

	if item is SeedItem:
		var seed_item: SeedItem = item as SeedItem
		seed_item.plant_at(self, _projectile_collision_pos(target_pos))
		_patient_strike_ready = false
		_followup_strike_ready = false
		return

	if item is Potion:
		var potion: Potion = item as Potion
		var shatter_pos: int = _projectile_collision_pos(target_pos)
		if shatter_pos < 0:
			shatter_pos = target_pos
		potion.shatter(shatter_pos, level)
		potion.identify()
		on_potion_used(shatter_pos)
		if EventBus:
			EventBus.item_used.emit(potion.item_name)
		if GameManager:
			GameManager.record_stat("potions_used")
		_consume_thrown_stack_item(potion)
		_patient_strike_ready = false
		_followup_strike_ready = false
		return

	var collision_pos: int = _projectile_collision_pos(target_pos)
	var collision_target: Variant = level.find_char_at(collision_pos) if collision_pos >= 0 else null
	if item is SpiritBow:
		SpiritBow.apply_seer_shot(self, collision_pos if collision_pos >= 0 else target_pos)
	var hit_target: Char = collision_target as Char if collision_target is Char and collision_target != self else null
	# Sniper special shot (upstream SnipersMark.doAction): arm the bow's
	# special flags from the target's mark; the mark is consumed when the
	# shot fires, whether or not it lands.
	if sniper_special and item is SpiritBow and hit_target != null:
		var mark: SnipersMark = hit_target.get_buff("SnipersMark") as SnipersMark
		if mark != null:
			var special_bow: SpiritBow = item as SpiritBow
			special_bow.sniper_special = true
			special_bow.sniper_special_bonus = mark.percent_dmg_bonus
			special_bow.sniper_special_distance = distance_to(hit_target.pos)
			hit_target.remove_buff(mark)
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
		var thrown_missile: MissileWeapon = item as MissileWeapon
		if not _durable_tips_preserves(thrown_missile) \
				and not _durable_projectiles_preserves(thrown_missile):
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
	if item != belongings.misc and item != belongings.weapon and not belongings.has_item(item):
		return
	last_visible_action = "zap_wand"
	last_visible_target_pos = target_pos
	if target_pos == pos and _try_shield_battery(item):
		_patient_strike_ready = false
		_followup_strike_ready = false
		return
	if item is Wand:
		(item as Wand).zap(self, target_pos)
	elif item.has_method("zap"):
		# Non-wand held items that expose a zap() (e.g. Mage's Staff) cast their
		# imbued wand through the same targeting path.
		item.zap(self, target_pos)
	_patient_strike_ready = false
	_followup_strike_ready = false

## Mage Shield Battery talent (SPD Wand.onSelect self-target branch): zapping
## a wand at the Mage's own cell converts all of its current charges into a
## Barrier of HT * 4% per charge, x1.5 at 2 talent points. Returns true when
## the self-zap was handled here (including the no-charge fizzle), so the
## normal zap path is skipped.
func _try_shield_battery(item: Variant) -> bool:
	if hero_class != ConstantsData.HeroClass.MAGE:
		return false
	var battery_level: int = get_talent_level("mage_shield_battery")
	if battery_level <= 0:
		return false
	var wand: Variant = item
	if not (wand is Wand) and wand != null and wand.has_method("get_imbued_wand"):
		wand = wand.get_imbued_wand()
	if not (wand is Wand):
		return false
	var wand_charges: int = (wand as Wand).charges
	if wand_charges <= 0:
		if MessageLog:
			MessageLog.add_warning("Your %s fizzles." % (wand as Wand).item_name)
		return true
	var shield: float = float(hp_max) * 0.04 * float(wand_charges)
	if battery_level >= 2:
		shield *= 1.5
	var barrier: Barrier = add_buff(Barrier.new()) as Barrier
	if barrier != null:
		barrier.set_shield(roundi(shield))
	(wand as Wand).charges = 0
	if MessageLog:
		MessageLog.add_positive("You channel the %s's charge into a shield." % (wand as Wand).item_name)
	if EventBus:
		EventBus.hero_stats_changed.emit()
	return true

## Warrior Improvised Projectiles talent (original: Item.cast): throwing any
## item that is not a thrown weapon at an enemy blinds it for 1 + points
## turns (2/3), then the talent cools down for 50 turns. Applied when the
## throw is declared, matching upstream (not gated on the throw hitting).
func _try_improvised_projectiles(item: Variant, target: Variant) -> void:
	var points: int = get_talent_level("warrior_improvised_projectiles")
	if points <= 0 or item is MissileWeapon or item is SpiritBow:
		return
	if has_buff("ImprovisedProjectileCooldown"):
		return
	if not (target is Mob) or target is NPC:
		return
	var mob: Mob = target as Mob
	if not mob.is_alive or mob.is_ally:
		return
	var blind: Blindness = Blindness.new()
	blind.duration = 1.0 + float(points)
	mob.add_buff(blind)
	add_buff(ImprovisedProjectileCooldown.new())
	if MessageLog:
		MessageLog.add("Your improvised projectile blinds the %s!" % mob.mob_name)

## Upstream Talent.onPotionUsed (Warrior Liquid Willpower): using a potion
## grants a Barrier of HT * (3% + 3.5% per point) — 6.5%/10% of max HP.
## Upstream setShield keeps the larger of the existing and new shield.
## `cell` is the drink cell (hero pos) or thrown-potion splash cell.
func on_potion_used(cell: int = -1) -> void:
	var points: int = get_talent_level("warrior_liquid_willpower")
	if points > 0:
		var shield_to_give: int = roundi(float(ht) * (0.030 + 0.035 * float(points)))
		var barrier: Barrier = add_buff(Barrier.new()) as Barrier
		if barrier != null:
			barrier.set_shield(maxi(barrier.get_shielding(), shield_to_give))
		if MessageLog:
			MessageLog.add_positive("Your willpower hardens into a shield.")
		if EventBus:
			EventBus.hero_stats_changed.emit()
	_liquid_nature_on_potion(cell)

## Upstream Talent.onPotionUsed (Huntress Liquid Nature): drinking or throwing
## a potion roots adjacent enemies for 1/2 turns and sprouts grass in the 3x3
## around the drink/splash cell — every EMPTY/EMBERS cell becomes short grass,
## then 4/6 random cells without a plant grow into tall grass. The port has no
## EMPTY_DECO terrain, so only EMPTY/EMBERS seed short grass.
func _liquid_nature_on_potion(cell: int) -> void:
	var points: int = get_talent_level("huntress_liquid_nature")
	if points <= 0 or level == null:
		return
	if cell < 0 or cell >= level.map.size():
		cell = pos
	var grass_cells: Array[int] = [cell]
	for offset: int in ConstantsData.DIRS_8:
		var neighbor: int = cell + offset
		if neighbor >= 0 and neighbor < level.map.size():
			grass_cells.append(neighbor)
	grass_cells.shuffle()
	for grass_cell: int in grass_cells:
		var ch: Variant = level.find_char_at(grass_cell)
		if ch is Mob and not (ch as Mob).is_ally:
			var rooted: Rooted = Rooted.new()
			rooted.set_duration(float(points))
			(ch as Mob).add_buff(rooted)
		var terrain: int = level.get_terrain(grass_cell)
		if terrain == ConstantsData.Terrain.EMPTY or terrain == ConstantsData.Terrain.EMBERS:
			level.set_terrain(grass_cell, ConstantsData.Terrain.GRASS)
	var total_grass_cells: int = 2 + 2 * points
	while grass_cells.size() > total_grass_cells:
		grass_cells.remove_at(0)
	for grass_cell: int in grass_cells:
		var terrain: int = level.get_terrain(grass_cell)
		if (terrain == ConstantsData.Terrain.EMPTY
				or terrain == ConstantsData.Terrain.EMBERS
				or terrain == ConstantsData.Terrain.GRASS
				or terrain == ConstantsData.Terrain.FURROWED_GRASS) \
				and not level.plants.has(grass_cell):
			level.set_terrain(grass_cell, ConstantsData.Terrain.HIGH_GRASS)
	if MessageLog:
		MessageLog.add_positive("Nature springs up around the potion.")

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
		acc_multi = item.accuracy_factor(self, target)
	if item is MissileWeapon or item is SpiritBow:
		var momentum: Buff = get_buff("FreerunnerMomentum")
		if momentum != null and momentum.has_method("ranged_accuracy_multiplier"):
			acc_multi *= momentum.ranged_accuracy_multiplier()
	if not Char.hit(self, target, acc_multi):
		on_attack_miss(target)
		return false

	var damage: int = 1
	if item.has_method("damage_roll"):
		damage = item.damage_roll(self)
	for b: Node in _buffs:
		if item is MissileWeapon and b.get("buff_id") == "RingOfForce":
			continue
		if b.has_method("modify_damage"):
			damage = b.modify_damage(damage)

	var effective_damage: int = target.defense_proc(self, damage)
	if effective_damage >= 0:
		effective_damage = maxi(effective_damage - target.dr_roll(), 0)
		if target.has_buff("Vulnerable"):
			effective_damage = int(effective_damage * 1.33)
		if item is MissileWeapon and not (item is SpiritBow):
			effective_damage = _shared_enchantment_proc(item, target, effective_damage)
		if item.has_method("proc_enchantment"):
			effective_damage = item.proc_enchantment(self, target, effective_damage)

	target.take_damage(effective_damage, self)
	on_attack_hit(target, effective_damage)
	if item is MissileWeapon and not (item is SpiritBow):
		_apply_snipers_mark(item, target)
	if EventBus and item is MissileWeapon and not (item is SpiritBow):
		EventBus.game_event.emit("thrown_weapon_hit", {"target_pos": target.pos})
	return true

## Upstream Hero.attackProc (SNIPER): hitting an enemy with a thrown missile
## weapon (not a spirit arrow) marks it for 4 turns. With Shared Upgrades the
## mark lasts min(2*points, weapon level) extra turns and the special shot
## gains 16.67% damage per counted level (max +2/+4/+6 turns, +33%/67%/100%).
## Port adaptation: the mark attaches to the enemy (no actor-id registry), and
## tapping the marked enemy fires the special shot (no ActionIndicator).
func _apply_snipers_mark(missile: MissileWeapon, target: Char) -> void:
	if hero_subclass != ConstantsData.HeroSubclass.SNIPER:
		return
	if target == null or target == self or not target.is_alive:
		return
	if target.is_hero or target.get("is_ally") == true:
		return
	var level_bonus: int = 0
	var points: int = get_talent_level("sniper_shared_upgrades")
	if points > 0:
		level_bonus = mini(2 * points, maxi(0, int(missile.level)))
	var mark: SnipersMark = SnipersMark.new()
	mark.set_duration(SnipersMark.DURATION + float(level_bonus))
	mark.percent_dmg_bonus = float(level_bonus) / 6.0
	target.add_buff(mark)

## True when tapping [target_pos] should fire a sniper special shot: the hero
## is a Sniper and the character there carries her mark.
func _is_sniper_special_target(target_pos: int) -> bool:
	if hero_subclass != ConstantsData.HeroSubclass.SNIPER or level == null:
		return false
	var ch: Variant = level.find_char_at(target_pos)
	return ch is Char and ch != self and (ch as Char).has_buff("SnipersMark")

## Sniper Shared Enchantment (upstream MissileWeapon.proc): thrown-weapon hits
## have a points-in-3 chance to also proc the spirit bow's enchantment.
## forced_roll overrides the random 0-2 roll for deterministic tests.
func _shared_enchantment_proc(
	missile: MissileWeapon, target: Char, damage: int, forced_roll: int = -1
) -> int:
	var points: int = get_talent_level("sniper_shared_enchantment")
	if points <= 0:
		return damage
	var roll: int = forced_roll if forced_roll >= 0 else randi() % 3
	if roll >= points:
		return damage
	if belongings == null or has_buff("MagicImmune"):
		return damage
	var bow: Variant = belongings.find_item_by_id("spirit_bow")
	if bow == null or bow.get("enchantment") == null:
		return damage
	return bow.enchantment.proc(missile, self, target, damage)

func _get_throw_delay(item: Variant) -> float:
	var delay: float = 1.0
	if item != null and item.has_method("speed_factor"):
		delay = item.speed_factor(self)
	if item is MissileWeapon or item is SpiritBow:
		delay = _apply_attack_delay_modifiers(delay)
	return _neutralize_movement_speed_for_action(delay)

func _should_consume_thrown_item(item: Variant) -> bool:
	if item is MissileWeapon and (item as MissileWeapon).does_return():
		return false
	return item is MissileWeapon or item is Bomb

## Warden Durable Tips (upstream TippedDart.durabilityPerUse: use /= 1 + points):
## port adaptation — each tipped dart deterministically survives (1 + points)
## throws before the stack loses a dart, matching upstream expected durability.
func _durable_tips_preserves(missile: MissileWeapon) -> bool:
	if missile == null or not missile.is_tipped_dart():
		return false
	var points: int = get_talent_level("warden_durable_tips")
	if points <= 0:
		return false
	missile.durable_tips_uses += 1
	if missile.durable_tips_uses > points:
		missile.durable_tips_uses = 0
		return false
	return true

## Huntress Durable Projectiles (upstream MissileWeapon.durabilityPerUse:
## usages *= 1.25 + 0.25*points -> x1.5/x1.75 durability): port adaptation —
## the stack accrues fractional wear per throw and only loses a weapon once a
## full point of wear accumulates, giving 50%/75% more throws per stack.
## Checked after Durable Tips so preserved tipped-dart throws add no wear,
## stacking multiplicatively like upstream.
func _durable_projectiles_preserves(missile: MissileWeapon) -> bool:
	if missile == null:
		return false
	var points: int = get_talent_level("huntress_durable_projectiles")
	if points <= 0:
		return false
	missile.durable_wear += 1.0 / (1.25 + 0.25 * points)
	if missile.durable_wear >= 1.0 - 0.0001:
		missile.durable_wear -= 1.0
		if missile.durable_wear < 0.0001:
			missile.durable_wear = 0.0
		return false
	return true

func _consume_thrown_stack_item(item: Variant) -> void:
	if item == null:
		return
	if item.get("quantity") != null:
		item.quantity -= 1
		if item.quantity <= 0:
			belongings.remove_item(item)

func get_auto_ranged_action(target_pos: int) -> Dictionary:
	var blink_action: Dictionary = _get_prep_blink_action(target_pos)
	if not blink_action.is_empty():
		return blink_action
	var ranged_item: Variant = _get_auto_ranged_item(target_pos)
	if ranged_item == null:
		return {}
	var action: Dictionary = {"type": "throw_item", "item": ranged_item, "target_pos": target_pos}
	if ranged_item is SpiritBow and _is_sniper_special_target(target_pos):
		action["sniper_special"] = true
	return action

## Assassin prepared blink-attack (upstream Preparation ActionIndicator; port
## adaptation: tapping a visible enemy within blink range while prepared
## blinks adjacent and attacks in one action instead of using an indicator).
func _get_prep_blink_action(target_pos: int) -> Dictionary:
	if level == null or target_pos < 0 or has_buff("Rooted"):
		return {}
	var prep: Node = get_buff("AssassinPreparation")
	if prep == null or not prep.has_method("blink_distance"):
		return {}
	var blink_range: int = prep.blink_distance()
	if blink_range <= 0:
		return {}
	if target_pos >= level.visible.size() or not level.visible[target_pos]:
		return {}
	var char_at: Variant = level.find_char_at(target_pos)
	if not (char_at is Char) or char_at == self:
		return {}
	var enemy: Char = char_at as Char
	if not enemy.is_alive or enemy.is_hero or enemy.get("is_ally") == true:
		return {}
	var dest: int = _find_prep_blink_dest(target_pos, blink_range)
	if dest < 0:
		return {}
	return {"type": "attack", "target": enemy, "target_pos": target_pos, "blink_pos": dest}

## Upstream Preparation blink dest: distance map over passable cells within
## [blink_range] of the hero (blinking over occupied cells is allowed), then
## the reachable free neighbor of [target_pos] closest to the hero, breaking
## ties by true (euclidean) distance.
func _find_prep_blink_dest(target_pos: int, blink_range: int) -> int:
	var dist_map: Dictionary = {pos: 0}
	var frontier: Array[int] = [pos]
	var depth: int = 0
	while depth < blink_range and not frontier.is_empty():
		depth += 1
		var next_frontier: Array[int] = []
		for cell: int in frontier:
			for n: int in level.get_neighbors(cell):
				if dist_map.has(n) or not level.is_passable(n):
					continue
				dist_map[n] = depth
				next_frontier.append(n)
		frontier = next_frontier
	var dest: int = -1
	for n: int in level.get_neighbors(target_pos):
		if not dist_map.has(n) or level.find_char_at(n) != null:
			continue
		if dest < 0:
			dest = n
			continue
		var d_n: int = int(dist_map[n])
		var d_dest: int = int(dist_map[dest])
		if d_n < d_dest or (d_n == d_dest and _true_dist_sq(pos, n) < _true_dist_sq(pos, dest)):
			dest = n
	return dest

func _true_dist_sq(a: int, b: int) -> int:
	var dx: int = ConstantsData.pos_to_x(a) - ConstantsData.pos_to_x(b)
	var dy: int = ConstantsData.pos_to_y(a) - ConstantsData.pos_to_y(b)
	return dx * dx + dy * dy

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
	# Duelist combo counter (upstream Hero.attack/onAttackComplete: every
	# hit on an enemy feeds Sai.ComboStrikeTracker).
	if hero_class == ConstantsData.HeroClass.DUELIST and target_char != null \
			and not target_char.is_hero \
			and not (target_char is Mob and (target_char as Mob).is_ally):
		var combo: ComboStrikeTracker = get_buff("ComboStrikeTracker") as ComboStrikeTracker
		if combo == null:
			combo = add_buff(ComboStrikeTracker.new()) as ComboStrikeTracker
		if combo != null:
			combo.add_hit()
	if EventBus and target_char != null:
		if EventBus.has_signal("mob_damaged_detailed"):
			EventBus.mob_damaged_detailed.emit(target_char.pos, damage, self)
		else:
			EventBus.mob_damaged.emit(target_char.pos, damage)
		if _pending_surprise_attack:
			EventBus.game_event.emit("surprise_attack", {"target_pos": target_char.pos, "damage": damage})
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
	# Hold Fast (upstream Hero.rest): waiting braces the Warrior on this tile.
	if get_talent_level("warrior_hold_fast") > 0:
		var hold_fast: HoldFastBuff = get_buff("HoldFast") as HoldFastBuff
		if hold_fast == null:
			hold_fast = add_buff(HoldFastBuff.new()) as HoldFastBuff
		if hold_fast != null:
			hold_fast.hold_pos = pos


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
	last_visible_action = "interact"
	last_visible_target_pos = target_pos
	if level.has_method("find_char_at"):
		var target_char: Variant = level.find_char_at(target_pos)
		if target_char != null and target_char != self and target_char is NPC:
			target_char.interact(self)
			return
		# Ally position swap (upstream Char.interact): adjacent by default,
		# at range with Ally Warp — where the swap is also instant/free.
		if target_char != null and target_char != self and target_char is Mob \
				and target_char.can_interact(self):
			_interact_was_free = get_talent_level("mage_ally_warp") > 0
			target_char.interact(self)
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

		ConstantsData.Terrain.CHASM:
			if Chasm.can_cross(self):
				if MessageLog:
					MessageLog.add("You float over the chasm.")
				return
			if MessageLog:
				MessageLog.add_negative("You fall into the chasm!")
			if EventBus and EventBus.has_signal("hero_fell"):
				EventBus.hero_fell.emit(self)
			else:
				Chasm.apply_landing_damage(self, level)

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
			_rejuvenating_steps_step()

		ConstantsData.Terrain.EMBERS:
			# Embers can ignite the hero
			if not has_buff("Fire Immunity") and not has_buff("Brimstone"):
				if randf() < 0.5:
					var burning: Burning = Burning.new()
					add_buff(burning)
					if MessageLog:
						MessageLog.add_negative("The hot embers set you ablaze!")
			_rejuvenating_steps_step()

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
	# SPD computes levelPercent against the current level's requirement BEFORE
	# consuming XP, then lets carried wands regenerate their use-based-ID pool.
	if belongings != null and xp_to_next > 0:
		belongings.notify_hero_gain_exp(float(amount) / float(xp_to_next))

	# Upstream Hero.earnExp counts the Rejuvenating Steps furrow counter down
	# by 200x the level fraction gained, detaching at 0. (Upstream skips this
	# for Potion of Experience; the port's earn_xp has no source, matching the
	# notify_hero_gain_exp precedent above.)
	if xp_to_next > 0 and has_buff("RejuvenatingStepsFurrow"):
		var furrow: Variant = get_buff("RejuvenatingStepsFurrow")
		furrow.count -= (float(amount) / float(xp_to_next)) * 200.0
		if furrow.count <= 0.0:
			remove_buff_by_id("RejuvenatingStepsFurrow")

	xp += amount
	xp_gained.emit(amount)
	if MessageLog:
		MessageLog.add_positive("+%d XP" % amount)

	# Check for level up(s)
	while xp >= xp_to_next and hero_level < ConstantsData.MAX_HERO_LEVEL:
		xp -= xp_to_next
		# Upstream Hero.earnExp: at Wand Preservation +2 the counter detaches
		# on each level-up, making preservation repeatable per hero level.
		if get_talent_level("mage_wand_preservation") >= 2 \
				and has_buff("WandPreservationCounter"):
			remove_buff_by_id("WandPreservationCounter")
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

	if hero_level >= ConstantsData.MAX_HERO_LEVEL and xp >= xp_to_next:
		xp = 0
		var bless: Bless = Bless.new()
		bless.duration = Bless.BASE_DURATION
		bless.time_left = Bless.BASE_DURATION
		add_buff(bless)
		if MessageLog:
			MessageLog.add_positive("You cannot grow stronger, but your experiences give you a surge of power!")
		if AudioManager:
			AudioManager.play_sfx("levelup")
		if EventBus:
			EventBus.hero_stats_changed.emit()

func get_talents() -> Array[TalentData.TalentInfo]:
	return TalentData.get_talents_for(hero_class, hero_subclass)

func get_talent_level(talent_id: String) -> int:
	return talent_levels.get(talent_id, 0)

## Upstream Hero.talentPointsSpent: total points invested in one tier.
func talent_points_spent(tier: int) -> int:
	var total: int = 0
	for talent: TalentData.TalentInfo in get_talents():
		if talent.tier == tier:
			total += get_talent_level(talent.id)
	return total

## Upstream Hero.talentPointsAvailable: per-tier point buckets. Each tier earns
## one point per hero level inside its own level band (2-6 / 7-12 / 13-20 /
## 21-30), minus points already spent in that tier. Tier 3 requires a subclass;
## tier 4 requires an armor ability, which the port does not have yet.
func talent_points_available_for(tier: int) -> int:
	if tier < 1 or tier > 3:
		return 0
	if hero_level < TalentData.tier_unlock_level(tier) - 1:
		return 0
	if tier == 3 and hero_subclass == ConstantsData.HeroSubclass.NONE:
		return 0
	var tier_start: int = TalentData.tier_unlock_level(tier)
	var tier_end: int = TalentData.tier_unlock_level(tier + 1)
	var earned: int = 0
	if hero_level >= tier_end:
		earned = tier_end - tier_start
	else:
		earned = 1 + hero_level - tier_start
	return maxi(0, earned - talent_points_spent(tier))

func total_talent_points_available() -> int:
	var total: int = 0
	for tier: int in range(1, 5):
		total += talent_points_available_for(tier)
	return total

func can_upgrade_talent(talent_id: String) -> bool:
	var talent: TalentData.TalentInfo = TalentData.get_talent(hero_class, talent_id, hero_subclass)
	if talent == null:
		return false
	if not talent.implemented:
		return false
	if hero_level < TalentData.tier_unlock_level(talent.tier):
		return false
	if talent_points_available_for(talent.tier) <= 0:
		return false
	return get_talent_level(talent_id) < talent.max_points

func upgrade_talent(talent_id: String) -> bool:
	if not can_upgrade_talent(talent_id):
		return false
	talent_levels[talent_id] = get_talent_level(talent_id) + 1
	if talent_id == "warrior_strongman":
		update_strongman_bonus()
	# Original: Talent.onTalentUpgraded — reaching Veteran's Intuition +2
	# retroactively identifies the currently worn armor.
	if talent_id == "warrior_veterans_intuition" and talent_levels[talent_id] >= 2:
		var worn_armor: Item = belongings.armor if belongings != null else null
		if worn_armor != null and not worn_armor.is_identified():
			worn_armor.identify()
			if MessageLog:
				MessageLog.add_positive("Your veteran's intuition reveals the %s." % worn_armor.get_display_name())
	if EventBus:
		EventBus.hero_stats_changed.emit()
	if MessageLog:
		var talent: TalentData.TalentInfo = TalentData.get_talent(hero_class, talent_id, hero_subclass)
		if talent != null:
			MessageLog.add_positive("%s improved to %d." % [talent.name, talent_levels[talent_id]])
	return true


## Keep the Strongman talent's live strength bonus in sync. Upstream Hero.STR()
## computes floor(STR * (0.03 + 0.05*points)) dynamically; the port bakes it
## into str_val via a live StrongmanBuff (same contract as Ring of Might's
## MightBuff), so this must be called after talent upgrades, base-strength
## changes (Potion of Strength), and load.
func update_strongman_bonus() -> void:
	var points: int = get_talent_level("warrior_strongman")
	var strongman: StrongmanBuff = get_buff("Strongman") as StrongmanBuff
	if points <= 0:
		if strongman != null:
			remove_buff(strongman)
		return
	if strongman == null:
		strongman = add_buff(StrongmanBuff.new()) as StrongmanBuff
	if strongman != null:
		strongman.update_bonus()


func on_item_picked_up(item: Item) -> void:
	if item == null:
		return

	var warrior_hypothesis: int = get_talent_level("warrior_tested_hypothesis")
	if hero_class == ConstantsData.HeroClass.WARRIOR and warrior_hypothesis > 0:
		if item.item_id == "healing" or item.item_id == "identify":
			_maybe_identify_pickup(item, 0.50 * warrior_hypothesis, "Your practical instincts reveal the %s.")

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

	# Iron Stomach (upstream Talent.onFoodEaten): eating grants a
	# WarriorFoodImmunity buff for the eating cooldown; take_damage quarters
	# (+1) or negates (+2) damage while it lasts. Port eating takes 1 turn.
	var iron_stomach: int = get_talent_level("warrior_iron_stomach")
	if hero_class == ConstantsData.HeroClass.WARRIOR and iron_stomach > 0:
		add_buff(WarriorFoodImmunity.new())
		changed_state = true

	# Empowering Meal (upstream Talent.onFoodEaten): eating grants 1+points
	# (2/3) bonus damage on the next 3 damage-wand zaps via WandEmpower.
	var mage_meal: int = get_talent_level("mage_empowering_meal")
	if hero_class == ConstantsData.HeroClass.MAGE and mage_meal > 0:
		var emp: WandEmpower = WandEmpower.new()
		emp.set_boost(1 + mage_meal, 3)
		add_buff(emp)
		changed_state = true

	# Energizing Meal (upstream Talent.onFoodEaten): eating grants
	# 2+3*points (5/8) turns of Recharging.
	var energizing_meal: int = get_talent_level("mage_energizing_meal")
	if hero_class == ConstantsData.HeroClass.MAGE and energizing_meal > 0:
		var recharge: Recharging = Recharging.new()
		recharge.set_duration(2.0 + 3.0 * energizing_meal)
		add_buff(recharge)
		changed_state = true

	# Mystical Meal (upstream Talent.onFoodEaten): eating grants 1+2*points
	# (3/5) turns of artifact recharging. Port adaptation: applied instantly
	# via _charge_artifacts, like Battlemage Mystical Charge, instead of an
	# over-time ArtifactRecharge buff.
	var mystical_meal: int = get_talent_level("rogue_mystical_meal")
	if hero_class == ConstantsData.HeroClass.ROGUE and mystical_meal > 0:
		_charge_artifacts(1.0 + 2.0 * mystical_meal)
		changed_state = true

	# Invigorating Meal (upstream Talent.onFoodEaten): eating grants the
	# Huntress 0.67+points turns of Haste — effectively 1/2 hastened turns.
	# Port adaptation: same-buff merge keeps the longer remaining duration
	# instead of upstream prolong's flat reset.
	var invigorating_meal: int = get_talent_level("huntress_invigorating_meal")
	if hero_class == ConstantsData.HeroClass.HUNTRESS and invigorating_meal > 0:
		var haste: Haste = Haste.new()
		haste.set_duration(0.67 + float(invigorating_meal))
		add_buff(haste)
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


func on_scroll_read() -> void:
	# Inscribed Stealth (upstream Talent.onScrollUsed): reading a scroll grants
	# the Rogue 1+2*points (3/5) turns of Invisibility. Port adaptation: buff
	# merge keeps the longer remaining duration instead of stacking additively.
	var inscribed: int = get_talent_level("rogue_inscribed_stealth")
	if hero_class == ConstantsData.HeroClass.ROGUE and inscribed > 0:
		var invis: Invisibility = Invisibility.new()
		invis.set_duration(1.0 + 2.0 * inscribed)
		add_buff(invis)
		if EventBus:
			EventBus.hero_stats_changed.emit()
	# Inscribed Power (upstream Talent.onScrollUsed): reading a scroll grants
	# the Mage ScrollEmpower for 1+points (2/3) empowered wand zaps (+2 wand
	# levels each). reset() keeps the higher remaining count on re-read.
	var inscribed_power: int = get_talent_level("mage_inscribed_power")
	if hero_class == ConstantsData.HeroClass.MAGE and inscribed_power > 0:
		var empower: ScrollEmpower = ScrollEmpower.new()
		empower.reset(1 + inscribed_power)
		add_buff(empower)
		if EventBus:
			EventBus.hero_stats_changed.emit()


## Huntress Rejuvenating Steps (upstream Level.occupyCell): stepping on short
## grass or embers sprouts high grass, which the Huntress immediately tramples
## into furrowed grass with the normal trample drop rolls (upstream sets
## HIGH_GRASS then pressCell -> HighGrass.trample huntress branch). Once the
## furrow counter reaches 200 the sprout comes up already furrowed with no
## drops, until exp gain counts it down. 15 - 5*points turn cooldown (10/5).
## Port adaptation: upstream's regen-disabled challenge branch is omitted
## (the port has no challenges).
func _rejuvenating_steps_step() -> void:
	var points: int = get_talent_level("huntress_rejuvenating_steps")
	if points <= 0 or has_buff("RejuvenatingStepsCooldown"):
		return
	if level == null or not level.has_method("set_terrain"):
		return
	var furrow: Variant = get_buff("RejuvenatingStepsFurrow")
	if furrow != null and furrow.count >= 200.0:
		level.set_terrain(pos, ConstantsData.Terrain.FURROWED_GRASS)
	else:
		if furrow == null:
			furrow = add_buff(RejuvenatingStepsFurrow.new())
		furrow.count += float(3 - points)
		level.set_terrain(pos, ConstantsData.Terrain.FURROWED_GRASS)
		if EventBus:
			EventBus.hero_trampled_grass.emit(pos)
		on_trampled_grass()
	var cd := RejuvenatingStepsCooldown.new()
	cd.set_duration(15.0 - 5.0 * float(points))
	add_buff(cd)


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
		if dew != null and level.has_method("drop_item"):
			level.drop_item(pos, dew)
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

	# Rogue Sucker Punch (upstream Talent.onAttackProc): the first surprise
	# attack against each enemy deals points..2 bonus damage; a permanent
	# SuckerPunchTracker on the enemy keeps it once-per-enemy.
	var sucker_punch_level: int = get_talent_level("rogue_sucker_punch")
	if sucker_punch_level > 0 and _pending_surprise_attack \
			and target_char is Mob and not target_char.has_buff("SuckerPunchTracker"):
		result += randi_range(sucker_punch_level, 2)
		target_char.add_buff(SuckerPunchTracker.new())

	var patient_strike_level: int = get_talent_level("duelist_patient_strike")
	if hero_class == ConstantsData.HeroClass.DUELIST and patient_strike_level > 0 and _patient_strike_ready:
		result = roundi(float(result) * (1.10 + 0.15 * patient_strike_level))

	var followup_strike_level: int = get_talent_level("huntress_followup_strike")
	if hero_class == ConstantsData.HeroClass.HUNTRESS and followup_strike_level > 0 and _followup_strike_ready:
		result = roundi(float(result) * (1.10 + 0.15 * followup_strike_level))

	# Battlemage Mystical Charge (upstream MagesStaff.proc head): every staff
	# melee hit instantly grants points/2 turns of artifact recharging via
	# ArtifactRecharge.chargeArtifacts.
	var mystical_level: int = get_talent_level("battlemage_mystical_charge")
	if mystical_level > 0 and belongings != null \
			and belongings.get_equipped_weapon() is MagesStaff:
		_charge_artifacts(float(mystical_level) / 2.0)

	# Battlemage Empowered Strike (upstream MagesStaff.proc): the first staff
	# melee hit after zapping the staff deals x(1 + points/6) damage and
	# consumes the tracker.
	var empowered_level: int = get_talent_level("battlemage_empowered_strikes")
	if empowered_level > 0 and has_buff("EmpoweredStrikeTracker") \
			and belongings != null and belongings.get_equipped_weapon() is MagesStaff:
		result = roundi(float(result) * (1.0 + float(empowered_level) / 6.0))
		remove_buff_by_id("EmpoweredStrikeTracker")

	# Warrior Provoked Anger (upstream Talent.onAttackProc): a physical attack
	# made while the shield-break tracker is active deals +1+2*points bonus
	# damage (3/5) and consumes the tracker.
	var provoked_level: int = get_talent_level("warrior_provoked_anger")
	if provoked_level > 0 and has_buff("ProvokedAngerTracker"):
		result += 1 + 2 * provoked_level
		remove_buff_by_id("ProvokedAngerTracker")

	# Mage Lingering Magic (upstream Talent.onAttackProc): a physical attack
	# made while the zap tracker is active deals +IntRange(points, 2) bonus
	# damage and consumes the tracker.
	var lingering_level: int = get_talent_level("mage_lingering_magic")
	if lingering_level > 0 and has_buff("LingeringMagicTracker"):
		result += randi_range(lingering_level, 2)
		remove_buff_by_id("LingeringMagicTracker")

	# Unarmed monk abilities bypass the weapon, so its enchantment never
	# procs (upstream: wep is null for the whole unarmed strike).
	if belongings != null and not has_buff("UnarmedAbilityTracker"):
		var weapon: Variant = belongings.get_equipped_weapon()
		if weapon != null and weapon.has_method("proc_enchantment"):
			result = weapon.proc_enchantment(self, target_char, result)

	_followup_strike_ready = false
	return maxi(0, result)

## Upstream CloakOfShadows.cloakRecharge: with the Rogue's Light Cloak talent
## the cloak also charges while sitting in the backpack, at 25%/50%/75% of its
## equipped rate (0.75 * points / 3). Equipped cloaks recharge via on_turn.
func _light_cloak_recharge() -> void:
	if belongings == null:
		return
	var points: int = get_talent_level("rogue_light_cloak")
	if points <= 0:
		return
	for item: Variant in belongings.backpack:
		if item is Artifact and (item as Artifact).item_id == "cloak_of_shadows":
			var cloak: Artifact = item as Artifact
			if not cloak.cursed:
				cloak._recharge(cloak.charge_rate * 0.25 * float(points))

## Upstream ArtifactRecharge.chargeArtifacts: instantly charge all equipped
## non-cursed artifacts by `turns` turns' worth of passive charging.
func _charge_artifacts(turns: float) -> void:
	if belongings == null:
		return
	for slot: Item in [belongings.artifact, belongings.misc]:
		if slot is Artifact:
			(slot as Artifact).charge_turns(turns)

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
	# Persist BASE str/hp without live equipped-ring passive bonuses baked in, so
	# reloading (which re-applies those passives) does not double-count them and
	# permanently inflate the hero. See RingOfMight.MightBuff.
	var base_str: int = str_val
	var base_hp_max: int = hp_max
	var base_ht: int = ht
	for b: Node in _buffs:
		if b == null or not is_instance_valid(b):
			continue
		if b.has_method("get_str_contribution"):
			base_str -= int(b.get_str_contribution())
		if b.has_method("get_ht_contribution"):
			var ht_contrib: int = int(b.get_ht_contribution())
			base_hp_max -= ht_contrib
			base_ht -= ht_contrib
	var data: Dictionary = serialize_char({
		"hp_max": base_hp_max,
		"ht": base_ht,
		"str_val": base_str,
	})
	data["hero_class"] = hero_class
	data["hero_subclass"] = hero_subclass
	data["hero_level"] = hero_level
	data["xp"] = xp
	data["xp_to_next"] = xp_to_next
	data["talent_levels"] = talent_levels.duplicate(true)
	data["hero_name"] = hero_name
	data["owner_peer_id"] = owner_peer_id
	data["hero_slot_index"] = hero_slot_index
	data["last_visible_action"] = last_visible_action
	data["last_visible_target_pos"] = last_visible_target_pos
	data["patient_strike_ready"] = _patient_strike_ready
	data["backup_barrier_ready"] = _backup_barrier_ready
	data["followup_strike_ready"] = _followup_strike_ready
	data["belongings"] = belongings.serialize() if belongings != null else {}
	return data

func deserialize(data: Dictionary) -> void:
	deserialize_char(data)
	hero_class = data.get("hero_class", ConstantsData.HeroClass.WARRIOR)
	hero_subclass = data.get("hero_subclass", ConstantsData.HeroSubclass.NONE)
	hero_level = data.get("hero_level", 1)
	xp = data.get("xp", 0)
	xp_to_next = data.get("xp_to_next", ConstantsData.xp_for_level(hero_level))
	# Pre-v6 saves stored a shared "talent_points_available" pool; availability
	# is now derived per tier from hero_level and talent_levels, so it is ignored.
	# Copied element-wise: assigning a JSON-loaded untyped Dictionary to the
	# typed Dictionary[String, int] raises and silently keeps old values.
	talent_levels.clear()
	var loaded_talents: Variant = data.get("talent_levels", {})
	if loaded_talents is Dictionary:
		for talent_key: Variant in (loaded_talents as Dictionary):
			talent_levels[str(talent_key)] = int((loaded_talents as Dictionary)[talent_key])
	# Migrate the retired mage_energizing_upgrade slot (removed upstream) to
	# its replacement Shield Battery, clamped to the new 2-point cap.
	if talent_levels.has("mage_energizing_upgrade"):
		var old_points: int = mini(int(talent_levels["mage_energizing_upgrade"]), 2)
		talent_levels.erase("mage_energizing_upgrade")
		talent_levels["mage_shield_battery"] = maxi(old_points, int(talent_levels.get("mage_shield_battery", 0)))
	# Migrate the retired inert Champion groundwork slots to their upstream
	# replacements (Varied Charge / Twin Upgrades), keeping spent points.
	if talent_levels.has("champion_dual_mastery"):
		var dual_points: int = mini(int(talent_levels["champion_dual_mastery"]), 3)
		talent_levels.erase("champion_dual_mastery")
		talent_levels["champion_varied_charge"] = maxi(dual_points, int(talent_levels.get("champion_varied_charge", 0)))
	if talent_levels.has("champion_guarded_offense"):
		var guarded_points: int = mini(int(talent_levels["champion_guarded_offense"]), 3)
		talent_levels.erase("champion_guarded_offense")
		talent_levels["champion_twin_upgrades"] = maxi(guarded_points, int(talent_levels.get("champion_twin_upgrades", 0)))
	hero_name = data.get("hero_name", HeroClassData.get_class_name_str(hero_class))
	owner_peer_id = int(data.get("owner_peer_id", 1))
	hero_slot_index = int(data.get("hero_slot_index", 0))
	last_visible_action = str(data.get("last_visible_action", ""))
	last_visible_target_pos = int(data.get("last_visible_target_pos", -1))
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
	var artifact_item: Variant = belongings.get_equipped_artifact() if belongings != null else null
	var level_ref: Variant = level if level != null else GameManager.current_level
	if artifact_item != null and artifact_item.has_method("resolve_post_load") and level_ref != null:
		artifact_item.resolve_post_load(self, level_ref)
	# Equipped rings are assigned directly during load, so their passive stat
	# modifiers (e.g. Ring of Might) must be rebuilt on top of the clean base
	# stats that were just restored. See Hero.serialize / RingOfMight.
	if belongings != null:
		for ring_item: Variant in [belongings.ring_left, belongings.ring_right]:
			if ring_item != null and ring_item.has_method("resolve_post_load"):
				ring_item.resolve_post_load(self)
	# Strongman's live strength bonus is not serialized (see StrongmanBuff);
	# rebuild it on top of the restored base stats.
	update_strongman_bonus()
	# Saves from before the WeaponCharger buff existed lack it; a Duelist
	# must always carry the charge pool, so attach one if missing.
	if hero_class == ConstantsData.HeroClass.DUELIST and not has_buff("WeaponCharger"):
		add_buff(WeaponCharger.new())

# ---------------------------------------------------------------------------
# Damage & Death Overrides
# ---------------------------------------------------------------------------

## Override take_damage to emit hero_stats_changed so the HP bar updates.
func take_damage(amount: int, source: Variant = null) -> int:
	# Iron Stomach (upstream Hero.damage WarriorFoodImmunity check): while the
	# eating-turn immunity is active, damage is quartered at +1 and negated at +2.
	if amount > 0 and has_buff("WarriorFoodImmunity"):
		var iron_stomach: int = get_talent_level("warrior_iron_stomach")
		if iron_stomach == 1:
			amount = roundi(float(amount) / 4.0)
		elif iron_stomach >= 2:
			amount = 0
	# Empowered Meditate resistance: 20% damage taken (upstream applies the
	# 0.2x in both Char.attack and Hero.damage; one choke point here covers
	# melee and non-Char sources alike).
	if amount > 0 and has_buff("MeditateResistance"):
		amount = roundi(float(amount) * 0.2)
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

## Death-prevention hook (upstream Berserk.berserking() with Deathless Fury):
## a Berserker at full rage survives a lethal hit behind a fury shield.
func _try_prevent_death(_source: Variant) -> bool:
	var rage_buff: Variant = get_buff("BerserkerRage")
	if rage_buff != null and rage_buff.has_method("try_prevent_death"):
		if rage_buff.try_prevent_death():
			if EventBus:
				EventBus.hero_stats_changed.emit()
			return true
	return false

## Override _on_death to emit the EventBus.hero_died signal so the game
## transitions to the death screen.
func _on_death(source: Variant) -> void:
	super._on_death(source)
	if EventBus:
		EventBus.hero_died_detailed.emit(self)
		var focused_hero: Variant = GameManager.get_local_hero() if GameManager and GameManager.has_method("get_local_hero") else (GameManager.hero if GameManager else null)
		if focused_hero == self:
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
	var current_level_ref: Variant = level if level != null else GameManager.current_level
	if current_level_ref is HallsLevel:
		var halls_cap: int = maxi(1, 26 - int(current_level_ref.get("depth")))
		dist = mini(dist, halls_cap)
	# Sniper Farsight multiplies the final radius, after level caps (upstream
	# Level.updateFieldOfView applies it to the already-capped viewDistance).
	var farsight: int = get_talent_level("sniper_farsight")
	if farsight > 0:
		dist = int(roundf(dist * (1.0 + 0.25 * farsight)))
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
	# Warrior Lethal Momentum (upstream Hero.attackDelay): a pending tracker
	# from a killing blow is consumed so the attack takes no time.
	if has_buff("LethalMomentumTracker"):
		remove_buff_by_id("LethalMomentumTracker")
		return 0.0
	var delay: float = 1.0
	if belongings:
		var equipped_weapon: Variant = belongings.get_equipped_weapon()
		if equipped_weapon and equipped_weapon.has_method("speed_factor"):
			delay = equipped_weapon.speed_factor(self)
	delay = _apply_attack_delay_modifiers(delay)
	return _neutralize_movement_speed_for_action(delay)

func _apply_attack_delay_modifiers(delay: float) -> float:
	for b: Node in _buffs:
		if b.has_method("modify_attack_delay"):
			delay = b.modify_attack_delay(delay)
	return delay

func _neutralize_movement_speed_for_action(delay: float) -> float:
	return delay * get_speed()

func _get_non_movement_action_delay() -> float:
	return _neutralize_movement_speed_for_action(1.0)

# ---------------------------------------------------------------------------
# Damage / Heal Overrides (emit HUD update signals)
# ---------------------------------------------------------------------------

## Flail Spin release (upstream Flail.accuracyFactor + damageRoll): while a
## SpinAbilityTracker is stacked, the next flail attack is a guaranteed hit
## with +spins*(8+2*lvl) bonus damage. The tracker is consumed up front, so
## a defender with infinite evasion still spends the spins (upstream
## detaches in accuracyFactor before the roll resolves).
func attack(target: Char, dmg_multi: float = 1.0, dmg_bonus: float = 0.0, acc_multi: float = 1.0) -> bool:
	var spin: SpinAbilityTracker = get_buff("SpinAbilityTracker") as SpinAbilityTracker
	if spin != null and belongings != null and belongings.weapon is MeleeWeapon \
			and (belongings.weapon as MeleeWeapon).ability_kind() == "spin":
		var weapon: MeleeWeapon = belongings.weapon as MeleeWeapon
		dmg_bonus += float(spin.spins * weapon.spin_boost_per_spin())
		acc_multi = 1.0e9
		remove_buff(spin)
	return super.attack(target, dmg_multi, dmg_bonus, acc_multi)

## Override damage_roll to use equipped weapon's damage calculation.
## Original SPD: Hero.damageRoll() delegates to weapon.damageRoll(this).
func damage_roll() -> int:
	# Monk unarmed abilities ignore the equipped weapon and roll unarmed
	# damage (upstream Hero.damageRoll nulls wep while
	# MonkAbility.UnarmedAbilityTracker is attached; unarmed max = STR-8).
	if has_buff("UnarmedAbilityTracker"):
		var unarmed: int = randi_range(1, maxi(1, str_val - 8))
		for ub: Node in _buffs:
			if ub.has_method("modify_damage"):
				unarmed = ub.modify_damage(unarmed)
		return maxi(0, unarmed)
	if belongings:
		var weapon: Variant = belongings.get_equipped_weapon()
		if weapon and weapon.has_method("damage_roll"):
			var dmg: int = weapon.damage_roll(self)
			# Apply buff modifiers (same as base Char.damage_roll)
			for b: Node in _buffs:
				if b.has_method("modify_damage"):
					dmg = b.modify_damage(dmg)
			return maxi(0, dmg)
		var force_buff: Node = get_buff("RingOfForce")
		if force_buff != null and force_buff.has_method("force_damage_roll"):
			var force_dmg: int = force_buff.force_damage_roll(str_val)
			for b: Node in _buffs:
				if b == force_buff:
					continue
				if b.has_method("modify_damage"):
					force_dmg = b.modify_damage(force_dmg)
			return maxi(0, force_dmg)
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
	# Hold Fast bonus armor while braced (upstream Hero.drRoll)
	var hold_fast: HoldFastBuff = get_buff("HoldFast") as HoldFastBuff
	if hold_fast != null:
		dr += hold_fast.armor_bonus()
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
