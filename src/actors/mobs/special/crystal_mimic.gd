class_name CrystalMimic
extends Mimic
## Upstream CrystalMimic.java: a mimic disguised as a crystal chest. Its free
## neutral bite deals NORMAL damage (no fixed-max bonus) but steals a random
## unequipped item instead. On reveal it Hastes and FLEES rather than hunting;
## while hostile, its bites teleport the victim aside before it bolts. If it
## gets out of sight and 6+ tiles away it escapes with everything it holds.

## True while a take_damage reveal is resolving (upstream: damage reveals get
## the 1-turn Haste; the neutral interact reveal gets 2 turns).
var _damage_reveal: bool = false


func _init() -> void:
	super._init()
	mob_id = "crystal_mimic"
	# Upstream name(): reads as the crystal chest heap until revealed.
	mob_name = "Crystal chest"
	description = "Mimics are magical creatures which can take any shape they " \
		+ "wish. A crystal mimic almost perfectly imitates a crystal chest, " \
		+ "and pilfers treasure rather than fighting fair. Once it has " \
		+ "stolen something it will attempt to flee with its loot!"


## Upstream CrystalMimic has no neutral fixed-max damage bonus — it steals
## instead (see attack_proc). INFINITE_ACCURACY is inherited unchanged.
func _neutral_bonus_damage() -> bool:
	return false


## Upstream attackProc: while neutral, steal from the hero; while hostile,
## blink the victim to a random free adjacent cell and switch to fleeing.
func attack_proc(enemy: Char, damage: int) -> int:
	if (disguised or _neutral_bite) and enemy is Hero:
		_steal(enemy)
	else:
		_fling_aside(enemy)
		if not disguised:
			_set_state(AIState.FLEEING)
	return super.attack_proc(enemy, damage)


## Upstream steal(): pick a random unequipped, non-unique, non-upgraded item
## from the hero's backpack and swallow one unit of it into stored_items.
## (Upstream rolls randomUnequipped() up to 10 times; filtering candidates
## up front is equivalent for this port's flat backpack.)
func _steal(hero: Hero) -> void:
	var candidates: Array = []
	for it: Variant in hero.belongings.backpack:
		if it != null and not it.unique and it.level < 1:
			candidates.append(it)
	if candidates.is_empty():
		return
	var item: Item = candidates[randi_range(0, candidates.size() - 1)]
	var stolen: Item = item
	if item.stackable and item.quantity > 1:
		stolen = item.split(1)
	else:
		hero.belongings.remove_item(item)
	if stolen != null:
		stored_items.append(stolen)
		if MessageLog:
			MessageLog.add_negative(
				"The crystal mimic ate your %s!" % stolen.get_display_name())


## Upstream hostile attackProc: ScrollOfTeleportation.appear moves the victim
## to a random passable, unoccupied cell adjacent to the mimic.
func _fling_aside(enemy: Char) -> void:
	if level == null or enemy == null:
		return
	var candidates: Array[int] = []
	for dir: int in ConstantsData.DIRS_8:
		var cell: int = pos + dir
		if level.is_passable(cell) and level.find_char_at(cell) == null:
			candidates.append(cell)
	if candidates.is_empty():
		return
	var new_pos: int = candidates[randi_range(0, candidates.size() - 1)]
	enemy.pos = new_pos
	if enemy is Hero and EventBus:
		EventBus.hero_moved_detailed.emit(enemy, new_pos)


## Upstream stopHiding: the crystal mimic flees instead of hunting, with a
## short Haste burst (2 turns off the neutral interact reveal, 1 otherwise).
func reveal() -> void:
	if not disguised:
		return
	disguised = false
	mob_name = "Crystal mimic"
	_set_state(AIState.FLEEING)
	var haste: Haste = Haste.new()
	var dur: float = 1.0 if _damage_reveal else 2.0
	haste.duration = dur
	haste.time_left = dur
	add_buff(haste)
	if target == null:
		_find_nearest_hero()
	if MessageLog:
		MessageLog.add_negative("The chest was a crystal mimic!")
	if EventBus:
		EventBus.mob_revealed.emit(self)


func take_damage(dmg: int, source: Variant = null) -> int:
	_damage_reveal = disguised
	var result: int = super.take_damage(dmg, source)
	_damage_reveal = false
	return result


## Upstream generatePrize: no extra reward — the chest's own contents are the
## prize, guaranteed uncursed.
func generate_prize(_p_depth: int) -> void:
	for item: Variant in stored_items:
		if item != null:
			item.cursed = false
			item.cursed_known = true


## Upstream Fleeing.escaped(): once out of the hero's sight and 6+ tiles away
## the mimic vanishes with its loot. nowhereToRun keeps upstream's turn-and-
## fight fallback via the base class, sped up by the standing Haste.
func _act_fleeing() -> void:
	if target == null or not target.is_alive:
		_find_nearest_hero()
	if target == null:
		_set_state(AIState.WANDERING)
		spend_turn()
		return
	_move_away_from(target.pos)
	spend_move()
	if not can_see(target.pos) and distance_to(target.pos) >= 6:
		_escape()


func _escape() -> void:
	if MessageLog:
		MessageLog.add_negative("The crystal mimic has escaped with its loot!")
	is_alive = false
	if level:
		level.remove_mob(self)


func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	if disguised:
		mob_name = "Crystal chest"
	else:
		# Base Mimic resumes HUNTING; a revealed crystal mimic flees.
		mob_name = "Crystal mimic"
		state = AIState.FLEEING
