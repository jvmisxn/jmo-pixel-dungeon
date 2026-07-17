class_name Ring
extends Item
## Base class for all rings. Rings provide passive stat bonuses while equipped
## in either the ring_left or ring_right slot, scaling with upgrade level.

# --- Ring Properties ---
## Gem color used for unidentified display.
var gem_color: Color = Color.WHITE
## Gem descriptor used for unidentified display.
var gem_name: String = ""
## Whether this ring type has been globally identified (any ring of same type).
var ring_known: bool = false

# --- Internal ---
## The buff instance applied while this ring is equipped, or null.
var _passive_buff: Node = null

func _init() -> void:
	category = ConstantsData.ItemCategory.RING
	default_action = "EQUIP"
	stackable = false

func is_equippable() -> bool:
	return true

# ---------------------------------------------------------------------------
# Bonus
# ---------------------------------------------------------------------------

## Returns the effective bonus level. Positive when upgraded, negative if cursed.
func bonus() -> int:
	if cursed and level == 0:
		return -1
	return level

# ---------------------------------------------------------------------------
# Equip / Unequip
# ---------------------------------------------------------------------------

func on_equip(hero: Char) -> void:
	super.on_equip(hero)
	_apply_passive(hero)

func on_unequip(hero: Char) -> void:
	_remove_passive(hero)
	super.on_unequip(hero)

## Create and attach the passive buff. Override in subclasses for custom buffs.
func _apply_passive(hero: Char) -> void:
	if hero == null:
		return
	_passive_buff = _create_passive_buff()
	if _passive_buff != null and hero.has_method("add_buff"):
		hero.add_buff(_passive_buff)

## Remove the passive buff from the hero.
func _remove_passive(hero: Char) -> void:
	if _passive_buff != null and hero != null and hero.has_method("remove_buff"):
		hero.remove_buff(_passive_buff)
	_passive_buff = null

## Virtual: create the passive buff node for this ring. Override per ring type.
func _create_passive_buff() -> Node:
	return null

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

func get_display_name() -> String:
	if not identified and not ring_known:
		if not gem_name.is_empty():
			return "%s ring" % gem_name.capitalize()
		return "ring"
	return super.get_display_name()

# ---------------------------------------------------------------------------
# Upgrade
# ---------------------------------------------------------------------------

func upgrade() -> Item:
	super.upgrade()
	# If already equipped, refresh the passive buff
	if _passive_buff != null and _passive_buff.target != null:
		var hero: Char = _passive_buff.target
		_remove_passive(hero)
		_apply_passive(hero)
	return self

# ---------------------------------------------------------------------------
# Random Generation
# ---------------------------------------------------------------------------

## Apply random upgrade and curse chances. Matches original Ring.random().
## +0: 66.67%, +1: 26.67%, +2: 5.33%. Then 30% chance to be cursed (level set to -1).
func random() -> Ring:
	var n: int = 0
	if randi() % 3 == 0:
		n += 1
		if randi() % 5 == 0:
			n += 1
	level = n

	# 30% chance to be cursed
	if randf() < 0.3:
		cursed = true
		level = -1  # Cursed rings have negative level
	return self

# ---------------------------------------------------------------------------
# Value
# ---------------------------------------------------------------------------

func value() -> int:
	return 75 * (level + 1)

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["gem_color"] = [gem_color.r, gem_color.g, gem_color.b, gem_color.a]
	data["gem_name"] = gem_name
	data["ring_known"] = ring_known
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	var gc: Variant = data.get("gem_color", [1.0, 1.0, 1.0, 1.0])
	if gc is Array and gc.size() >= 4:
		gem_color = Color(gc[0], gc[1], gc[2], gc[3])
	gem_name = data.get("gem_name", "")
	ring_known = data.get("ring_known", false)

# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## Create a ring by ID string. Returns null for unknown IDs.
static func create(ring_id: String) -> Ring:
	var ring: Ring = null
	match ring_id:
		"ring_of_accuracy":
			ring = _create_accuracy()
		"ring_of_evasion":
			ring = _create_evasion()
		"ring_of_elements":
			ring = _create_elements()
		"ring_of_force":
			ring = _create_force()
		"ring_of_furor":
			ring = _create_furor()
		"ring_of_haste":
			ring = _create_haste()
		"ring_of_energy":
			ring = _create_energy()
		"ring_of_might":
			ring = _create_might()
		"ring_of_sharpshooting":
			ring = _create_sharpshooting()
		"ring_of_tenacity":
			ring = _create_tenacity()
		"ring_of_wealth":
			ring = _create_wealth()
	return ring

# ===========================================================================
# RING IMPLEMENTATIONS
# ===========================================================================

# ---------------------------------------------------------------------------
# Ring of Accuracy
# ---------------------------------------------------------------------------

static func _create_accuracy() -> Ring:
	var r: Ring = RingOfAccuracy.new()
	return r

# ---------------------------------------------------------------------------
# Ring of Evasion
# ---------------------------------------------------------------------------

static func _create_evasion() -> Ring:
	var r: Ring = RingOfEvasion.new()
	return r

# ---------------------------------------------------------------------------
# Ring of Elements
# ---------------------------------------------------------------------------

static func _create_elements() -> Ring:
	var r: Ring = RingOfElements.new()
	return r

# ---------------------------------------------------------------------------
# Ring of Force
# ---------------------------------------------------------------------------

static func _create_force() -> Ring:
	var r: Ring = RingOfForce.new()
	return r

# ---------------------------------------------------------------------------
# Ring of Furor
# ---------------------------------------------------------------------------

static func _create_furor() -> Ring:
	var r: Ring = RingOfFuror.new()
	return r

# ---------------------------------------------------------------------------
# Ring of Haste
# ---------------------------------------------------------------------------

static func _create_haste() -> Ring:
	var r: Ring = RingOfHaste.new()
	return r

# ---------------------------------------------------------------------------
# Ring of Energy
# ---------------------------------------------------------------------------

static func _create_energy() -> Ring:
	var r: Ring = RingOfEnergy.new()
	return r

# ---------------------------------------------------------------------------
# Ring of Might
# ---------------------------------------------------------------------------

static func _create_might() -> Ring:
	var r: Ring = RingOfMight.new()
	return r

# ---------------------------------------------------------------------------
# Ring of Sharpshooting
# ---------------------------------------------------------------------------

static func _create_sharpshooting() -> Ring:
	var r: Ring = RingOfSharpshooting.new()
	return r

# ---------------------------------------------------------------------------
# Ring of Tenacity
# ---------------------------------------------------------------------------

static func _create_tenacity() -> Ring:
	var r: Ring = RingOfTenacity.new()
	return r

# ---------------------------------------------------------------------------
# Ring of Wealth
# ---------------------------------------------------------------------------

static func _create_wealth() -> Ring:
	var r: Ring = RingOfWealth.new()
	return r


# ===========================================================================
# RING BUFF INNER CLASSES
# ===========================================================================

# Each ring creates a passive buff that modifies stats via the buff system.
# The buff references the ring to read its current bonus().

# ---------------------------------------------------------------------------
# Accuracy Buff
# ---------------------------------------------------------------------------

class AccuracyBuff extends Buff:
	var ring: Ring = null

	func _init() -> void:
		buff_id = "RingOfAccuracy"
		buff_name = "Ring of Accuracy"
		duration = -1.0
		icon_color = Color(0.3, 0.3, 1.0)

	func modify_accuracy(acc: int) -> int:
		if ring == null:
			return acc
		var b: int = ring.bonus()
		# Each level adds ~17% accuracy multiplicatively: acc * 1.3^bonus
		var multi: float = pow(1.3, b)
		return maxi(0, int(float(acc) * multi))

# ---------------------------------------------------------------------------
# Evasion Buff
# ---------------------------------------------------------------------------

class EvasionBuff extends Buff:
	var ring: Ring = null

	func _init() -> void:
		buff_id = "RingOfEvasion"
		buff_name = "Ring of Evasion"
		duration = -1.0
		icon_color = Color(0.3, 1.0, 0.3)

	func modify_evasion(eva: int) -> int:
		if ring == null:
			return eva
		var b: int = ring.bonus()
		var multi: float = pow(1.3, b)
		return maxi(0, int(float(eva) * multi))

# ---------------------------------------------------------------------------
# Elements Buff
# ---------------------------------------------------------------------------

class ElementsBuff extends Buff:
	var ring: Ring = null

	func _init() -> void:
		buff_id = "RingOfElements"
		buff_name = "Ring of Elements"
		duration = -1.0
		icon_color = Color(0.6, 0.2, 0.8)

	## Reduce incoming elemental/magic damage.
	func on_damage_taken(amount: int, source: Variant) -> void:
		if ring == null or target == null:
			return
		# Elements ring resists damage from magical/elemental sources
		# Buff-type sources (Burning, Poison, etc.) are elemental
		if source is Buff:
			var b: int = ring.bonus()
			var resist: float = 1.0 - pow(0.8, maxf(0.0, float(b)))
			var blocked: int = int(float(amount) * resist)
			if blocked > 0:
				target.heal(blocked)

# ---------------------------------------------------------------------------
# Force Buff
# ---------------------------------------------------------------------------

class ForceBuff extends Buff:
	var ring: Ring = null

	func _init() -> void:
		buff_id = "RingOfForce"
		buff_name = "Ring of Force"
		duration = -1.0
		icon_color = Color(1.0, 0.3, 0.3)

	## Compute the effective weapon tier from hero STR.
	## Original: tier = max(1, (STR-8)/2), each STR above 18 is half as effective.
	static func _force_tier(hero_str: int) -> float:
		var t: float = maxf(1.0, float(hero_str - 8) / 2.0)
		if t > 5.0:
			t = 5.0 + (t - 5.0) / 2.0
		return t

	## Min unarmed damage at given level and tier (same formula as melee weapon).
	static func _force_min(lvl: int, tier: float) -> int:
		if lvl <= 0:
			tier = 1.0  # Cursed ring forces tier 1
		return maxi(0, roundi(tier + float(lvl)))

	## Max unarmed damage at given level and tier (same formula as melee weapon).
	static func _force_max(lvl: int, tier: float) -> int:
		if lvl <= 0:
			tier = 1.0
		return maxi(0, roundi(5.0 * (tier + 1.0) + float(lvl) * (tier + 1.0)))

	## Roll unarmed damage using the force ring. Called when hero fights unarmed.
	func force_damage_roll(hero_str: int) -> int:
		if ring == null:
			return 1
		var lvl: int = ring.bonus()
		var tier: float = _force_tier(hero_str)
		var lo: int = _force_min(lvl, tier)
		var hi: int = _force_max(lvl, tier)
		@warning_ignore("integer_division")
		return (randi_range(lo, hi) + randi_range(lo, hi)) / 2

	## Armed damage bonus: flat +bonus added to weapon damage.
	func armed_damage_bonus() -> int:
		if ring == null:
			return 0
		return ring.bonus()

	func modify_damage(dmg: int) -> int:
		if ring == null:
			return dmg
		# When armed, Ring of Force adds flat +bonus to weapon damage
		return dmg + armed_damage_bonus()

# ---------------------------------------------------------------------------
# Furor Buff
# ---------------------------------------------------------------------------

class FurorBuff extends Buff:
	var ring: Ring = null

	func _init() -> void:
		buff_id = "RingOfFuror"
		buff_name = "Ring of Furor"
		duration = -1.0
		icon_color = Color(1.0, 1.0, 0.2)

	func modify_speed(speed: float) -> float:
		if ring == null:
			return speed
		var b: int = ring.bonus()
		# Attack speed bonus: ~10.5% per level multiplicatively
		# Only affects attack speed, approximated as general speed boost
		var multi: float = pow(1.105, b)
		return speed * multi

# ---------------------------------------------------------------------------
# Haste Buff
# ---------------------------------------------------------------------------

class HasteBuff extends Buff:
	var ring: Ring = null

	func _init() -> void:
		buff_id = "RingOfHaste"
		buff_name = "Ring of Haste"
		duration = -1.0
		icon_color = Color(0.3, 1.0, 1.0)

	func modify_speed(speed: float) -> float:
		if ring == null:
			return speed
		var b: int = ring.bonus()
		# Move speed bonus: ~20% per level
		var multi: float = pow(1.2, b)
		return speed * multi

# ---------------------------------------------------------------------------
# Energy Buff
# ---------------------------------------------------------------------------

class EnergyBuff extends Buff:
	var ring: Ring = null

	func _init() -> void:
		buff_id = "RingOfEnergy"
		buff_name = "Ring of Energy"
		duration = -1.0
		icon_color = Color(0.5, 0.8, 1.0)

	# Energy ring effect is checked by the Wand recharge system.
	# The ring stores a reference; wands query hero buffs for this buff_id.
	# No stat modifier here -- wand.gd checks for this buff during recharge.

# ---------------------------------------------------------------------------
# Might Buff
# ---------------------------------------------------------------------------

class MightBuff extends Buff:
	var ring: Ring = null
	var _str_bonus: int = 0
	var _hp_bonus: int = 0

	func _init() -> void:
		buff_id = "RingOfMight"
		buff_name = "Ring of Might"
		duration = -1.0
		icon_color = Color(0.8, 0.2, 0.2)

	func on_attach() -> void:
		_apply_bonus()

	func on_detach() -> void:
		_remove_bonus()

	# This buff is a live modifier owned by the equipped ring: it mutates the
	# hero's str_val/hp_max/ht while worn. Persisting it would let the bonus be
	# baked into the hero's saved base stats (double-counted on reload), so it is
	# not serialized -- the ring rebuilds it via resolve_post_load() after a load.
	func is_persistent() -> bool:
		return false

	# Amount this buff currently adds to str_val, so the hero can persist a clean
	# base value (see Hero.serialize).
	func get_str_contribution() -> int:
		return _str_bonus

	# Amount this buff currently adds to both hp_max and ht.
	func get_ht_contribution() -> int:
		return _hp_bonus

	func _apply_bonus() -> void:
		if ring == null or target == null:
			return
		var b: int = ring.bonus()
		# STR bonus: flat +bonus (matches original's getBonus)
		_str_bonus = b
		# HP bonus: multiplicative pow(1.035, bonus) on base HT
		# Original: HTMultiplier = pow(1.035, getBuffedBonus)
		var base_ht: int = target.ht  # base HT before ring
		var multiplier: float = pow(1.035, maxf(0.0, float(b)))
		_hp_bonus = maxi(0, int(float(base_ht) * multiplier) - base_ht)
		target.str_val += _str_bonus
		target.hp_max += _hp_bonus
		target.ht += _hp_bonus

	func _remove_bonus() -> void:
		if target == null:
			return
		target.str_val -= _str_bonus
		target.hp_max -= _hp_bonus
		target.ht -= _hp_bonus
		target.hp = mini(target.hp, target.hp_max)
		_str_bonus = 0
		_hp_bonus = 0

# ---------------------------------------------------------------------------
# Sharpshooting Buff
# ---------------------------------------------------------------------------

class SharpshootingBuff extends Buff:
	var ring: Ring = null

	func _init() -> void:
		buff_id = "RingOfSharpshooting"
		buff_name = "Ring of Sharpshooting"
		duration = -1.0
		icon_color = Color(1.0, 0.8, 0.0)

	# Sharpshooting modifies missile weapon damage and accuracy.
	# Missile weapons check for this buff and scale accordingly.
	func modify_accuracy(acc: int) -> int:
		if ring == null:
			return acc
		# Only boosts missile accuracy; approximated as general accuracy boost
		var b: int = ring.bonus()
		return acc + b * 2

	func modify_damage(dmg: int) -> int:
		if ring == null:
			return dmg
		# Missile weapons deal bonus damage per level
		var b: int = ring.bonus()
		return dmg + b

# ---------------------------------------------------------------------------
# Tenacity Buff
# ---------------------------------------------------------------------------

class TenacityBuff extends Buff:
	var ring: Ring = null

	func _init() -> void:
		buff_id = "RingOfTenacity"
		buff_name = "Ring of Tenacity"
		duration = -1.0
		icon_color = Color(0.6, 0.0, 0.0)

	func modify_armor(armor: int) -> int:
		if ring == null or target == null:
			return armor
		var b: int = ring.bonus()
		# Grants more armor the lower your HP ratio is
		var hp_ratio: float = float(target.hp) / float(maxi(1, target.hp_max))
		var missing: float = 1.0 - hp_ratio
		# At low HP, gains up to bonus * 5 extra armor
		var extra: int = int(float(b) * 5.0 * missing)
		return armor + extra

# ---------------------------------------------------------------------------
# Wealth Buff
# ---------------------------------------------------------------------------

class WealthBuff extends Buff:
	var ring: Ring = null

	func _init() -> void:
		buff_id = "RingOfWealth"
		buff_name = "Ring of Wealth"
		duration = -1.0
		icon_color = Color(1.0, 0.85, 0.0)

	# Wealth effect is checked by the loot generation system.
	# The ring's bonus() is queried by mob/chest loot tables to
	# multiply gold drops and increase rare item chance.


# ===========================================================================
# RING SUBCLASSES
# ===========================================================================

class RingOfAccuracy extends Ring:
	func _init() -> void:
		super._init()
		item_id = "ring_of_accuracy"
		item_name = "Ring of Accuracy"
		description = "This ring enhances the wearer's focus, " \
			+ "granting improved precision with all physical attacks. " \
			+ "Its effect scales multiplicatively with upgrade level."
		icon_color = Color(0.3, 0.3, 1.0)
		gem_color = Color(0.2, 0.2, 0.9)

	func _create_passive_buff() -> Node:
		var b: AccuracyBuff = AccuracyBuff.new()
		b.ring = self
		return b


class RingOfEvasion extends Ring:
	func _init() -> void:
		super._init()
		item_id = "ring_of_evasion"
		item_name = "Ring of Evasion"
		description = "This ring allows the wearer to twist and dodge with " \
			+ "supernatural agility. Each upgrade multiplicatively increases " \
			+ "the chance to evade incoming attacks."
		icon_color = Color(0.3, 1.0, 0.3)
		gem_color = Color(0.2, 0.9, 0.2)

	func _create_passive_buff() -> Node:
		var b: EvasionBuff = EvasionBuff.new()
		b.ring = self
		return b


class RingOfElements extends Ring:
	func _init() -> void:
		super._init()
		item_id = "ring_of_elements"
		item_name = "Ring of Elements"
		description = "This ring grants the wearer resistance to elemental " \
			+ "and magical damage sources such as fire, frost, and toxic gas. " \
			+ "Higher levels provide greater damage reduction."
		icon_color = Color(0.6, 0.2, 0.8)
		gem_color = Color(0.5, 0.1, 0.7)

	func _create_passive_buff() -> Node:
		var b: ElementsBuff = ElementsBuff.new()
		b.ring = self
		return b


class RingOfForce extends Ring:
	func _init() -> void:
		super._init()
		item_id = "ring_of_force"
		item_name = "Ring of Force"
		description = "This ring channels raw physical power through the " \
			+ "wearer's attacks, adding flat bonus damage that scales with " \
			+ "upgrade level. Effective even when fighting unarmed."
		icon_color = Color(1.0, 0.3, 0.3)
		gem_color = Color(0.9, 0.2, 0.2)

	func _create_passive_buff() -> Node:
		var b: ForceBuff = ForceBuff.new()
		b.ring = self
		return b


class RingOfFuror extends Ring:
	func _init() -> void:
		super._init()
		item_id = "ring_of_furor"
		item_name = "Ring of Furor"
		description = "This ring fills the wearer with boundless ferocity, " \
			+ "increasing attack speed. Each upgrade allows the wearer to " \
			+ "strike more frequently per turn."
		icon_color = Color(1.0, 1.0, 0.2)
		gem_color = Color(0.9, 0.9, 0.1)

	func _create_passive_buff() -> Node:
		var b: FurorBuff = FurorBuff.new()
		b.ring = self
		return b


class RingOfHaste extends Ring:
	func _init() -> void:
		super._init()
		item_id = "ring_of_haste"
		item_name = "Ring of Haste"
		description = "This ring imbues the wearer with supernatural quickness, " \
			+ "increasing movement speed. Higher upgrades allow even faster " \
			+ "traversal through the dungeon."
		icon_color = Color(0.3, 1.0, 1.0)
		gem_color = Color(0.2, 0.9, 0.9)

	func _create_passive_buff() -> Node:
		var b: HasteBuff = HasteBuff.new()
		b.ring = self
		return b


class RingOfEnergy extends Ring:
	func _init() -> void:
		super._init()
		item_id = "ring_of_energy"
		item_name = "Ring of Energy"
		description = "This ring channels arcane energy into the wearer's " \
			+ "equipped wands, significantly increasing their recharge rate. " \
			+ "A must-have for any aspiring battlemage."
		icon_color = Color(0.5, 0.8, 1.0)
		gem_color = Color(0.4, 0.7, 0.9)

	func _create_passive_buff() -> Node:
		var b: EnergyBuff = EnergyBuff.new()
		b.ring = self
		return b


class RingOfMight extends Ring:
	func _init() -> void:
		super._init()
		item_id = "ring_of_might"
		item_name = "Ring of Might"
		description = "This ring grants the wearer " \
			+ "immense physical power, boosting strength and maximum health. " \
			+ "Essential for wearing heavy armor and weapons."
		icon_color = Color(0.8, 0.2, 0.2)
		gem_color = Color(0.7, 0.1, 0.1)

	func _create_passive_buff() -> Node:
		var b: MightBuff = MightBuff.new()
		b.ring = self
		return b

	# Equipped rings are assigned directly during load (bypassing on_equip), and
	# the MightBuff is intentionally not serialized. Rebuild the passive buff here
	# so the STR/HP bonus is re-applied on top of the persisted clean base stats.
	# Called by Hero.deserialize for each equipped ring.
	func resolve_post_load(hero: Char) -> void:
		if hero == null:
			return
		_passive_buff = null
		_apply_passive(hero)


class RingOfSharpshooting extends Ring:
	func _init() -> void:
		super._init()
		item_id = "ring_of_sharpshooting"
		item_name = "Ring of Sharpshooting"
		description = "This ring hones the wearer's aim with thrown and missile " \
			+ "weapons, increasing both accuracy and damage at range."
		icon_color = Color(1.0, 0.8, 0.0)
		gem_color = Color(0.9, 0.7, 0.0)

	func _create_passive_buff() -> Node:
		var b: SharpshootingBuff = SharpshootingBuff.new()
		b.ring = self
		return b


class RingOfTenacity extends Ring:
	func _init() -> void:
		super._init()
		item_id = "ring_of_tenacity"
		item_name = "Ring of Tenacity"
		description = "This ring strengthens the wearer's resolve, granting " \
			+ "increased damage resistance when health is low. The closer " \
			+ "to death, the tougher the wearer becomes."
		icon_color = Color(0.6, 0.0, 0.0)
		gem_color = Color(0.5, 0.0, 0.0)

	func _create_passive_buff() -> Node:
		var b: TenacityBuff = TenacityBuff.new()
		b.ring = self
		return b


class RingOfWealth extends Ring:
	func _init() -> void:
		super._init()
		item_id = "ring_of_wealth"
		item_name = "Ring of Wealth"
		description = "This ring attracts fortune to the wearer, increasing " \
			+ "gold drops and the chance of finding rare items from defeated enemies."
		icon_color = Color(1.0, 0.85, 0.0)
		gem_color = Color(0.9, 0.75, 0.0)

	func _create_passive_buff() -> Node:
		var b: WealthBuff = WealthBuff.new()
		b.ring = self
		return b
