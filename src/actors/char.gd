class_name Char
extends Actor
## Base class for all characters (hero, mobs) — anything with HP, combat stats,
## and the ability to attack/defend. Manages buffs and provides the combat interface.

# --- Signals ---
@warning_ignore("unused_signal")
signal damaged(amount: int, source: Variant)
@warning_ignore("unused_signal")
signal healed(amount: int)
@warning_ignore("unused_signal")
signal died
@warning_ignore("unused_signal")
signal buff_added(buff: Node)
@warning_ignore("unused_signal")
signal buff_removed(buff: Node)

# --- Stats ---
var hp: int = 1
var hp_max: int = 1
var ht: int = 1  # max HP at current level (base, before buffs)
var shielding: int = 0
var str_val: int = 10  # strength
var base_speed: float = 1.0

# --- Combat Stats ---
var attack_skill: int = 10
var defense_skill: int = 5
var damage_roll_min: int = 1
var damage_roll_max: int = 4
var armor_value: int = 0

# --- State ---
var is_alive: bool = true
var enemy: Char = null  # current target
var sprite: Node = null  # visual representation
var last_damage_source: Variant = null  # tracks what last dealt damage (for death cause)
var flying: bool = false  # can fly over chasms/water without penalty

# --- Buffs ---
var _buffs: Array[Node] = []

# --- Properties ---
var is_hero: bool = false  # Override in Hero class
var invisible: int = 0  # >0 means invisible; incremented by Invisibility buff
var paralysed: int = 0  # >0 means paralysed; incremented by Frost/Paralysis buffs

# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------

## Roll attack accuracy (base + modifiers from buffs).
func accuracy() -> int:
	var acc: int = attack_skill
	for b: Node in _buffs:
		if b.has_method("modify_accuracy"):
			acc = b.modify_accuracy(acc)
	return acc

## Roll evasion (defense skill + modifiers).
func evasion() -> int:
	var eva: int = defense_skill
	for b: Node in _buffs:
		if b.has_method("modify_evasion"):
			eva = b.modify_evasion(eva)
	return eva

## Roll damage for an attack. Uses triangular distribution approximating SPD's
## Random.NormalIntRange(min, max) — a bell curve favoring the middle, matching
## the original Mob.damageRoll(). dr_roll() and Weapon.damage_roll() share this shape.
func damage_roll() -> int:
	# Triangular distribution: average of two uniform rolls approximates NormalIntRange
	var roll_a: int = randi_range(damage_roll_min, damage_roll_max)
	var roll_b: int = randi_range(damage_roll_min, damage_roll_max)
	@warning_ignore("integer_division")
	var dmg: int = (roll_a + roll_b) / 2
	for b: Node in _buffs:
		if b.has_method("modify_damage"):
			dmg = b.modify_damage(dmg)
	return maxi(0, dmg)

## Get effective armor value.
func effective_armor() -> int:
	var armor: int = armor_value
	for b: Node in _buffs:
		if b.has_method("modify_armor"):
			armor = b.modify_armor(armor)
	return maxi(0, armor)

## Attempt to attack a target character. Returns true if hit landed.
## Matches original SPD Char.attack(enemy, dmgMulti, dmgBonus, accMulti).
func attack(target: Char, dmg_multi: float = 1.0, dmg_bonus: float = 0.0, acc_multi: float = 1.0) -> bool:
	if target == null or not target.is_alive:
		return false

	# Invulnerability check (original: isInvulnerable)
	if target.is_invulnerable(self):
		return false

	if hit(self, target, acc_multi):
		# Hit — roll damage
		var dmg: float = float(damage_roll())

		# Damage multiplier and bonus
		dmg = dmg * dmg_multi + dmg_bonus

		# Berserk damage factor
		var berserk_buff: Node = get_buff("BerserkerRage")
		if berserk_buff and berserk_buff.has_method("damage_factor"):
			dmg = berserk_buff.damage_factor(dmg)

		# Weakness: 0.67x damage
		if has_buff("Weakness"):
			dmg *= 0.67

		# defenseProc (pre-armor: earthroot, glyphs, etc.)
		var effective_dmg: int = target.defense_proc(self, roundi(dmg))

		# Armor reduction (only if defenseProc didn't return negative)
		if effective_dmg >= 0:
			var dr: int = target.dr_roll()
			effective_dmg = maxi(effective_dmg - dr, 0)

			# Vulnerable: 1.33x AFTER armor (original: effectiveDamage *= 1.33f)
			if target.has_buff("Vulnerable"):
				effective_dmg = int(effective_dmg * 1.33)

			# attackProc (post-armor: enchantments, etc.)
			effective_dmg = attack_proc(target, effective_dmg)

		# Apply damage
		target.take_damage(effective_dmg, self)
		on_attack_hit(target, effective_dmg)

		# Notify buffs of damage dealt
		for b: Node in _buffs:
			if b.has_method("on_damage_dealt"):
				b.on_damage_dealt(effective_dmg, target)
		return true
	else:
		# Miss
		on_attack_miss(target)
		for b: Node in target._buffs:
			if b.has_method("on_damage_taken"):
				b.on_damage_taken(0, self)
		return false

## SPD hit formula: Random.Float(acuStat) >= Random.Float(defStat) with buff modifiers.
## This dual-roll system has higher variance than a deterministic formula.
static func hit(attacker: Char, defender: Char, acc_multi: float = 1.0) -> bool:
	var acu_stat: float = float(attacker.accuracy())
	var def_stat: float = float(defender.evasion())

	# Guaranteed hit when the defender is surprised: an invisible attacker, or
	# (for mobs) one the defender cannot see/detect — sleeping, unaware, stealth.
	# Mirrors SPD, where a surprised defender has 0 effective evasion.
	if attacker.can_surprise_attack() and defender.is_surprised_by(attacker):
		return true

	# Infinite evasion beats infinite accuracy
	if def_stat >= 1000000.0:
		return false
	if acu_stat >= 1000000.0:
		return true

	# Roll accuracy: Random.Float(acuStat) with buff modifiers
	var acu_roll: float = randf() * acu_stat
	if attacker.has_buff("Bless"):
		acu_roll *= 1.25
	if attacker.has_buff("Hex"):
		acu_roll *= 0.8
	if attacker.has_buff("Daze"):
		acu_roll *= 0.5
	acu_roll *= acc_multi

	# Roll defense: Random.Float(defStat) with buff modifiers
	var def_roll: float = randf() * def_stat
	if defender.has_buff("Bless"):
		def_roll *= 1.25
	if defender.has_buff("Hex"):
		def_roll *= 0.8
	if defender.has_buff("Daze"):
		def_roll *= 0.5

	return acu_roll >= def_roll

## Check if this character can perform a surprise attack (hero: weapon STR met, etc.).
## Override in Hero to check weapon requirements. Base returns true.
func can_surprise_attack() -> bool:
	return true

## Whether this character is surprised by (unaware of) the attacker, granting the
## attacker a guaranteed hit. Base characters are only surprised by an invisible
## attacker; Mob overrides this to also cover sleeping/unaware/out-of-sight states.
func is_surprised_by(attacker: Char) -> bool:
	return attacker != null and attacker.invisible > 0

## Check if the target is invulnerable to this attacker.
## Override for boss-specific invulnerability phases.
func is_invulnerable(_source: Variant) -> bool:
	if has_buff("Invulnerable"):
		return true
	return false

## Called when an attack hits.
func on_attack_hit(_target: Char, _damage: int) -> void:
	pass

## Called when an attack misses.
func on_attack_miss(_target: Char) -> void:
	pass

## Pre-armor defense proc. Called on the DEFENDER during attack resolution.
## Allows earthroot armor, armor glyphs, etc. to modify damage before DR.
## Return negative to cancel on-hit logic. Override in subclasses.
func defense_proc(_enemy: Char, damage: int) -> int:
	# Earthroot / HerbalArmor absorb
	var herbal: Node = get_buff("HerbalArmor")
	if herbal and herbal.has_method("absorb"):
		damage = herbal.absorb(damage)
	return damage

## Post-armor attack proc. Called on the ATTACKER after armor reduction.
## Allows weapon enchantments, fire imbue, etc. to modify/add effects.
## Override in subclasses (Hero applies weapon enchantment proc here).
func attack_proc(_enemy: Char, damage: int) -> int:
	return damage

## Roll damage reduction from armor. Uses triangular distribution approximating
## SPD's NormalIntRange(0, armor) which is a bell curve favoring the middle.
## Original Char.drRoll() also includes Barkskin level.
func dr_roll() -> int:
	var dr: int = 0

	# Barkskin bonus (from Warden subclass, Earthroot plant)
	# Uses static current_level() which takes max across all Barkskin instances
	var bark_lvl: int = Barkskin.current_level(self)
	if bark_lvl > 0:
		# NormalIntRange(0, barkskin_level) approximated by triangular
		dr += int((randi_range(0, bark_lvl) + randi_range(0, bark_lvl)) / 2.0)

	var armor: int = effective_armor()
	if armor > 0:
		# Triangular distribution: average of two uniform rolls approximates NormalIntRange
		dr += int((randi_range(0, armor) + randi_range(0, armor)) / 2.0)

	return dr

## Take damage from a source. This receives ALREADY-REDUCED damage (armor is
## applied in attack(), not here). Matches original Char.damage(dmg, src).
## For non-attack sources (buffs, traps, blobs), damage comes in raw.
func take_damage(dmg: int, source: Variant = null) -> int:
	if not is_alive or dmg < 0:
		return 0

	# Invulnerability blocks all damage (original: isInvulnerable(source))
	if has_buff("Invulnerable"):
		return 0

	var damage: float = float(dmg)

	# Wake from sleep/frost on damage (original behavior)
	if has_buff("Frozen"):
		remove_buff_by_id("Frozen")
	if has_buff("Sleep"):
		remove_buff_by_id("Sleep")

	# Terror/Dread/Charm recover on damage
	var terror: Node = get_buff("Terror")
	if terror and terror.has_method("recover"):
		terror.recover()
	var dread: Node = get_buff("Dread")
	if dread and dread.has_method("recover"):
		dread.recover()
	var charm: Node = get_buff("Charm")
	if charm and charm.has_method("recover"):
		charm.recover(source)

	# Doom amplifies all damage by 67% (original: damage *= 1.67f)
	if has_buff("Doom") and not is_immune("Doom"):
		damage *= 1.67

	# Resistance/immunity check for non-Char damage sources (buffs, traps, blobs).
	# Attack-sourced damage already had its chance through attack() formula.
	if source != null and not (source is Char):
		var source_id: String = ""
		if source is Buff:
			source_id = (source as Buff).buff_id
		elif source is String:
			source_id = source
		elif source is Object and source.has_method("get_class"):
			source_id = source.get_class()
		if source_id != "":
			if is_immune(source_id):
				damage = 0
			else:
				damage *= resist(source_id)

	# ArcaneArmor reduces magic damage (from AntiMagic glyph, traps, blobs, wands)
	# Original: ArcaneArmor DR is applied to non-physical damage sources
	var arcane_armor: Node = get_buff("ArcaneArmor")
	if arcane_armor and arcane_armor.has_method("dr_roll"):
		var aa_dr: int = arcane_armor.dr_roll()
		if aa_dr > 0:
			damage = maxf(0.0, damage - aa_dr)

	# Paralysis damage processing (accumulated damage can break paralysis)
	var para: Node = get_buff("Paralysis")
	if para and para.has_method("process_damage"):
		para.process_damage(roundi(damage))

	var actual: int = maxi(0, roundi(damage))

	# Equipped Cape of Thorns absorbs/reflects a portion of incoming damage.
	# The artifact charges from hits and, when activated, reduces the blow.
	# Only heroes carry belongings; base Chars simply skip this.
	if actual > 0:
		var _belongings: Variant = get("belongings")
		if _belongings != null and _belongings.has_method("get_equipped_artifact"):
			var _art: Variant = _belongings.get_equipped_artifact()
			if _art != null and _art.has_method("on_hero_damaged"):
				actual = maxi(0, _art.on_hero_damaged(actual, source))

	# Apply to ShieldBuff instances first (original: ShieldBuff.processDamage)
	if actual > 0:
		for b: Node in _buffs.duplicate():
			if actual <= 0:
				break
			if b.has_method("absorb_damage"):
				actual = b.absorb_damage(actual)

	# Then apply to flat shielding (legacy, for cases without ShieldBuff pattern)
	if shielding > 0 and actual > 0:
		var shield_absorb: int = mini(shielding, actual)
		shielding -= shield_absorb
		actual -= shield_absorb

	hp -= actual
	if actual > 0 and source != null:
		last_damage_source = source
	damaged.emit(actual, source)

	# Notify buffs
	for b: Node in _buffs.duplicate():
		if b.has_method("on_damage_taken"):
			b.on_damage_taken(actual, source)

	if hp <= 0:
		die(source)

	return actual

## Heal HP (clamped to max).
func heal(amount: int) -> void:
	if not is_alive:
		return
	var actual: int = mini(amount, hp_max - hp)
	hp += actual
	if actual > 0:
		healed.emit(actual)

## Kill this character. Checks for death-prevention buffs first.
func die(source: Variant = null) -> void:
	if not is_alive:
		return
	# Check for death prevention (e.g., Berserker rage, Ankh)
	if _try_prevent_death(source):
		return
	is_alive = false
	hp = 0
	died.emit()
	deactivate()
	_on_death(source)

## Override in subclasses to add death-prevention mechanics.
## Returns true if death was prevented.
func _try_prevent_death(_source: Variant) -> bool:
	return false

## Override for death behavior (drop loot, give XP, etc.).
func _on_death(_source: Variant) -> void:
	pass

## Destroy this character (remove from scene tree).
func destroy() -> void:
	deactivate()
	if is_inside_tree():
		queue_free()

# ---------------------------------------------------------------------------
# Buffs
# ---------------------------------------------------------------------------

## Add a buff to this character. If the buff type already exists, refreshes it.
## Checks immunity before attaching — if immune, the buff is rejected and freed.
func add_buff(buff_node: Node) -> Node:
	# Immunity check (original: attachTo checks target.isImmune(getClass()))
	var buff_type: String = (buff_node as Buff).buff_id if buff_node is Buff else buff_node.get_script().get_path()
	if is_immune(buff_type):
		buff_node.queue_free()
		return null

	# Check for existing buff of same type
	for existing: Node in _buffs:
		var existing_type: String = (existing as Buff).buff_id if existing is Buff else existing.get_script().get_path()
		if existing_type == buff_type:
			# Merge/refresh
			if existing.has_method("merge"):
				existing.merge(buff_node)
			elif existing.has_method("set_duration"):
				if buff_node.has_method("get_duration"):
					existing.set_duration(buff_node.get_duration())
			buff_node.queue_free()
			if EventBus and EventBus.has_signal("status_effect_applied"):
				EventBus.status_effect_applied.emit(self, buff_type)
			return existing

	# New buff
	_buffs.append(buff_node)
	add_child(buff_node)
	if buff_node.has_method("attach"):
		buff_node.attach(self)
	buff_added.emit(buff_node)
	if EventBus and EventBus.has_signal("status_effect_applied"):
		EventBus.status_effect_applied.emit(self, buff_type)
	return buff_node

## Remove a specific buff instance.
func remove_buff(buff_node: Node) -> void:
	if buff_node in _buffs:
		_buffs.erase(buff_node)
		if buff_node.has_method("detach"):
			buff_node.detach()
		buff_removed.emit(buff_node)
		buff_node.queue_free()

## Remove all buffs with a given buff_id.
func remove_buff_by_id(buff_id: String) -> void:
	for b: Node in _buffs.duplicate():
		if b is Buff and (b as Buff).buff_id == buff_id:
			remove_buff(b)

## Check if this character has a buff with the given ID.
func has_buff(buff_id: String) -> bool:
	for b: Node in _buffs:
		if b is Buff and (b as Buff).buff_id == buff_id:
			return true
	return false

## Get a buff by ID (or null).
func get_buff(buff_id: String) -> Buff:
	for b: Node in _buffs:
		if b is Buff and (b as Buff).buff_id == buff_id:
			return b as Buff
	return null

## Get all active buffs.
func get_buffs() -> Array[Node]:
	return _buffs.duplicate()

## Process all buffs (called each turn).
func process_buffs() -> void:
	for b: Node in _buffs.duplicate():
		if b.has_method("act"):
			b.act()
		# Check if buff expired
		if b.has_method("is_expired") and b.is_expired():
			remove_buff(b)

func _serialize_buffs() -> Array[Dictionary]:
	var buff_data: Array[Dictionary] = []
	for buff_node: Node in _buffs:
		if buff_node == null or not is_instance_valid(buff_node) or not buff_node.has_method("serialize"):
			continue
		if buff_node.has_method("is_persistent") and not buff_node.is_persistent():
			continue
		buff_data.append(buff_node.serialize())
	return buff_data

func _deserialize_buffs(data: Variant) -> void:
	for existing_buff: Node in _buffs.duplicate():
		remove_buff(existing_buff)
	if not (data is Array):
		return
	for buff_entry: Variant in data:
		if not (buff_entry is Dictionary):
			continue
		var buff_dict: Dictionary = buff_entry as Dictionary
		var script_path: String = str(buff_dict.get("_script_path", ""))
		if script_path.is_empty() or not ResourceLoader.exists(script_path):
			continue
		var buff_script: Script = load(script_path) as Script
		if buff_script == null:
			continue
		var buff_node: Variant = buff_script.new()
		if not (buff_node is Node):
			continue
		var buff: Node = buff_node as Node
		if buff.has_method("deserialize"):
			buff.deserialize(buff_dict)
		_buffs.append(buff)
		add_child(buff)
		if buff.has_method("attach"):
			buff.attach(self)
		buff_added.emit(buff)

# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

## Add temporary shielding HP that absorbs damage before real HP.
func add_shielding(amount: int) -> void:
	shielding += amount
	if shielding > hp_max:
		shielding = hp_max

## Get total shielding from all sources (flat + ShieldBuff instances).
## Matches original Char.shielding() which sums all ShieldBuff amounts.
func total_shielding() -> int:
	var total: int = shielding
	for b: Node in _buffs:
		if b.has_method("get_shielding"):
			total += b.get_shielding()
	return total

## Move to a new position. Returns true if successful.
func move_to(new_pos: int) -> bool:
	if level == null:
		pos = new_pos
		return true
	# Check passability
	if not level.is_passable(new_pos):
		return false
	# Check for other characters at target
	if level.find_char_at(new_pos) != null:
		return false
	var old_pos: int = pos
	pos = new_pos
	on_move(old_pos, new_pos)
	return true

## Called after a successful move. Notifies all buffs.
func on_move(old_pos: int, new_pos: int) -> void:
	for b: Node in _buffs:
		if b.has_method("on_move"):
			b.on_move(old_pos, new_pos)

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

## Get speed including buff modifiers. Matches original Char.speed().
func get_speed() -> float:
	var spd: float = base_speed
	for b: Node in _buffs:
		if b.has_method("modify_speed"):
			spd = b.modify_speed(spd)
	return spd

# ---------------------------------------------------------------------------
# Immunities & Resistances
# ---------------------------------------------------------------------------

## Permanent immunities — override in subclasses to add class-specific immunities.
## Returns an array of buff_id strings this character is intrinsically immune to.
func _innate_immunities() -> Array[String]:
	return []

## Check if this character is immune to a given effect (buff_id string).
## Checks innate immunities first, then active buff-provided immunities.
func is_immune(effect_id: String) -> bool:
	# Innate immunities (subclass overrides)
	if effect_id in _innate_immunities():
		return true
	# Buff-provided immunities (e.g., Fire immunity from Firebloom, Frost immunity)
	for b: Node in _buffs:
		if b.has_method("immunities"):
			var imm: Array = b.immunities()
			if effect_id in imm:
				return true
	return false

## Get the resistance multiplier for an effect (1.0 = normal, <1.0 = resistant).
## Buffs can provide resistance via a resistances() method returning an Array of IDs.
func resist(effect_id: String) -> float:
	var multi: float = 1.0
	for b: Node in _buffs:
		if b.has_method("resistances"):
			var res: Array = b.resistances()
			if effect_id in res:
				multi *= 0.5  # Each resistance source halves the damage
	return multi

# ---------------------------------------------------------------------------
# Spatial Helpers
# ---------------------------------------------------------------------------

## Chebyshev distance (king-move distance) from this character's position to a cell.
## Matches original SPD Level.distance(a, b).
func distance_to(target_pos: int) -> int:
	var ax: int = ConstantsData.pos_to_x(pos)
	var ay: int = ConstantsData.pos_to_y(pos)
	var bx: int = ConstantsData.pos_to_x(target_pos)
	var by: int = ConstantsData.pos_to_y(target_pos)
	return maxi(absi(ax - bx), absi(ay - by))

## Whether this character is adjacent (Chebyshev distance == 1) to a cell.
func is_adjacent(target_pos: int) -> bool:
	return distance_to(target_pos) == 1

## Whether this character can see a given cell.
## Delegates to the level's field-of-view / line-of-sight check.
## Blindness reduces vision range to 0 (only own cell visible).
func can_see(target_pos: int) -> bool:
	if pos == target_pos:
		return true
	if has_buff("Blindness"):
		return false
	if level and level.has_method("has_los"):
		return level.has_los(pos, target_pos)
	# Fallback: simple distance check if level has no LOS system
	return distance_to(target_pos) <= 8
