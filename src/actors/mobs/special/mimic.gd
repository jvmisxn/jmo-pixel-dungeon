class_name Mimic
extends Mob
## Mimics disguise themselves as item heaps on the ground.
## When a hero tries to pick up the "item," the mimic reveals itself and attacks.
## They are fast, hit hard, and pursue relentlessly once revealed.

## Whether this mimic is still disguised as an item heap.
var disguised: bool = true
## The fake item this mimic appears as (for visual purposes).
var fake_item_id: String = "healing"
## Items stored inside the mimic (dropped on death).
var stored_items: Array = []
## Upstream Mimic.level (setLevel from depth); drives all stats.
var mimic_level: int = 0
## Transient: true while the free interact bite resolves after reveal(), so
## the neutral-alignment combat bonuses still apply (upstream keeps alignment
## NEUTRAL through doAttack and only flips to ENEMY in onAttackComplete).
var _neutral_bite: bool = false

func _init() -> void:
	super._init()
	mob_id = "mimic"
	mob_name = "Mimic"
	description = "Mimics are magical creatures which can take any shape they wish. In dungeons they almost always choose a shape of a treasure chest, in order to lure in unsuspecting adventurers.\n\nMimics have a nasty bite, but often hold more treasure than a regular chest."
	# Baseline = upstream adjustStats(3); scale_to_depth overrides on spawn.
	setup(24, 9, 3, 4, 8, 2)
	xp_value = 0  # Upstream: EXP = 0 — mimics grant no experience.
	max_level = 30
	awareness = 1.0
	aggro_range = 8
	_properties = ["DEMONIC"]
	state = AIState.SLEEPING  # Starts dormant, disguised

## Upstream Mimic.setLevel/adjustStats with level = Dungeon.scalingDepth():
## HP/HT = (1+level)*6, defenseSkill = 2 + level/2, attackSkill = 6 + level,
## damageRoll = 1+level .. 2+2*level, drRoll bonus = NormalIntRange(0, 1+level/2)
## (modeled as armor_value, same as this port's other flat-dr mobs).
func scale_to_depth(p_depth: int) -> void:
	set_mimic_level(p_depth)
	# Port adaptation: disguise as an item heap instead of a chest tile.
	var possible_fakes: Array[String] = ["healing", "upgrade", "iron_key", "gold"]
	fake_item_id = possible_fakes[randi_range(0, possible_fakes.size() - 1)]

func set_mimic_level(p_level: int) -> void:
	mimic_level = p_level
	hp = (1 + p_level) * 6
	hp_max = hp
	ht = hp
	attack_skill = 6 + p_level
	@warning_ignore("integer_division")
	defense_skill = 2 + p_level / 2
	damage_roll_min = 1 + p_level
	damage_roll_max = 2 + 2 * p_level
	@warning_ignore("integer_division")
	armor_value = 1 + p_level / 2
	xp_value = 0

## Upstream Mimic.generatePrize: an extra reward for killing the mimic —
## equal chance of gold, a missile weapon, armor, a melee weapon, or a ring.
func generate_prize(p_depth: int) -> void:
	var reward: Variant = null
	var guard: int = 0
	while reward == null and guard < 10:
		guard += 1
		match randi_range(0, 4):
			0: reward = Generator.random_gold(p_depth)
			1: reward = Generator.random_missile(p_depth)
			2: reward = Generator.random_armor(p_depth)
			3: reward = Generator.random_weapon(p_depth)
			4: reward = Generator.random_ring()
	if reward != null:
		stored_items.append(reward)

## Upstream Mimic.interact gate: a hidden (neutral) mimic can be "opened" by
## an adjacent hero. Once revealed it is hostile and never interactable.
func can_interact(c: Variant) -> bool:
	if disguised and is_alive and c is Hero and level != null \
			and c.get("pos") != null:
		return level.adjacent(pos, int(c.pos))
	return super.can_interact(c)

## Upstream Mimic.interact: opening the "chest" reveals the mimic and, unless
## the hero is invisible (or time-frozen upstream — no such buff in this
## port), it lands a free surprise bite while still neutral: INFINITE_ACCURACY
## and fixed max damage (2 + 2*level). Alignment flips to ENEMY only after the
## bite, so damage-based reveals (take_damage) never get this bonus.
func interact(c: Variant) -> void:
	if not disguised or not (c is Hero):
		super.interact(c)
		return
	var hero: Char = c as Char
	if hero.invisible > 0:
		reveal()
		return
	_neutral_bite = true
	reveal()
	target = hero
	attack(hero)
	_neutral_bite = false

## Upstream attackSkill: INFINITE_ACCURACY while neutral (the interact bite
## is the only attack a hidden mimic can make; invisible heroes skip it).
func accuracy() -> int:
	if disguised or _neutral_bite:
		return 1000000
	return super.accuracy()

## Upstream damageRoll: fixed max damage (2 + 2*level) while neutral.
func damage_roll() -> int:
	if disguised or _neutral_bite:
		return 2 + 2 * mimic_level
	return super.damage_roll()

## Reveal the mimic — called when hero tries to interact with or step on it.
func reveal() -> void:
	if not disguised:
		return
	disguised = false
	state = AIState.HUNTING
	mob_name = "Mimic"
	if MessageLog:
		MessageLog.add_negative("The item was a mimic!")
	if EventBus:
		EventBus.mob_revealed.emit(self)

# --- AI Overrides ---

func _act_sleeping() -> void:
	# While disguised, do nothing — wait to be triggered
	if disguised:
		spend_turn()
		return
	# If woken up (e.g. by AoE), start hunting
	_find_nearest_hero()
	if target != null:
		state = AIState.HUNTING
	spend_turn()

func _act_hunting() -> void:
	if disguised:
		reveal()

	if target == null or not target.is_alive:
		_find_nearest_hero()
		if target == null:
			state = AIState.WANDERING
			return

	# If adjacent, attack
	if is_adjacent(target.pos):
		attack(target)
		spend_attack()
		return

	# Move toward target
	_step_toward(target.pos)
	spend_move()

func _act_wandering() -> void:
	_find_nearest_hero()
	if target != null:
		state = AIState.HUNTING
		return
	# Wander randomly
	var dirs: Array[int] = ConstantsData.DIRS_8.duplicate()
	dirs.shuffle()
	for dir: int in dirs:
		var next: int = pos + dir
		if level and level.is_passable(next) and level.find_char_at(next) == null:
			move_to(next)
			spend_move()
			return
	# Couldn't move anywhere
	spend_turn()

func _find_nearest_hero() -> void:
	_acquire_nearest_hero_target()

## Delegate to base Mob BFS pathfinding instead of greedy approach.
func _step_toward(target_position: int) -> void:
	_move_toward(target_position)

func _on_death(_source: Variant) -> void:
	# Upstream rollToDropLoot: drop every stored item (the original heap item
	# plus the generate_prize reward). No extra invented gold — gold is one of
	# the possible prize rolls.
	if level:
		for item: Variant in stored_items:
			level.drop_item(pos, item)
		level.remove_mob(self)
	if EventBus:
		EventBus.mob_died.emit(self)
	if GameManager:
		GameManager.record_stat("enemies_slain")

## Override take_damage to auto-reveal on hit.
func take_damage(dmg: int, source: Variant = null) -> int:
	if disguised:
		reveal()
	return super.take_damage(dmg, source)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["disguised"] = disguised
	data["fake_item_id"] = fake_item_id
	data["mimic_level"] = mimic_level
	var stored_data: Array[Dictionary] = []
	for item: Variant in stored_items:
		if item != null and item.has_method("serialize"):
			stored_data.append(item.serialize())
	data["stored_items"] = stored_data
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	disguised = bool(data.get("disguised", disguised))
	fake_item_id = str(data.get("fake_item_id", fake_item_id))
	mimic_level = int(data.get("mimic_level", mimic_level))
	stored_items.clear()
	var stored_data: Variant = data.get("stored_items", [])
	if stored_data is Array:
		for item_data: Variant in stored_data:
			if not (item_data is Dictionary):
				continue
			var item_id: String = str((item_data as Dictionary).get("item_id", ""))
			if item_id == "":
				continue
			var item: Variant = Generator.create_item(item_id)
			if item != null and item.has_method("deserialize"):
				item.deserialize(item_data as Dictionary)
				stored_items.append(item)
	if disguised:
		state = AIState.SLEEPING
	else:
		state = AIState.HUNTING
