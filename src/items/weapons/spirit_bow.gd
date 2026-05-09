class_name SpiritBow
extends Weapon
## The Huntress's unique weapon. A magical bow that scales with hero level rather
## than weapon tier. Cannot be thrown. Fires virtual SpiritArrow projectiles.
## Always tier 1 for upgrade cost purposes but damage scales independently.

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

# ---------------------------------------------------------------------------
# Strength Requirement (fixed at 10)
# ---------------------------------------------------------------------------

func get_str_requirement() -> int:
	return 10

# ---------------------------------------------------------------------------
# Speed
# ---------------------------------------------------------------------------

## Bows are slightly slower than melee weapons by default.
func speed_factor(_hero: Char) -> float:
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

## Bows have slightly improved accuracy at range.
func accuracy_factor(_hero: Char = null) -> float:
	return 1.2

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

func deserialize(_data: Dictionary) -> void:
	pass
