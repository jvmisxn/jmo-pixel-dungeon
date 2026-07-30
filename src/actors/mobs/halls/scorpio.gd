class_name Scorpio
extends Mob
## Scorpio (upstream Scorpio.java). Demonic ranged attacker: fires crippling
## serrated spikes at any visible enemy, refuses melee (never attacks an
## adjacent target), and backs away while hunting to keep firing distance.
## Port adaptation: the upstream Ballistica PROJECTILE shot check maps to
## this port's `can_see` LOS gate, matching the other ranged mobs here.

func _init() -> void:
	super._init()
	mob_id = "scorpio"
	mob_name = "Scorpio"
	description = "These huge arachnid-like demonic creatures avoid close combat by all means, firing crippling serrated spikes from long distances."
	# Upstream: HP 110, attackSkill 36, defenseSkill 24, damage 30-40,
	# drRoll super + NormalIntRange(0, 16), viewDistance = Light.DISTANCE.
	setup(110, 36, 24, 30, 40, 16)
	xp_value = 14
	max_level = 27
	awareness = 0.5
	aggro_range = 8
	base_speed = 1.0
	_properties = ["DEMONIC"]
	# Loot handled by _drop_loot/create_loot below (upstream: POTION
	# category at 50%, rerolled so it is never healing or strength).
	loot_table = []

func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_set_state(AIState.WANDERING)
		spend_turn()
		return
	# Upstream canAttack: never adjacent, needs a clear shot.
	if not is_adjacent(target.pos) and can_see(target.pos) and target.invisible <= 0:
		attack(target)
		spend_attack()
		return
	# Upstream getCloser while HUNTING calls getFurther instead: the scorpio
	# retreats to regain firing distance rather than closing in.
	_move_away_from(target.pos)
	spend_move()

## Upstream attackProc: Random.Int(2) == 0 -> Cripple.prolong(DURATION).
func attack_proc(enemy: Char, damage: int) -> int:
	damage = super.attack_proc(enemy, damage)
	if enemy != null and randi_range(0, 1) == 0:
		apply_cripple(enemy)
	return damage

## Split out so tests can exercise the cripple application deterministically.
func apply_cripple(enemy: Char) -> void:
	var crip: Cripple = Cripple.new()
	crip.set_duration(Cripple.BASE_DURATION)
	enemy.add_buff(crip)

## Upstream: loot = POTION, lootChance = 0.5 -> createLoot().
func _drop_loot(killer: Variant = null) -> void:
	if level == null or not level.has_method("drop_item"):
		return
	if randf() >= 0.5 * _loot_chance_multiplier(killer):
		return
	var item: Item = create_loot()
	if item != null:
		level.drop_item(pos, item)

## Upstream createLoot: a random potion, rerolled while it is healing or
## strength.
func create_loot() -> Item:
	var potion_id: String = _random_loot_potion_id()
	return Generator.create_item(potion_id) if Generator else null

func _random_loot_potion_id() -> String:
	var pool: Array[String] = []
	for potion_id: String in Generator._POTION_IDS:
		if potion_id != "healing" and potion_id != "strength":
			pool.append(potion_id)
	if pool.is_empty():
		return "mind_vision"
	return pool[randi_range(0, pool.size() - 1)]
