class_name DistortionTrap
extends Trap
## Summons a small pack of mismatched enemies around the trap.
##
## Source notes: upstream SPD's DistortionTrap picks 3-5 open neighbouring
## cells, then spawns a deliberately odd mix: ordinary mobs from random
## non-boss depths, one special mob, and sometimes one rare alternate. The port
## mirrors that structure with currently implemented mob ids and leaves visuals,
## Bestiary accounting, Rat King, exact rare-alt roster, and large/open-space
## filtering as documented omissions for this slice.

const MIN_SUMMONS: int = 3
const MAX_SUMMONS: int = 5
const NON_BOSS_DEPTHS: Array[int] = [
	1, 2, 3, 4,
	6, 7, 8, 9,
	11, 12, 13, 14,
	16, 17, 18, 19,
	21, 22, 23, 24,
]
const SPECIAL_MOB_IDS: Array[String] = [
	"wraith",
	"piranha",
	"mimic",
	"animated_statue",
]
const RARE_ALT_MOB_IDS: Array[String] = [
	"fetid_rat",
	"great_crab",
	"gnoll_trickster",
	"bandit",
	"dm201",
]

func _init() -> void:
	trap_name = "distortion trap"
	color = Color(0.1, 0.75, 0.75)

func _do_effect(_triggerer: Variant, level: Level) -> void:
	if level == null:
		return
	if MessageLog:
		MessageLog.add("Space distorts around the trap!")

	var spawn_cells: Array[int] = _select_spawn_cells(level)
	var occupied_spawn_cells: Array[int] = []
	for i: int in range(spawn_cells.size()):
		var mob: Mob = _create_distorted_mob(i + 1, level.depth)
		if mob == null:
			continue
		_spawn_distorted_mob(mob, spawn_cells[i], level)
		occupied_spawn_cells.append(spawn_cells[i])

	# Upstream processes occupied-cell pressure after all summons appear. Do the
	# same in the port so a mob spawned onto another trap can trigger it.
	for cell: int in occupied_spawn_cells:
		var trap: Variant = level.trap_at(cell) if level.has_method("trap_at") else null
		if trap != null and trap != self and trap.get("active") == true and trap.has_method("activate"):
			trap.activate(level.find_char_at(cell), level)

func _select_spawn_cells(level: Level) -> Array[int]:
	var candidates: Array[int] = []
	for dir: int in ConstantsData.DIRS_8:
		var cell: int = pos + dir
		if not _is_true_neighbour(pos, cell):
			continue
		if level.is_passable(cell) and level.find_char_at(cell) == null:
			candidates.append(cell)
	candidates.shuffle()
	var count: int = _summon_count()
	return candidates.slice(0, mini(count, candidates.size()))

func _create_distorted_mob(summon_number: int, depth: int) -> Mob:
	if MobFactory == null:
		return null
	if summon_number == 2:
		return _create_special_mob(depth)
	if summon_number == 4:
		return _create_rare_alt_mob()
	return MobFactory.create_random_mob(_random_non_boss_depth())

func _create_special_mob(depth: int) -> Mob:
	var mob_id: String = SPECIAL_MOB_IDS[randi_range(0, SPECIAL_MOB_IDS.size() - 1)]
	var mob: Mob = MobFactory.create_mob(mob_id)
	if mob is Mimic:
		mob.disguised = false
		mob.state = Mob.AIState.WANDERING
	elif mob is AnimatedStatue:
		mob.state = Mob.AIState.WANDERING
	return mob

func _create_rare_alt_mob() -> Mob:
	var mob_id: String = RARE_ALT_MOB_IDS[randi_range(0, RARE_ALT_MOB_IDS.size() - 1)]
	return MobFactory.create_mob(mob_id)

func _random_non_boss_depth() -> int:
	return NON_BOSS_DEPTHS[randi_range(0, NON_BOSS_DEPTHS.size() - 1)]

func _summon_count() -> int:
	var count: int = MIN_SUMMONS
	if randi_range(0, 1) == 0:
		count += 1
		if randi_range(0, 1) == 0:
			count += 1
	return count

func _is_true_neighbour(center: int, cell: int) -> bool:
	if not ConstantsData.is_valid_pos(center) or not ConstantsData.is_valid_pos(cell):
		return false
	var cx: int = center % ConstantsData.WIDTH
	var cy: int = center / ConstantsData.WIDTH
	var x: int = cell % ConstantsData.WIDTH
	var y: int = cell / ConstantsData.WIDTH
	return maxi(absi(cx - x), absi(cy - y)) == 1

func _spawn_distorted_mob(mob: Mob, spawn_pos: int, level: Level) -> void:
	if mob == null:
		return
	mob.pos = spawn_pos
	mob.level = level
	mob.max_level = ConstantsData.MAX_HERO_LEVEL - 1
	if mob.state != Mob.AIState.PASSIVE:
		mob.state = Mob.AIState.WANDERING
	level.add_mob(mob)
	if TurnManager:
		TurnManager.add_actor(mob)
