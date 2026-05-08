class_name Mimic
extends Mob
## Mimics disguise themselves as item heaps on the ground.
## When a hero tries to pick up the "item," the mimic reveals itself and attacks.
## They are fast, hit hard, and pursue relentlessly once revealed.

## Whether this mimic is still disguised as an item heap.
var disguised: bool = true
## The fake item this mimic appears as (for visual purposes).
var fake_item_id: String = "potion_of_healing"
## Items stored inside the mimic (dropped on death).
var stored_items: Array = []

func _init() -> void:
	super._init()
	mob_id = "mimic"
	mob_name = "Mimic"
	description = "What appeared to be a treasure chest is actually a toothy predator!"
	setup(25, 15, 10, 5, 12, 6, 1.5)  # Fast and hits hard
	xp_value = 6
	max_level = 30
	awareness = 1.0
	aggro_range = 8
	state = AIState.SLEEPING  # Starts dormant, disguised

## Scale stats based on dungeon depth.
func scale_to_depth(p_depth: int) -> void:
	@warning_ignore("integer_division")
	var tier: int = 1 + p_depth / 5
	hp = 15 + tier * 8
	hp_max = hp
	ht = hp
	attack_skill = 10 + tier * 4
	defense_skill = 5 + tier * 2
	damage_roll_min = 3 + tier * 2
	damage_roll_max = 8 + tier * 3
	armor_value = 2 + tier * 2
	xp_value = 4 + tier * 2
	# Generate appropriate fake loot appearance
	var possible_fakes: Array[String] = ["potion_of_healing", "scroll_of_upgrade", "iron_key", "gold"]
	fake_item_id = possible_fakes[randi_range(0, possible_fakes.size() - 1)]

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
		return
	# If woken up (e.g. by AoE), start hunting
	_find_nearest_hero()
	if target != null:
		state = AIState.HUNTING

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
		return

	# Move toward target
	_step_toward(target.pos)

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
			return

func _find_nearest_hero() -> void:
	_acquire_nearest_hero_target()

## Delegate to base Mob BFS pathfinding instead of greedy approach.
func _step_toward(target_position: int) -> void:
	_move_toward(target_position)

func _on_death(_source: Variant) -> void:
	# Drop stored items
	if level:
		for item: Variant in stored_items:
			level.drop_item(pos, item)
		# Also drop some gold
		var gold_item: Variant = Generator.create_item("gold") if Generator else null
		if gold_item:
			level.drop_item(pos, gold_item)
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
