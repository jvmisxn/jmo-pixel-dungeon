class_name Swarm
extends Mob
## Swarm of Flies: splits into a smaller swarm when damaged below half HP.

var has_split: bool = false

func _init() -> void:
	super._init()
	mob_id = "swarm"
	mob_name = "Swarm of Flies"
	description = "A buzzing cloud of biting flies. Damaging it may cause it to split."
	setup(12, 10, 5, 1, 4, 0, 1.2)
	xp_value = 3
	max_level = 7
	awareness = 0.3
	aggro_range = 8
	loot_table = [{"item_id": "healing", "chance": 0.15}]

## When damaged below half HP, split into a new smaller swarm.
func take_damage(dmg: int, source: Variant = null) -> int:
	var actual: int = super.take_damage(dmg, source)
	if actual > 0 and is_alive and not has_split and hp <= hp_max / 2:
		_split()
	return actual

func _split() -> void:
	has_split = true
	did_visible_action = true
	if level == null:
		return
	# Find an adjacent empty cell for the new swarm
	var spawn_pos: int = -1
	for dir: int in ConstantsData.DIRS_8:
		var adj: int = pos + dir
		if _can_move_to(adj):
			spawn_pos = adj
			break
	if spawn_pos < 0:
		return  # No room to split
	# Create the child swarm
	var child: Swarm = Swarm.new()
	child.has_split = true  # Children don't split again
	child.hp = hp  # Share remaining HP
	child.hp_max = hp_max
	child.ht = hp
	child.state = AIState.HUNTING
	child.target = target
	child.pos = spawn_pos
	child.level = level
	if level.has_method("add_mob"):
		level.add_mob(child)
	if TurnManager:
		TurnManager.add_actor(child)
	if MessageLog:
		MessageLog.add_warning("The swarm splits in two!")

func scale_to_depth(p_depth: int) -> void:
	var scale: int = maxi(0, p_depth - 1)
	hp = 12 + scale * 2
	hp_max = hp
	ht = hp
	damage_roll_min = 1 + scale
	damage_roll_max = 4 + scale
	attack_skill = 10 + scale
	defense_skill = 5 + scale

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["has_split"] = has_split
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	has_split = bool(data.get("has_split", has_split))
