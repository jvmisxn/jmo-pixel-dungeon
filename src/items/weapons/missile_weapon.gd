class_name MissileWeapon
extends Weapon
## Thrown/ranged weapons that are stackable and break after a number of uses.
## Created via the static factory method create(weapon_id).

# --- Properties ---
var base_uses: int = 10
var uses_left: int = 10
var sticky: bool = false  # embeds in enemy on hit
var returns: bool = false  # boomerang-type weapons return to thrower
var special_effect: String = ""  # e.g. "slow" for bolas
# Warden Durable Tips: throws survived by the current tipped dart since it was
# last consumed (upstream TippedDart durability /= 1 + talent points).
var durable_tips_uses: int = 0
# Huntress Durable Projectiles: fractional wear accrued by the stack since the
# last weapon was consumed (upstream durabilityPerUse usages *= 1.25 + 0.25*pts).
var durable_wear: float = 0.0

func _init() -> void:
	super._init()
	stackable = true
	default_action = "throw"

# ---------------------------------------------------------------------------
# Stacking
# ---------------------------------------------------------------------------

func is_stackable() -> bool:
	return true

func can_stack_with(other: Variant) -> bool:
	if not super.can_stack_with(other):
		return false
	# Only stack if same upgrade level and cursed state
	if other.get("level") != level:
		return false
	return true

# ---------------------------------------------------------------------------
# Durability
# ---------------------------------------------------------------------------

## Upstream MissileWeapon.durabilityFactor: round(base_uses * 1.2^level).
## At level 0 this equals base_uses; each upgrade adds ~20% more durability.
func durability_factor() -> int:
	return roundi(base_uses * pow(1.2, buffed_lvl()))

## Called after each throw/use. Returns true if the weapon broke.
func use_once() -> bool:
	uses_left -= 1
	if uses_left <= 0:
		return true  # weapon broke
	return false

## Whether this missile weapon is spent (no uses remaining).
func is_broken() -> bool:
	return uses_left <= 0

## Reset durability to the level-scaled maximum.
func reset_uses() -> void:
	uses_left = durability_factor()

## Upgrade: increment level then refresh durability to the new factor.
func upgrade() -> Item:
	super.upgrade()
	reset_uses()
	return self

## Preserve mutable missile durability/combat state when splitting a stack.
func duplicate_item() -> Item:
	var copy_item: Item = super.duplicate_item()
	if not copy_item is MissileWeapon:
		copy_item = MissileWeapon.create(item_id)
		if copy_item == null:
			copy_item = MissileWeapon.new()
	var copy: MissileWeapon = copy_item as MissileWeapon
	copy.deserialize(serialize())
	return copy

# ---------------------------------------------------------------------------
# Throw Behavior
# ---------------------------------------------------------------------------

## Whether this weapon returns to the thrower after hitting.
func does_return() -> bool:
	return returns

## Whether this is a tipped dart (the port's analogue of upstream TippedDart,
## which Warden Durable Tips extends the durability of).
func is_tipped_dart() -> bool:
	return item_id == "curare_dart" or item_id == "paralytic_dart"

## Whether this weapon has a special on-hit effect.
func has_special_effect() -> bool:
	return not special_effect.is_empty()

## Apply special on-hit effect to the target.
func apply_special_effect(target: Variant) -> void:
	if target == null:
		return
	match special_effect:
		"slow":
			if target.has_method("add_buff"):
				var script: GDScript = load("res://src/actors/buffs/cripple.gd") as GDScript
				if script:
					var cripple: Variant = script.new()
					if cripple.has_method("set_duration"):
						# Upstream Bolas.proc: Cripple.DURATION/2 = 5 turns.
						cripple.set_duration(5)
					target.add_buff(cripple)
				if MessageLog:
					MessageLog.add("The bolas entangle the enemy!")
		"poison":
			if target.has_method("add_buff"):
				target.add_buff(Poison.create(4.0))
				if MessageLog:
					MessageLog.add("The dart poisons its target!")
		"paralysis":
			if target.has_method("add_buff"):
				target.add_buff(Paralysis.new())
				if MessageLog:
					MessageLog.add("The dart leaves its target paralyzed!")

# ---------------------------------------------------------------------------
# Per-Item Hit Procs
# ---------------------------------------------------------------------------

## Upstream per-item MissileWeapon subclass proc(attacker, defender, damage)
## overrides (Tomahawk, FishingSpear). Called from the hero ranged path after
## DR/Vulnerable but before shared-enchantment and enchantment procs, matching
## upstream's subclass proc -> super chain. Returns the (possibly modified)
## damage.
func proc_hit(attacker: Variant, defender: Variant, damage: int) -> int:
	match item_id:
		"tomahawk":
			_apply_tomahawk_bleed(attacker, defender)
		"fishing_spear":
			# Upstream FishingSpear.proc: against piranhas the hit deals at
			# least half the target's current HP.
			if defender is Piranha:
				damage = maxi(damage, floori(float(defender.hp) / 2.0))
	return damage

## Upstream Tomahawk.minBleed/maxBleed: 3 + lvl/2 .. 6 + lvl, where lvl is
## buffedLvl() plus the Ring of Sharpshooting damage bonus. Augment multiplier
## is NOT applied here; the proc applies it to the rolled value.
func tomahawk_bleed_range(owner: Variant = null) -> Array[float]:
	var lvl: int = buffed_lvl()
	if owner != null:
		lvl += Ring.sharpshooting_level_bonus(owner)
	return [3.0 + lvl / 2.0, 6.0 + float(lvl)]

## Upstream Tomahawk.proc: Bleeding.set(augment.damageFactor(
## Random.NormalFloat(minBleed, maxBleed))) — level-based, independent of the
## damage dealt and unaffected by armor.
func _apply_tomahawk_bleed(attacker: Variant, defender: Variant) -> void:
	if defender == null or not defender.has_method("add_buff"):
		return
	var bleed_range: Array[float] = tomahawk_bleed_range(attacker)
	# Random.NormalFloat: average of two uniform rolls in [min, max].
	var roll: float = (
		randf_range(bleed_range[0], bleed_range[1])
		+ randf_range(bleed_range[0], bleed_range[1])
	) / 2.0
	var amount: float = _augment_damage_multiplier() * roll
	var bleeding: Bleeding = null
	if defender.has_method("get_buff"):
		bleeding = defender.get_buff("Bleeding") as Bleeding
	if bleeding == null:
		bleeding = Bleeding.new()
		defender.add_buff(bleeding)
	bleeding.set_level(amount)

# ---------------------------------------------------------------------------
# Damage
# ---------------------------------------------------------------------------

## Upstream ThrowingClub/ThrowingHammer.pickupDelay: 0, picked up instantly;
## every other missile pays the standard 1-turn pickup cost.
func pickup_delay() -> float:
	if item_id == "throwing_club" or item_id == "throwing_hammer":
		return 0.0
	return super.pickup_delay()

## Upstream Kunai.damageRoll: 60% toward max instead of min..max on a
## surprise attack.
func surprise_toward_max() -> float:
	if item_id == "kunai":
		return 0.6
	return 0.0

## Upstream MissileWeapon.min/max: min = 2*tier + lvl, max = 5*tier + tier*lvl
## (melee weapons use tier + lvl / 5*(tier+1) + lvl*(tier+1) instead). Items
## with upstream min/max overrides adjust below by id.
func _damage_range_for_level(lvl: int) -> Array[int]:
	var base_min: int = 2 * tier + lvl
	var base_max: int = 5 * tier + tier * lvl
	match item_id:
		"throwing_knife":
			base_max = 6 * tier + (2 * lvl if tier == 1 else tier * lvl)
		"shuriken", "kunai", "throwing_club", "throwing_hammer":
			base_max = 4 * tier + tier * lvl
		"bolas":
			base_min = 2 * (tier - 1)
			base_max = 3 * tier + (tier - 1) * lvl
		"tomahawk":
			base_min = roundi(1.5 * tier) + lvl
			base_max = roundi(4.0 * tier) + (tier - 1) * lvl
		"heavy_boomerang":
			base_max = 4 * tier + (tier - 1) * lvl

	var dmg_multi: float = _augment_damage_multiplier() * damage_multiplier
	var final_min: int = maxi(1, roundi(base_min * dmg_multi))
	var final_max: int = maxi(final_min, roundi(base_max * dmg_multi))
	return [final_min, final_max]

## Upstream MissileWeapon.STRReq: one less STR than a melee weapon of the
## same tier.
func get_str_requirement() -> int:
	return maxi(1, super.get_str_requirement() - 1)

## Missile damage adds the equipped Ring of Sharpshooting's level bonus, matching
## upstream SPD where MissileWeapon.min()/max() use buffedLvl() +
## RingOfSharpshooting.levelDamageBonus(hero). The bonus raises the missile's
## effective level (widening the damage range), NOT a flat post-roll add, and it
## is missile-only — melee weapons never see this bonus.
func damage_roll(owner: Variant = null) -> int:
	var bonus: int = 0
	if owner != null:
		bonus = Ring.sharpshooting_level_bonus(owner)
	if bonus == 0:
		return super.damage_roll(owner)
	return _roll_from_range(_damage_range_for_level(buffed_lvl() + bonus), owner)

# ---------------------------------------------------------------------------
# Accuracy
# ---------------------------------------------------------------------------

## Upstream MissileWeapon.accuracyFactor: base weapon accuracy (STR
## encumbrance) times the adjacency split — 0.5x against adjacent targets,
## 1.5x at range. Huntress Point Blank (T3) raises the adjacent factor to
## 0.75x/1.0x/1.25x.
func accuracy_factor(hero: Char = null, target: Char = null) -> float:
	return super.accuracy_factor(hero, target) * adjacent_acc_factor_for(hero, target)

## Shared with SpiritBow, which mirrors upstream SpiritArrow inheriting this.
static func adjacent_acc_factor_for(owner: Char, target: Char) -> float:
	if owner == null or target == null:
		return 1.0
	var w: int = ConstantsData.WIDTH
	var adjacent: bool = (
		owner.pos != target.pos
		and absi(owner.pos % w - target.pos % w) <= 1
		and absi(owner.pos / w - target.pos / w) <= 1
	)
	if not adjacent:
		return 1.5
	if owner is Hero:
		return 0.5 + 0.25 * (owner as Hero).get_talent_level("huntress_point_blank")
	return 0.5

# ---------------------------------------------------------------------------
# Speed
# ---------------------------------------------------------------------------

## Missile weapons are generally faster to use than melee.
func speed_factor(hero: Char) -> float:
	var base: float = super.speed_factor(hero)
	return base * 0.5  # thrown weapons are quick

# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## All valid missile weapon IDs.
static var ALL_IDS: Array[String] = [
	"dart", "curare_dart", "paralytic_dart",
	"throwing_knife", "throwing_stone", "throwing_spike",
	"fishing_spear", "throwing_club", "shuriken",
	"throwing_spear", "kunai", "bolas",
	"javelin", "tomahawk", "heavy_boomerang", "boomerang",
	"trident", "throwing_hammer", "force_cudgel",
]

## Create a fully configured missile weapon by ID.
static func create(weapon_id: String) -> MissileWeapon:
	var w: MissileWeapon = MissileWeapon.new()
	w.item_id = weapon_id

	match weapon_id:
		# ===== TIER 1 =====
		"dart":
			w.item_name = "Dart"
			w.description = "A light throwing dart. Cheap, accurate, and easy to carry in bundles."
			w.tier = 1
			w.base_uses = 8
			w.icon_color = Color(0.7, 0.7, 0.65)
		"curare_dart":
			w.item_name = "Curare Dart"
			w.description = "A dart tipped with curare. It deals little damage but poisons on hit."
			w.tier = 1
			w.base_uses = 6
			w.special_effect = "poison"
			w.icon_color = Color(0.45, 0.8, 0.35)
		"paralytic_dart":
			w.item_name = "Paralytic Dart"
			w.description = "A dart coated with a numbing agent that can briefly paralyze its victim."
			w.tier = 1
			w.base_uses = 4
			w.special_effect = "paralysis"
			w.icon_color = Color(0.9, 0.85, 0.35)
		"throwing_knife":
			w.item_name = "Throwing Knife"
			w.description = "A small balanced knife designed for throwing. Cheap and disposable."
			w.tier = 1
			w.base_uses = 5
			w.icon_color = Color(0.6, 0.6, 0.65)
		"throwing_stone":
			w.item_name = "Throwing Stone"
			w.description = "A smooth, heavy stone. Primitive but always available."
			w.tier = 1
			w.base_uses = 5
			w.icon_color = Color(0.5, 0.5, 0.5)
		"throwing_spike":
			w.item_name = "Throwing Spike"
			w.description = "A sturdy metal spike, weighted for throwing. Simple and durable."
			w.tier = 1
			w.base_uses = 12
			w.icon_color = Color(0.55, 0.55, 0.6)

		# ===== TIER 2 =====
		"fishing_spear":
			w.item_name = "Fishing Spear"
			w.description = "A short spear with a barbed tip, made for spearing fish."
			w.tier = 2
			w.base_uses = 10
			w.icon_color = Color(0.55, 0.45, 0.35)
		"throwing_club":
			w.item_name = "Throwing Club"
			w.description = "A weighted wooden club that can be hurled short distances."
			w.tier = 2
			w.base_uses = 12
			w.icon_color = Color(0.5, 0.35, 0.15)
		"shuriken":
			w.item_name = "Shuriken"
			w.description = (
					"A razor-sharp throwing star. Cuts deep but wears down "
					+ "quickly. Once every 20 turns, a shuriken can be thrown "
					+ "in an instant, costing no time at all."
				)
			w.tier = 2
			w.base_uses = 5
			w.icon_color = Color(0.7, 0.7, 0.75)

		# ===== TIER 3 =====
		"throwing_spear":
			w.item_name = "Throwing Spear"
			w.description = "A sturdy spear balanced for throwing at distant prey."
			w.tier = 3
			w.base_uses = 10
			w.icon_color = Color(0.6, 0.5, 0.3)
		"kunai":
			w.item_name = "Kunai"
			w.description = "A pointed throwing blade favored by assassins."
			w.tier = 3
			w.base_uses = 8
			w.icon_color = Color(0.35, 0.35, 0.4)
		"bolas":
			w.item_name = "Bolas"
			w.description = "Weighted balls connected by cord. Entangles enemies on hit."
			w.tier = 3
			w.base_uses = 5
			w.special_effect = "slow"
			w.icon_color = Color(0.55, 0.45, 0.3)

		# ===== TIER 4 =====
		"javelin":
			w.item_name = "Javelin"
			w.description = "A long throwing spear. Excellent range and penetration."
			w.tier = 4
			w.base_uses = 10
			w.icon_color = Color(0.6, 0.55, 0.35)
		"tomahawk":
			w.item_name = "Tomahawk"
			w.description = "A throwing axe that tumbles through the air with lethal force."
			w.tier = 4
			w.base_uses = 5
			w.icon_color = Color(0.45, 0.35, 0.2)
		"heavy_boomerang":
			w.item_name = "Heavy Boomerang"
			w.description = "A reinforced boomerang made of dense metal. Hits hard and returns."
			w.tier = 4
			w.base_uses = 5
			w.returns = true
			w.icon_color = Color(0.5, 0.45, 0.35)
		"boomerang":
			# Port adaptation kept for old saves; no longer in the random
			# drop decks (upstream has no plain boomerang).
			w.item_name = "Boomerang"
			w.description = "A curved throwing weapon that returns to the wielder after striking."
			w.tier = 3
			w.base_uses = 5
			w.returns = true
			w.icon_color = Color(0.55, 0.5, 0.3)

		# ===== TIER 5 =====
		"trident":
			w.item_name = "Trident"
			w.description = "A heavy three-pronged spear. Powerful at range."
			w.tier = 5
			w.base_uses = 10
			w.icon_color = Color(0.4, 0.6, 0.7)
		"throwing_hammer":
			w.item_name = "Throwing Hammer"
			w.description = "A brutally heavy hammer built to be hurled. Durable and devastating."
			w.tier = 5
			w.base_uses = 12
			w.icon_color = Color(0.45, 0.45, 0.5)
		"force_cudgel":
			# Roster adaptation filling upstream's ForceCube tier-5 slot.
			w.item_name = "Force Cudgel"
			w.description = "A massive thrown club imbued with kinetic energy. Devastating impact."
			w.tier = 5
			w.base_uses = 5
			w.icon_color = Color(0.6, 0.3, 0.6)
		_:
			push_warning("MissileWeapon.create: unknown id '%s'" % weapon_id)
			w.item_name = weapon_id.capitalize()
			w.tier = 1
			w.base_uses = 10

	w.uses_left = w.base_uses
	w.str_requirement = w.get_str_requirement()
	return w

# ---------------------------------------------------------------------------
# Value
# ---------------------------------------------------------------------------

func value() -> int:
	# Missile weapons are worth less per unit since they're consumable
	return maxi(1, int(super.value() * 0.3)) * quantity

# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

func get_display_name() -> String:
	var display: String = super.get_display_name()
	if quantity > 1:
		display += " x%d" % quantity
	return display

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["base_uses"] = base_uses
	data["uses_left"] = uses_left
	data["sticky"] = sticky
	data["returns"] = returns
	data["special_effect"] = special_effect
	data["durable_tips_uses"] = durable_tips_uses
	data["durable_wear"] = durable_wear
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	base_uses = data.get("base_uses", 10)
	uses_left = data.get("uses_left", base_uses)
	sticky = data.get("sticky", false)
	returns = data.get("returns", false)
	special_effect = data.get("special_effect", "")
	durable_tips_uses = data.get("durable_tips_uses", 0)
	durable_wear = data.get("durable_wear", 0.0)
	# Migrate shurikens saved with the retired 0.8 quick-throw stand-in
	# (replaced by the upstream ShurikenInstantTracker instant first throw).
	if item_id == "shuriken" and is_equal_approx(delay_factor, 0.8):
		delay_factor = 1.0
