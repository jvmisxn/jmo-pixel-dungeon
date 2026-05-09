class_name DwarfKing
extends Mob
## Fourth boss (depth 20). Summons undead minions, phases with corpse mechanic.

var phase: int = 1
var summon_cooldown: int = 0
var undead_count: int = 0
const MAX_UNDEAD: int = 4
const SUMMON_INTERVAL: int = 5

func _init() -> void:
	super._init()
	mob_id = "king"
	mob_name = "King of Dwarves"
	description = "The undead king who rules the city with an army of undead servants."
	setup(400, 26, 14, 14, 30, 16)
	xp_value = 80
	max_level = 25
	awareness = 1.0
	aggro_range = 99
	base_speed = 0.9
	state = AIState.HUNTING

func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_find_hero_target()
		if target == null:
			return

	summon_cooldown = maxi(0, summon_cooldown - 1)

	# Phase transition
	@warning_ignore("integer_division")
	var threshold_2: int = hp_max * 2 / 3
	@warning_ignore("integer_division")
	var threshold_3: int = hp_max / 3
	if phase == 1 and hp <= threshold_2:
		phase = 2
		_summon_wave()
		if MessageLog:
			MessageLog.add_warning("\"Kneel before your king!\"")
	elif phase == 2 and hp <= threshold_3:
		phase = 3
		_summon_wave()
		if MessageLog:
			MessageLog.add_negative("\"You will serve me in death!\"")

	# Summon minions periodically
	if summon_cooldown <= 0 and undead_count < MAX_UNDEAD:
		_try_summon()

	# Melee
	if is_adjacent(target.pos):
		attack(target)
		# King's strikes can cripple
		if randf() < 0.3 and target:
			var crip: Cripple = Cripple.new()
			crip.set_duration(3.0)
			target.add_buff(crip)
	else:
		_move_toward(target.pos)

func _summon_wave() -> void:
	for _i: int in range(3):
		_try_summon()

func _try_summon() -> void:
	summon_cooldown = SUMMON_INTERVAL
	did_visible_action = true
	for dir: int in ConstantsData.DIRS_8:
		var spawn_pos: int = pos + dir
		if _can_move_to(spawn_pos):
			var minion: Skeleton = Skeleton.new()
			minion.pos = spawn_pos
			minion.level = level
			minion.state = AIState.HUNTING
			minion.target = target
			# Weaker than normal skeletons
			minion.setup(15, 12, 5, 2, 8, 3)
			if level and level.has_method("add_mob"):
				level.add_mob(minion)
			minion.activate()
			undead_count += 1
			return

func _find_hero_target() -> void:
	var heroes: Array[Char] = _find_visible_heroes()
	if not heroes.is_empty():
		target = heroes[0]

func _on_death(source: Variant) -> void:
	if MessageLog:
		MessageLog.add_positive("The King of Dwarves is slain! The throne room falls silent.")
	if level and level.has_method("unlock_exit"):
		level.unlock_exit()
	super._on_death(source)
