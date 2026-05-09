class_name Yog
extends Mob
## Final boss (depth 25). Immobile core with fists and lasers.
## Spawns RottingFist and BurningFist. Must destroy fists to damage Yog.

var fists_spawned: bool = false
var laser_cooldown: int = 0
const LASER_INTERVAL: int = 3
const LASER_DAMAGE: int = 25

func _init() -> void:
	super._init()
	mob_id = "yog"
	mob_name = "Yog-Dzewa"
	description = "An ancient evil that lurks at the bottom of the dungeon. The source of all darkness."
	setup(500, 10, 20, 0, 0, 20)
	xp_value = 100
	max_level = 30
	awareness = 1.0
	aggro_range = 99
	base_speed = 0.5
	state = AIState.HUNTING

func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_find_hero_target()
		if target == null:
			spend_turn()
			return

	# Spawn fists on first sight
	if not fists_spawned:
		_spawn_fists()
		fists_spawned = true
		spend_turn()
		return

	laser_cooldown = maxi(0, laser_cooldown - 1)

	# Fire laser at target
	if laser_cooldown <= 0 and can_see(target.pos):
		_fire_laser()
		spend_attack()
		return

	# Yog doesn't move — it's stationary
	spend_turn()

func _spawn_fists() -> void:
	# Spawn Rotting Fist
	var rotting: YogFist = YogFist.new()
	rotting.mob_name = "Rotting Fist"
	rotting.mob_id = "rotting_fist"
	rotting.setup(200, 22, 10, 12, 28, 14)
	rotting.fist_type = YogFist.FistType.ROTTING
	_place_fist(rotting)

	# Spawn Burning Fist
	var burning: YogFist = YogFist.new()
	burning.mob_name = "Burning Fist"
	burning.mob_id = "burning_fist"
	burning.setup(200, 22, 10, 10, 24, 10)
	burning.fist_type = YogFist.FistType.BURNING
	_place_fist(burning)

	if MessageLog:
		MessageLog.add_negative("Yog-Dzewa awakens its fists!")

func _place_fist(fist: YogFist) -> void:
	fist.level = level
	fist.state = AIState.HUNTING
	fist.target = target
	# Find position near Yog
	for dir: int in ConstantsData.DIRS_8:
		var spawn_pos: int = pos + dir
		if _can_move_to(spawn_pos):
			fist.pos = spawn_pos
			if level and level.has_method("add_mob"):
				level.add_mob(fist)
			fist.activate()
			return

func _fire_laser() -> void:
	laser_cooldown = LASER_INTERVAL
	if target == null:
		return
	target.take_damage(LASER_DAMAGE, self)
	if MessageLog:
		MessageLog.add_negative("Yog-Dzewa fires a beam of dark energy!")

func _find_hero_target() -> void:
	var heroes: Array[Char] = _find_visible_heroes()
	if not heroes.is_empty():
		target = heroes[0]

func _on_death(source: Variant) -> void:
	if MessageLog:
		MessageLog.add_positive("Yog-Dzewa is destroyed! Light floods the dungeon!")
	if level and level.has_method("unlock_exit"):
		level.unlock_exit()
	super._on_death(source)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["fists_spawned"] = fists_spawned
	data["laser_cooldown"] = laser_cooldown
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	fists_spawned = bool(data.get("fists_spawned", fists_spawned))
	laser_cooldown = int(data.get("laser_cooldown", laser_cooldown))
