class_name Goo
extends Mob
## First boss (depth 5). Pumps up for a powerful attack, heals in water.
## Original: Goo.java — HP 100, enrages at half HP, applies Ooze debuff,
## multi-stage pump-up with ranged pumped attack at distance 2.

## Pump-up stage: 0 = normal, 1 = first pump, 2+ = ready to release pumped attack.
var pumped_up: int = 0
## Healing increment in water (original: starts at 1, can increase with Stronger Bosses).
var heal_inc: int = 1
## Whether the floor has been sealed (prevents hero from leaving until boss is dead).
var floor_sealed: bool = false

func _init() -> void:
	super._init()
	mob_id = "goo"
	mob_name = "Goo"
	description = "A massive blob of dark ooze. The first guardian of the dungeon."
	# Original: HP=HT=100, attackSkill=10 (15 when enraged), defenseSkill=8
	setup(100, 10, 8, 1, 8, 2)
	xp_value = 10  # Original: EXP = 10
	max_level = 10
	awareness = 1.0
	aggro_range = 99
	state = AIState.SLEEPING  # Original: Goo starts SLEEPING, wakes on notice()
	_properties = ["BOSS", "DEMONIC", "ACIDIC"]

## Whether Goo is enraged (HP <= HT/2). Affects attack, defense, pump chance.
func is_enraged() -> bool:
	return hp * 2 <= ht

## Original: attackSkill = 10, or 15 when enraged. Pumped attacks double accuracy.
func accuracy() -> int:
	var acc: int = 10
	if is_enraged():
		acc = 15
	if pumped_up > 0:
		acc *= 2
	# Apply buff modifiers
	for b: Node in _buffs:
		if b.has_method("modify_accuracy"):
			acc = b.modify_accuracy(acc)
	return acc

## Original: defenseSkill * 1.5 when enraged.
func evasion() -> int:
	var eva: int = defense_skill
	if is_enraged():
		eva = int(float(eva) * 1.5)
	for b: Node in _buffs:
		if b.has_method("modify_evasion"):
			eva = b.modify_evasion(eva)
	return eva

## Original: damageRoll — base 1-8, or 1-12 when enraged. Pumped: 3x range.
func damage_roll() -> int:
	var min_dmg: int = 1
	var max_dmg: int = 12 if is_enraged() else 8
	if pumped_up > 0:
		pumped_up = 0
		min_dmg *= 3
		max_dmg *= 3
	var dmg: int = randi_range(min_dmg, max_dmg)
	return dmg

## AI: pump up or attack
func _act_hunting() -> void:
	if target == null or not target.is_alive:
		_find_hero_target()
		if target == null:
			return

	# Heal in water
	if _is_in_water():
		if hp < ht:
			heal(heal_inc)

	var dist: int = distance_to(target.pos)

	# Pump up mechanic
	if pumped_up == 0 and dist <= 1:
		# Adjacent: chance to pump up
		if is_enraged() or randf() < 0.33:
			pumped_up = 1
			did_visible_action = true
			if MessageLog:
				MessageLog.add_warning("Goo is pumping up!")
			return

	if pumped_up > 0:
		# Already pumped: release attack
		if dist <= 1:
			attack(target)
			# Apply Ooze debuff
			if target and target.is_alive:
				var ooze: Ooze = Ooze.new()
				target.add_buff(ooze)
		elif dist <= 2:
			# Ranged pumped attack at distance 2
			did_visible_action = true
			var dmg: int = damage_roll()
			target.take_damage(dmg, self)
			if target and target.is_alive:
				var ooze: Ooze = Ooze.new()
				target.add_buff(ooze)
			pumped_up = 0
		else:
			_move_toward(target.pos)
		return

	# Normal behavior
	if is_adjacent(target.pos):
		attack(target)
		# Apply Ooze on hit
		if target and target.is_alive and randf() < 0.5:
			var ooze: Ooze = Ooze.new()
			target.add_buff(ooze)
	else:
		_move_toward(target.pos)

func _is_in_water() -> bool:
	if level and level.has_method("get_terrain"):
		return level.get_terrain(pos) == ConstantsData.Terrain.WATER
	return false

func _find_hero_target() -> void:
	var heroes: Array[Char] = _find_visible_heroes()
	if not heroes.is_empty():
		target = heroes[0]

func _on_death(source: Variant) -> void:
	if MessageLog:
		MessageLog.add_positive("Goo is vanquished! The way forward opens.")
	if level and level.has_method("unlock_exit"):
		level.unlock_exit()
