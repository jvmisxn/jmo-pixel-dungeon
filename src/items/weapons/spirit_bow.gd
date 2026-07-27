class_name SpiritBow
extends Weapon
## The Huntress's unique weapon. A magical bow that scales with hero level rather
## than weapon tier. Cannot be thrown. Fires virtual SpiritArrow projectiles.
## Always tier 1 for upgrade cost purposes but damage scales independently.

## Transient sniper-special state (upstream SpiritBow.sniperSpecial /
## sniperSpecialBonusDamage): set just before a marked special shot resolves,
## cleared after the action's time is spent. Never serialized.
var sniper_special: bool = false
var sniper_special_bonus: float = 0.0
var sniper_special_distance: int = 0

func _init() -> void:
	super._init()
	item_id = "spirit_bow"
	item_name = "Spirit Bow"
	description = "A bow woven from spiritual energy. It grows stronger as its wielder does."
	tier = 1
	unique = true
	icon_color = Color(0.3, 0.8, 0.4)  # spiritual green
	default_action = "shoot"

# ---------------------------------------------------------------------------
# Damage (scales with hero level, not tier)
# ---------------------------------------------------------------------------

## Damage range scales with the wielder's hero level.
## min = 1 + hero_level / 3, max = 6 + hero_level
## Augment still applies.
func get_damage_range_for_level(hero_level: int) -> Array[int]:
	var base_min: int = 1 + int(hero_level / 3.0)
	var base_max: int = 6 + hero_level

	# Upgrade bonus
	base_min += level
	base_max += level * 2

	# Augment scaling
	var dmg_multi: float = _augment_damage_multiplier()
	var final_min: int = maxi(1, int(base_min * dmg_multi))
	var final_max: int = maxi(final_min, int(base_max * dmg_multi))

	return [final_min, final_max]

## Override: uses hero_level=1 as fallback when no hero reference is available.
## Prefer get_damage_range_for_level() when the hero is accessible.
func get_damage_range() -> Array[int]:
	return get_damage_range_for_level(1)

## Upstream SpiritBow.damageRoll: hero-level-scaled roll + excess STR, then
## sniper-special modifiers — x(1 + Shared Upgrades bonus), then per augment:
## NONE x0.667, SPEED x0.5, DAMAGE x min(3, 1.2 * 1.125^(distance-1)).
## (Also fixes the ranged-attack path rolling at hero_level=1: the base
## Weapon.damage_roll ignored the wielder's level entirely.)
func damage_roll(owner: Variant = null) -> int:
	var hero_level: int = 1
	if owner != null and owner.get("hero_level") != null:
		hero_level = int(owner.hero_level)
	var dmg: int = _roll_from_range(get_damage_range_for_level(hero_level), owner)
	if sniper_special:
		dmg = roundi(dmg * (1.0 + sniper_special_bonus))
		match augment:
			Augment.SPEED:
				dmg = roundi(dmg * 0.5)
			Augment.DAMAGE:
				var dist: int = maxi(0, sniper_special_distance - 1)
				dmg = roundi(dmg * minf(3.0, 1.2 * pow(1.125, dist)))
			_:
				dmg = roundi(dmg * 0.667)
	return maxi(0, dmg)

# ---------------------------------------------------------------------------
# Strength Requirement (fixed at 10)
# ---------------------------------------------------------------------------

func get_str_requirement() -> int:
	return 10

# ---------------------------------------------------------------------------
# Speed
# ---------------------------------------------------------------------------

## Bows are slightly slower than melee weapons by default.
## Upstream SpiritBow.baseDelay: sniper-special shots replace the base delay
## per augment — NONE is a free (0-time) shot, SPEED costs 1 turn, DAMAGE 2.
## Port adaptation: SPEED's 3-arrow flurry is not ported; it fires one
## half-damage arrow at normal speed instead.
func speed_factor(_hero: Char) -> float:
	if sniper_special:
		match augment:
			Augment.SPEED:
				return 1.0
			Augment.DAMAGE:
				return 2.0
			_:
				return 0.0
	var base_delay: float = 1.0

	match augment:
		Augment.SPEED:
			base_delay *= SPEED_AUGMENT_DELAY
		Augment.DAMAGE:
			base_delay *= DAMAGE_AUGMENT_DELAY

	# No strength penalty for spirit bow (always meets requirement)
	return base_delay

# ---------------------------------------------------------------------------
# Accuracy
# ---------------------------------------------------------------------------

## Upstream SpiritArrow inherits MissileWeapon's adjacency accuracy split:
## 1.5x at range, 0.5x adjacent (raised by Huntress Point Blank). The bow has
## no STR encumbrance, so the adjacency factor is the whole multiplier.
## Upstream SpiritArrow.accuracyFactor: a DAMAGE-augmented sniper special
## never misses (Float.POSITIVE_INFINITY).
func accuracy_factor(hero: Char = null, target: Char = null) -> float:
	if sniper_special and augment == Augment.DAMAGE:
		return 1000000.0
	return MissileWeapon.adjacent_acc_factor_for(hero, target)

# ---------------------------------------------------------------------------
# Seer Shot (Huntress T3 talent)
# ---------------------------------------------------------------------------

## Upstream `SpiritBow.SpiritArrow.cast`: shooting the bow at a cell with no
## character on it, while Seer Shot is off cooldown, attaches a RevealedArea
## buff (3x3 fog reveal around the shot cell for 5 turns per talent point)
## and a 20-turn SeerShotCooldown.
static func apply_seer_shot(hero: Variant, shot_pos: int) -> void:
	if hero == null or shot_pos < 0:
		return
	if not hero.has_method("get_talent_level") \
			or hero.get_talent_level("huntress_seer_shot") <= 0:
		return
	if hero.has_method("has_buff") and hero.has_buff("SeerShotCooldown"):
		return
	var level: Variant = hero.get("level")
	if level != null and level.has_method("find_char_at") \
			and level.find_char_at(shot_pos) != null:
		return
	var points: int = hero.get_talent_level("huntress_seer_shot")
	var reveal: RevealedArea = RevealedArea.new()
	reveal.reveal_pos = shot_pos
	reveal.reveal_depth = int(GameManager.depth) if GameManager != null else 0
	reveal.set_duration(5.0 * points)
	hero.add_buff(reveal)
	hero.add_buff(SeerShotCooldown.new())

# ---------------------------------------------------------------------------
# Surprise Attack
# ---------------------------------------------------------------------------

## Spirit bow always allows surprise attacks (no STR requirement issue).
func can_surprise_attack(_hero: Char) -> bool:
	return true

# ---------------------------------------------------------------------------
# Spirit Arrow (virtual projectile)
# ---------------------------------------------------------------------------

## Calculate damage for a spirit arrow shot by the given hero.
func spirit_arrow_damage(hero: Char) -> int:
	if hero == null:
		return 1
	var hero_level: int = hero.get("hero_level") if hero.get("hero_level") != null else 1
	var dmg_range: Array[int] = get_damage_range_for_level(hero_level)
	return randi_range(dmg_range[0], dmg_range[1])

## Fire a spirit arrow at a target. Returns the damage dealt.
## In a full implementation this would create a projectile entity.
func shoot(hero: Char, target: Variant) -> int:
	if hero == null or target == null:
		return 0

	var dmg: int = spirit_arrow_damage(hero)

	# Apply enchantment
	if enchantment != null:
		dmg = proc_enchantment(hero, target, dmg)

	# Apply damage to target
	if target.has_method("take_damage"):
		return target.take_damage(dmg, hero)
	return dmg

# ---------------------------------------------------------------------------
# Equipment
# ---------------------------------------------------------------------------

func on_equip(hero: Char) -> void:
	super.on_equip(hero)
	# Spirit bow identifies itself on equip
	identified = true
	cursed_known = true

func is_upgradeable() -> bool:
	return true

# ---------------------------------------------------------------------------
# Value
# ---------------------------------------------------------------------------

func value() -> int:
	# Unique items are not typically sold
	return 0

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["is_spirit_bow"] = true
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
