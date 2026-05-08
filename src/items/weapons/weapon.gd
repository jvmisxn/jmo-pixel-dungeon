class_name Weapon
extends Item
## Base weapon class. Handles damage calculation, augmentation, enchantments,
## strength requirements, and attack speed. All melee/missile/special weapons extend this.

# --- Enums ---
enum Augment { NONE, SPEED, DAMAGE }

# --- Properties ---
var tier: int = 1
var augment: Augment = Augment.NONE
var enchantment: WeaponEnchantment = null
var delay_factor: float = 1.0
## Whether the enchantment is hardened (protected from upgrade loss).
var enchant_hardened: bool = false
## Whether this weapon has a curse infusion bonus (+1 + level/6 to effective level).
var curse_infusion_bonus: bool = false
## Whether this weapon has a mastery potion bonus (reduced STR req).
var mastery_potion_bonus: bool = false
## Use-based identification tracking (SPD: 20 uses to ID).
var _uses_to_id: int = 20
var _uses_left_to_id: float = 20.0
var _available_uses_to_id: float = 10.0

# --- Augment Multipliers ---
## Original SPD values: SPEED = (0.7 dmg, 2/3 dly), DAMAGE = (5/3 dmg, 1.5 dly)
const SPEED_AUGMENT_DELAY: float = 0.6667  # 2/3
const SPEED_AUGMENT_DAMAGE: float = 0.7
const DAMAGE_AUGMENT_DELAY: float = 1.5
const DAMAGE_AUGMENT_DAMAGE: float = 1.6667  # 5/3

func _init() -> void:
	category = ConstantsData.ItemCategory.WEAPON
	default_action = "attack"

func is_equippable() -> bool:
	return true

# ---------------------------------------------------------------------------
# Damage
# ---------------------------------------------------------------------------

## Returns [min_damage, max_damage] factoring in tier, buffed level, and augment.
## SPD MeleeWeapon formula: min = tier + lvl, max = 5*(tier+1) + lvl*(tier+1)
func get_damage_range() -> Array[int]:
	var lvl: int = buffed_lvl()
	var base_min: int = tier + lvl
	var base_max: int = 5 * (tier + 1) + lvl * (tier + 1)

	# Apply augment damage scaling
	var dmg_multi: float = _augment_damage_multiplier()
	var final_min: int = maxi(1, roundi(base_min * dmg_multi))
	var final_max: int = maxi(final_min, roundi(base_max * dmg_multi))

	return [final_min, final_max]

## Roll weapon damage using triangular distribution (NormalIntRange approximation).
## Includes augment scaling and excess STR bonus. Called by Hero.damage_roll().
## Matches original MeleeWeapon.damageRoll(owner).
func damage_roll(owner: Variant = null) -> int:
	var dmg_range: Array[int] = get_damage_range()
	# Triangular distribution approximating NormalIntRange(min, max)
	var roll_a: int = randi_range(dmg_range[0], dmg_range[1])
	var roll_b: int = randi_range(dmg_range[0], dmg_range[1])
	@warning_ignore("integer_division")
	var dmg: int = (roll_a + roll_b) / 2

	# Excess STR bonus: NormalIntRange(0, excessSTR) added to damage
	if owner != null and owner.get("str_val") != null:
		var excess_str: int = owner.str_val - get_str_requirement()
		if excess_str > 0:
			var str_a: int = randi_range(0, excess_str)
			var str_b: int = randi_range(0, excess_str)
			@warning_ignore("integer_division")
			dmg += (str_a + str_b) / 2

	return maxi(0, dmg)

## Damage multiplier from augment.
func _augment_damage_multiplier() -> float:
	match augment:
		Augment.SPEED:
			return SPEED_AUGMENT_DAMAGE
		Augment.DAMAGE:
			return DAMAGE_AUGMENT_DAMAGE
	return 1.0

# ---------------------------------------------------------------------------
# Strength Requirement
# ---------------------------------------------------------------------------

## Base strength requirement: (8 + tier*2) with diminishing reduction from upgrades.
## Uses the original SPD triangular-number formula:
## STRReq(tier, lvl) = (8 + tier*2) - floor((sqrt(8*lvl + 1) - 1) / 2)
func get_str_requirement() -> int:
	var effective_lvl: int = maxi(0, level)
	var reduction: int = int((sqrt(8.0 * effective_lvl + 1.0) - 1.0) / 2.0)
	return maxi(1, 8 + tier * 2 - reduction)

# ---------------------------------------------------------------------------
# Accuracy
# ---------------------------------------------------------------------------

## Accuracy factor applied to the hero's base accuracy.
## 1.0 = no change. Reduced by STR encumbrance (pow(1.5, deficit)).
func accuracy_factor(hero: Char = null) -> float:
	if hero == null:
		return 1.0
	var encumbrance: int = get_str_requirement() - hero.str_val
	if encumbrance > 0:
		return 1.0 / pow(1.5, encumbrance)
	return 1.0

# ---------------------------------------------------------------------------
# Speed
# ---------------------------------------------------------------------------

## Attack speed factor. Lower = faster. Modified by augment and strength penalty.
## SPD formula: baseDelay = augment.delayFactor(DLY), then *= pow(1.2, encumbrance).
## Final delay = baseDelay * (1/speedMultiplier).
func speed_factor(hero: Char) -> float:
	var base_delay: float = delay_factor

	# Augment modifier
	match augment:
		Augment.SPEED:
			base_delay *= SPEED_AUGMENT_DELAY
		Augment.DAMAGE:
			base_delay *= DAMAGE_AUGMENT_DELAY

	# Strength penalty: multiplicative, matching original pow(1.2, encumbrance)
	if hero != null:
		var encumbrance: int = get_str_requirement() - hero.str_val
		if encumbrance > 0:
			base_delay *= pow(1.2, encumbrance)

	return base_delay

# ---------------------------------------------------------------------------
# Surprise Attack
# ---------------------------------------------------------------------------

## A hero can surprise-attack only if they meet the weapon's STR requirement.
func can_surprise_attack(hero: Char) -> bool:
	if hero == null:
		return false
	return hero.str_val >= get_str_requirement()

# ---------------------------------------------------------------------------
# Enchantment
# ---------------------------------------------------------------------------

## Apply the enchantment's proc effect, if one is present.
## Returns the (possibly modified) damage value.
func proc_enchantment(attacker: Variant, defender: Variant, damage: int) -> int:
	if enchantment != null:
		return enchantment.proc(self, attacker, defender, damage)
	return damage

## Set an enchantment on this weapon.
func enchant(ench: WeaponEnchantment) -> Weapon:
	enchantment = ench
	return self

## Remove the current enchantment.
func clear_enchantment() -> void:
	enchantment = null

# ---------------------------------------------------------------------------
# Equipment Overrides
# ---------------------------------------------------------------------------

func on_equip(hero: Char) -> void:
	super.on_equip(hero)
	if hero == null:
		return
	# Cursed weapons cannot be unequipped
	if cursed and not cursed_known:
		cursed_known = true
		if MessageLog:
			MessageLog.add_negative("The %s latches onto your hand!" % item_name)

func on_unequip(hero: Char) -> void:
	super.on_unequip(hero)
	# Note: Curse prevention is handled by Belongings.unequip_weapon(), not here.
	# This callback fires only when unequip is actually allowed (e.g. via Remove Curse).

# ---------------------------------------------------------------------------
# Upgrade
# ---------------------------------------------------------------------------

## Upgrade weapon with enchantment loss logic matching SPD.
func upgrade_weapon(inscribe_enchant: bool = false) -> Item:
	if inscribe_enchant:
		if enchantment == null:
			enchant(WeaponEnchantment.random())
	elif enchantment != null:
		# Chance to lose hardened buff: 10/20/40/80/100% at +6/7/8/9/10
		if enchant_hardened:
			if level >= 6 and randf() * 10.0 < pow(2.0, level - 6):
				enchant_hardened = false
		# Normal enchantments: 10/20/40/80/100% loss at +4/5/6/7/8
		elif level >= 4 and randf() * 10.0 < pow(2.0, level - 4):
			clear_enchantment()
	cursed = false
	super.upgrade()
	return self

func upgrade() -> Item:
	return upgrade_weapon(false)

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
	if enchantment != null and identified:
		base_name += " {%s}" % enchantment.enchant_name
	return base_name

func get_stats_text() -> String:
	var dmg: Array[int] = get_damage_range()
	return "Damage: %d-%d  STR req: %d" % [dmg[0], dmg[1], str_requirement]

# ---------------------------------------------------------------------------
# Value
# ---------------------------------------------------------------------------

## SPD formula: 20*tier, *1.5 if enchanted, /2 if cursed, *(level+1) if known.
func value() -> int:
	var price: int = 20 * tier
	if enchantment != null:
		price = int(float(price) * 1.5)
	if cursed_known and cursed:
		@warning_ignore("integer_division")
		price /= 2
	if level_known and level > 0:
		price *= (level + 1)
	return maxi(1, price)

# ---------------------------------------------------------------------------
# Random Generation
# ---------------------------------------------------------------------------

## Apply random upgrade, curse, and enchantment chances to this weapon.
## Called by Generator when spawning loot. Matches original Weapon.random().
func random() -> Weapon:
	var n: int = 0
	if randi() % 4 == 0:
		n += 1
		if randi() % 5 == 0:
			n += 1
	level = n

	var effect_roll: float = randf()
	if effect_roll < 0.3:
		cursed = true
	elif effect_roll >= 0.85:
		enchant(WeaponEnchantment.random())

	return self

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["tier"] = tier
	data["augment"] = augment
	data["delay_factor"] = delay_factor
	data["enchant_hardened"] = enchant_hardened
	data["curse_infusion_bonus"] = curse_infusion_bonus
	data["mastery_potion_bonus"] = mastery_potion_bonus
	data["_uses_left_to_id"] = _uses_left_to_id
	data["_available_uses_to_id"] = _available_uses_to_id
	if enchantment != null:
		data["enchantment"] = enchantment.serialize()
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	tier = data.get("tier", 1)
	augment = data.get("augment", Augment.NONE) as Augment
	delay_factor = data.get("delay_factor", 1.0)
	enchant_hardened = data.get("enchant_hardened", false)
	curse_infusion_bonus = data.get("curse_infusion_bonus", false)
	mastery_potion_bonus = data.get("mastery_potion_bonus", false)
	_uses_left_to_id = data.get("_uses_left_to_id", 20.0)
	_available_uses_to_id = data.get("_available_uses_to_id", 10.0)
	if data.has("enchantment"):
		var ench_data: Dictionary = data["enchantment"]
		var ench_id: String = ench_data.get("enchant_id", "")
		if ench_id != "":
			enchantment = WeaponEnchantment.create(ench_id)
			if enchantment != null:
				enchantment.deserialize(ench_data)
