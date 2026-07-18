class_name Armor
extends Item
## Base class for all armor in the game. Provides damage reduction, evasion
## modifiers, strength requirements, glyph support, and augmentation.

# ---------------------------------------------------------------------------
# Augment Enum
# ---------------------------------------------------------------------------

enum Augment {
	NONE,    ## No augment — balanced armor and evasion.
	EVASION, ## Less armor DR, but increased evasion.
	DEFENSE, ## More armor DR, but no evasion bonus.
}

# --- Augment Tuning Constants (matching SPD) ---
## Evasion augment: evasion_factor = (2+level) * 2, defense_factor = (2+level) * -1
## Defense augment: evasion_factor = (2+level) * -2, defense_factor = (2+level) * 1
## These are additive bonuses, not multipliers.
## Speed floor — armor can never slow you below this fraction.
const MIN_SPEED_FACTOR: float = 0.5
## Properties matching SPD
var enchant_hardened: bool = false
var curse_infusion_bonus: bool = false
var mastery_potion_bonus: bool = false
## Use-based identification (SPD: 10 uses to ID)
var _uses_left_to_id: float = 10.0
var _available_uses_to_id: float = 5.0

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

## Armor tier (1-5). Determines base stats and progression.
var tier: int = 1
## Current augment applied to this armor.
var augment: Augment = Augment.NONE
## Inscribed glyph (or null if none).
var glyph: ArmorGlyph = null

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func _init() -> void:
	category = ConstantsData.ItemCategory.ARMOR
	default_action = "EQUIP"
	stackable = false
	_update_str_requirement()

func is_equippable() -> bool:
	return true

# ---------------------------------------------------------------------------
# Armor Value (Damage Reduction)
# ---------------------------------------------------------------------------

## SPD formula: DRMax = tier * (2 + lvl) + augment.defenseFactor(lvl)
## DRMin = lvl (clamped to max). Augment adds/subtracts (2+level) for defense/evasion.
## Returns the MAX DR value (for display). Use dr_roll() for actual combat.
func get_armor_value() -> int:
	return dr_max()

## Maximum damage reduction. SPD: tier * (2 + lvl) + augment bonus.
## Uses buffed_lvl() for combat calculations.
func dr_max(lvl: int = -1) -> int:
	if lvl < 0:
		lvl = buffed_lvl()
	var augment_bonus: int = _augment_defense_factor(lvl)
	var max_dr: int = tier * (2 + lvl) + augment_bonus
	if lvl > max_dr:
		@warning_ignore("integer_division")
		return (lvl - max_dr + 1) / 2
	return max_dr

## Minimum damage reduction. SPD: lvl, clamped by DRMax.
func dr_min(lvl: int = -1) -> int:
	if lvl < 0:
		lvl = buffed_lvl()
	var max_dr: int = dr_max(lvl)
	if lvl >= max_dr:
		return lvl - max_dr
	return lvl

## Augment defense factor: DEFENSE = +(2+level), EVASION = -(2+level), NONE = 0
func _augment_defense_factor(lvl: int) -> int:
	match augment:
		Augment.DEFENSE:
			return int(round(float(2 + lvl) * 1.0))
		Augment.EVASION:
			return int(round(float(2 + lvl) * -1.0))
	return 0

## Augment evasion factor: EVASION = +(2+level)*2, DEFENSE = -(2+level)*2, NONE = 0
func _augment_evasion_factor(lvl: int) -> int:
	match augment:
		Augment.EVASION:
			return int(round(float(2 + lvl) * 2.0))
		Augment.DEFENSE:
			return int(round(float(2 + lvl) * -2.0))
	return 0

## Roll actual DR using a triangular (bell-curve approximation) distribution.
## Approximates the original's NormalIntRange(min, max).
func dr_roll(lvl_override: int = -1) -> int:
	var lo: int = dr_min(lvl_override)
	var hi: int = dr_max(lvl_override)
	if lo >= hi:
		return lo
	# Triangular distribution: average of two uniform rolls (approximates normal)
	var roll_a: int = randi_range(lo, hi)
	var roll_b: int = randi_range(lo, hi)
	@warning_ignore("integer_division")
	return (roll_a + roll_b) / 2

# ---------------------------------------------------------------------------
# Strength Requirement
# ---------------------------------------------------------------------------

## Recalculate strength requirement using the original's triangular-number formula:
## (8 + tier*2) - floor((sqrt(8*lvl + 1) - 1) / 2), reduced by 2 if mastery potion.
func _update_str_requirement() -> void:
	var effective_lvl: int = maxi(0, level)
	var reduction: int = int((sqrt(8.0 * effective_lvl + 1.0) - 1.0) / 2.0)
	var req: int = 8 + tier * 2 - reduction
	if mastery_potion_bonus:
		req -= 2
	str_requirement = maxi(1, req)

# ---------------------------------------------------------------------------
# Evasion Factor
# ---------------------------------------------------------------------------

## Returns the evasion adjustment for the hero's dodge.
## SPD: evasion /= pow(1.5, encumbrance), then += augment evasion bonus.
## Momentum also adds evasion at high excess STR.
func evasion_factor(hero: Char, evasion: float = 1.0) -> float:
	if hero != null and hero.get("str_val") != null:
		var encumbrance: int = str_requirement - hero.str_val
		if encumbrance > 0:
			evasion /= pow(1.5, encumbrance)
	return evasion + float(_augment_evasion_factor(buffed_lvl()))

# ---------------------------------------------------------------------------
# Speed Factor
# ---------------------------------------------------------------------------

## Returns a speed multiplier. 1.0 if strength requirement is met; slower if not.
## SPD formula: speed /= pow(1.2, encumbrance).
func speed_factor(hero: Char) -> float:
	var speed: float = 1.0
	if hero != null and hero.get("str_val") != null:
		var encumbrance: int = str_requirement - hero.str_val
		if encumbrance > 0:
			speed /= pow(1.2, encumbrance)
	# Stone glyph slows movement
	if glyph != null and glyph.glyph_id == "stone":
		speed -= 0.2
	# Flow glyph speeds movement in water
	if glyph != null and glyph.glyph_id == "flow":
		if hero != null and hero.get("pos") != null and hero.get("level") != null:
			var level_ref: Variant = hero.level
			if level_ref != null and level_ref.has_method("get_terrain"):
				var terrain: int = level_ref.get_terrain(hero.pos)
				if terrain == ConstantsData.Terrain.WATER:
					speed += 0.3
	# Swiftness glyph always grants a small speed bonus
	if glyph != null and glyph.glyph_id == "swiftness":
		speed += 0.1
	return maxf(MIN_SPEED_FACTOR, speed)

# ---------------------------------------------------------------------------
# Glyph Processing
# ---------------------------------------------------------------------------

## Trigger the inscribed glyph when the wearer is struck.
## Returns the modified damage after glyph effects.
func proc_glyph(attacker: Variant, defender: Variant, damage: int) -> int:
	if glyph != null:
		return glyph.proc(self, attacker, defender, damage)
	return damage

## Inscribe a glyph onto this armor, replacing any existing one.
func inscribe(new_glyph: ArmorGlyph) -> Armor:
	glyph = new_glyph
	if identified and glyph != null and DiscoveryCatalog:
		DiscoveryCatalog.record_glyph(glyph.glyph_name)
	return self

## Remove the current glyph.
func erase_glyph() -> Armor:
	glyph = null
	return self

## Check if this armor has a glyph inscribed.
func has_glyph() -> bool:
	return glyph != null

# ---------------------------------------------------------------------------
# Augmentation
# ---------------------------------------------------------------------------

## Apply an augment to this armor. Only one augment can be active at a time.
func apply_augment(new_augment: Augment) -> Armor:
	augment = new_augment
	return self

# ---------------------------------------------------------------------------
# Equipment Lifecycle
# ---------------------------------------------------------------------------

func on_equip(hero: Char) -> void:
	super.on_equip(hero)
	# Note: Do NOT call hero.belongings.equip_armor(self) here — that method
	# already calls on_equip(), which would create an infinite recursion loop.
	# Belongings.equip_armor() is the caller; this callback handles side-effects only.
	if cursed and not cursed_known:
		cursed_known = true
		if MessageLog:
			MessageLog.add_negative("The %s constricts around you!" % item_name)

func on_unequip(hero: Char) -> void:
	super.on_unequip(hero)

# ---------------------------------------------------------------------------
# Upgrade
# ---------------------------------------------------------------------------

## Upgrade armor with glyph loss logic matching SPD.
func upgrade_armor(inscribe_glyph: bool = false) -> Item:
	if inscribe_glyph:
		if glyph == null:
			inscribe(ArmorGlyph.random())
	elif glyph != null:
		# Chance to lose hardened buff: 10/20/40/80/100% at +6/7/8/9/10
		if enchant_hardened:
			if level >= 6 and randf() * 10.0 < pow(2.0, level - 6):
				enchant_hardened = false
		# Curse glyphs: static 33% chance to remove
		elif has_curse_glyph():
			if randi() % 3 == 0:
				inscribe(null)
		# Normal glyphs: 10/20/40/80/100% loss at +4/5/6/7/8
		elif level >= 4 and randf() * 10.0 < pow(2.0, level - 4):
			inscribe(null)
	cursed = false
	super.upgrade()
	_update_str_requirement()
	return self

func upgrade() -> Item:
	return upgrade_armor(false)

func degrade() -> Item:
	super.degrade()
	_update_str_requirement()
	return self

## Override buffed_lvl to account for curse infusion bonus.
func buffed_lvl() -> int:
	var lvl: int = super.buffed_lvl()
	if curse_infusion_bonus:
		@warning_ignore("integer_division")
		lvl += 1 + lvl / 6
	return lvl

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

func get_display_name() -> String:
	var base_name: String = super.get_display_name()
	if glyph != null and identified:
		base_name += " {%s}" % glyph.glyph_name
	return base_name

# ---------------------------------------------------------------------------
# Value
# ---------------------------------------------------------------------------

## SPD formula: 20*tier, *1.5 if good glyph, /2 if cursed, *(level+1) if known.
func value() -> int:
	var price: int = 20 * tier
	if has_good_glyph():
		price = int(float(price) * 1.5)
	if cursed_known and (cursed or has_curse_glyph()):
		@warning_ignore("integer_division")
		price /= 2
	if level_known and level > 0:
		price *= (level + 1)
	return maxi(1, price)

## Whether this armor has a good (non-curse) glyph.
func has_good_glyph() -> bool:
	return glyph != null and not (glyph.get("is_curse") == true)

## Whether this armor has a curse glyph.
func has_curse_glyph() -> bool:
	return glyph != null and glyph.get("is_curse") == true

# ---------------------------------------------------------------------------
# Duplication
# ---------------------------------------------------------------------------

func duplicate_item() -> Item:
	var copy: Armor = Armor.new()
	_copy_base_properties(copy)
	copy.tier = tier
	copy.augment = augment
	if glyph != null:
		copy.glyph = ArmorGlyph.create(glyph.glyph_id)
	return copy

# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## Create a configured armor piece by ID.
static func create(armor_id: String) -> Armor:
	var a: Armor = Armor.new()
	a.item_id = armor_id
	match armor_id:
		"cloth_armor":
			a.item_name = "Cloth Armor"
			a.description = "This lightweight armor offers basic protection."
			a.tier = 1
		"leather_armor":
			a.item_name = "Leather Armor"
			a.description = "Cured leather provides decent protection without much weight."
			a.tier = 2
		"mail_armor":
			a.item_name = "Mail Armor"
			a.description = "Interlocking metal rings form a flexible yet sturdy defense."
			a.tier = 3
		"scale_armor":
			a.item_name = "Scale Armor"
			a.description = "Overlapping metal scales offer excellent protection."
			a.tier = 4
		"plate_armor":
			a.item_name = "Plate Armor"
			a.description = "Heavy plates of solid metal provide the best defense available."
			a.tier = 5
		_:
			a.item_name = armor_id.capitalize()
			a.tier = 1
	a._update_str_requirement()
	return a


static func all_ids() -> Array[String]:
	return ["cloth_armor", "leather_armor", "mail_armor", "scale_armor", "plate_armor"]

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------


## Apply random upgrade, curse, and glyph chances to this armor.
## Called by Generator when spawning loot. Matches original Armor.random().
## +0: 75%, +1: 20%, +2: 5%. Then 30% cursed (with curse glyph), 15% inscribed.
func random() -> Armor:
	# Upgrade level: +0 (75%), +1 (20%), +2 (5%)
	var n: int = 0
	if randi() % 4 == 0:
		n += 1
		if randi() % 5 == 0:
			n += 1
	level = n

	# 30% chance to be cursed with curse glyph
	# 15% chance to get a good glyph (only if not cursed)
	var effect_roll: float = randf()
	if effect_roll < 0.3:
		cursed = true
		# Curse glyph would be applied here with a full glyph system
	elif effect_roll >= 0.85:
		# Good glyph would be applied here with a full glyph system
		pass

	_update_str_requirement()
	return self

## Get a stats text description for the item detail window.
func get_stats_text() -> String:
	var text: String = "Armor: %d" % get_armor_value()
	text += "  STR req: %d" % str_requirement
	if glyph != null and glyph.has_method("get_name"):
		text += "  Glyph: %s" % glyph.get_name()
	return text

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["tier"] = tier
	data["augment"] = augment
	data["enchant_hardened"] = enchant_hardened
	data["curse_infusion_bonus"] = curse_infusion_bonus
	data["mastery_potion_bonus"] = mastery_potion_bonus
	data["_uses_left_to_id"] = _uses_left_to_id
	data["_available_uses_to_id"] = _available_uses_to_id
	if glyph != null:
		data["glyph"] = glyph.serialize()
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	tier = data.get("tier", 1)
	augment = data.get("augment", Augment.NONE) as Augment
	enchant_hardened = data.get("enchant_hardened", false)
	curse_infusion_bonus = data.get("curse_infusion_bonus", false)
	mastery_potion_bonus = data.get("mastery_potion_bonus", false)
	_uses_left_to_id = data.get("_uses_left_to_id", 0)
	_available_uses_to_id = data.get("_available_uses_to_id", 0)
	if data.has("glyph"):
		var glyph_data: Dictionary = data["glyph"]
		var glyph_id: String = glyph_data.get("glyph_id", "")
		if glyph_id != "":
			glyph = ArmorGlyph.create(glyph_id)
			if glyph != null:
				glyph.deserialize(glyph_data)
	_update_str_requirement()
