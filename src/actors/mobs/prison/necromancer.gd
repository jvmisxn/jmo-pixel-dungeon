class_name Necromancer
extends Mob
## Dark mage that raises and maintains a linked skeleton.
## Original: Necromancer.java — summons ONE linked skeleton near the enemy,
## heals it (HT/5 per turn) or gives it Adrenaline, re-teleports it if stuck,
## and when the necromancer dies, its linked skeleton dies too.
## The necromancer CANNOT directly attack — it only acts through its skeleton.

## The necromancer's linked skeleton. Only one at a time.
var my_skeleton: Mob = null
## Whether currently in the process of summoning.
var summoning: bool = false
## Position where the skeleton will be summoned.
var summoning_pos: int = -1
## First summon is faster (1 turn instead of 2).
var first_summon: bool = true
## Cooldown between healing/buffing zaps to the skeleton.
var zap_cooldown: int = 0
## Saved actor_id of the linked skeleton for post-load relinking.
var _saved_skeleton_actor_id: int = -1

func _init() -> void:
	super._init()
	mob_id = "necromancer"
	mob_name = "Necromancer"
	description = "A dark mage that raises the dead to fight for it. Kill the necromancer to destroy its skeleton."
	# Original: HP=HT=40, attackSkill (irrelevant, can't attack), defenseSkill=14, DR 0-5
	setup(40, 0, 14, 0, 0, 5)
	xp_value = 7
	max_level = 14
	awareness = 0.4
	aggro_range = 10
	loot_table = [{"item_id": "potion_healing", "chance": 0.2}]
	_properties = ["UNDEAD"]

## Necromancer cannot directly attack.
func attack(_target_char: Char, _dmg_multi: float = 1.0, _dmg_bonus: float = 0.0, _acc_multi: float = 1.0) -> bool:
	return false

func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_find_hero_target()
		if target == null:
			_set_state(AIState.WANDERING)
			spend_turn()
			return

	zap_cooldown = maxi(0, zap_cooldown - 1)
	_refresh_linked_skeleton()

	if my_skeleton == null:
		if not summoning:
			summoning_pos = _find_summon_position()
			if summoning_pos >= 0:
				summoning = true
				did_visible_action = true
				if MessageLog:
					MessageLog.add_warning("The necromancer begins raising a skeleton!")
		else:
			_complete_summon()
		spend_turn()
		return

	if my_skeleton.target == null or not my_skeleton.target.is_alive:
		my_skeleton.target = target
		my_skeleton.target_pos = target.pos
		my_skeleton.state = AIState.HUNTING

	if zap_cooldown <= 0 and can_see(my_skeleton.pos):
		if my_skeleton.hp < my_skeleton.ht:
			_support_skeleton_heal()
		elif not my_skeleton.has_buff("Adrenaline"):
			_support_skeleton_adrenaline()
		else:
			_move_away_from(target.pos)
			spend_move()
			return
		spend_turn()
		return

	var dist: int = distance_to(target.pos)
	if dist <= 3:
		_move_away_from(target.pos)
		spend_move()
	else:
		spend_turn()

func _find_hero_target() -> void:
	var heroes: Array[Char] = _find_visible_heroes()
	if not heroes.is_empty():
		target = heroes[0]
		target_pos = target.pos

func _refresh_linked_skeleton() -> void:
	if my_skeleton != null and (not is_instance_valid(my_skeleton) or not my_skeleton.is_alive):
		my_skeleton = null

func _find_summon_position() -> int:
	if level == null or target == null:
		return -1
	for dir: int in ConstantsData.DIRS_8:
		var candidate: int = target.pos + dir
		if _can_move_to(candidate):
			return candidate
	for dir: int in ConstantsData.DIRS_8:
		var candidate: int = pos + dir
		if _can_move_to(candidate):
			return candidate
	return -1

func _complete_summon() -> void:
	if level == null or summoning_pos < 0:
		summoning = false
		return
	var skeleton: Skeleton = Skeleton.new()
	skeleton.pos = summoning_pos
	skeleton.level = level
	skeleton.state = AIState.HUNTING
	skeleton.target = target
	skeleton.target_pos = target.pos if target != null else -1
	if level.has_method("add_mob"):
		level.add_mob(skeleton)
	skeleton.activate()
	my_skeleton = skeleton
	summoning = false
	summoning_pos = -1
	first_summon = false
	did_visible_action = true
	if MessageLog:
		MessageLog.add_negative("A skeleton rises to defend the necromancer!")

func _support_skeleton_heal() -> void:
	if my_skeleton == null:
		return
	zap_cooldown = 2
	did_visible_action = true
	var heal_amount: int = maxi(1, int(my_skeleton.ht / 5))
	my_skeleton.heal(heal_amount)
	if MessageLog:
		MessageLog.add_negative("The necromancer restores its skeleton!")

func _support_skeleton_adrenaline() -> void:
	if my_skeleton == null:
		return
	zap_cooldown = 3
	did_visible_action = true
	var adrenal: Adrenaline = Adrenaline.new()
	my_skeleton.add_buff(adrenal)
	if MessageLog:
		MessageLog.add_negative("The necromancer hastens its skeleton!")

func _on_death(source: Variant) -> void:
	_refresh_linked_skeleton()
	if my_skeleton != null and my_skeleton.is_alive:
		my_skeleton.take_damage(my_skeleton.hp_max + my_skeleton.shielding, self)
	super._on_death(source)

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["summoning"] = summoning
	data["summoning_pos"] = summoning_pos
	data["first_summon"] = first_summon
	data["zap_cooldown"] = zap_cooldown
	data["my_skeleton_actor_id"] = my_skeleton.actor_id if is_instance_valid(my_skeleton) else -1
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	summoning = data.get("summoning", false)
	summoning_pos = data.get("summoning_pos", -1)
	first_summon = data.get("first_summon", true)
	zap_cooldown = data.get("zap_cooldown", 0)
	_saved_skeleton_actor_id = int(data.get("my_skeleton_actor_id", -1))
	my_skeleton = null

func resolve_post_load(level_ref: Level) -> void:
	if _saved_skeleton_actor_id < 0 or level_ref == null:
		return
	for mob_ref: Variant in level_ref.mobs:
		if mob_ref == null or not is_instance_valid(mob_ref):
			continue
		if mob_ref.get("actor_id") == _saved_skeleton_actor_id:
			my_skeleton = mob_ref as Mob
			break
	_saved_skeleton_actor_id = -1
