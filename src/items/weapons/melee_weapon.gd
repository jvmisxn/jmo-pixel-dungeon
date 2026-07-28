class_name MeleeWeapon
extends Weapon
## Base melee weapon. All melee weapons are created via the static factory method
## create(weapon_id). Each weapon is configured with unique stats, name, description,
## and color. The reach property determines attack range (1 = adjacent, 2 = polearm).

# --- Properties ---
var reach: int = 1

# ---------------------------------------------------------------------------
# Reach (accounts for Projecting enchantment)
# ---------------------------------------------------------------------------

## Effective reach, including enchantment bonus.
func get_reach() -> int:
	var r: int = reach
	if enchantment != null and enchantment.enchant_id == "projecting":
		r += 1
	return r

# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

## All valid melee weapon IDs.
static var ALL_IDS: Array[String] = [
	# Tier 1
	"worn_shortsword", "cudgel", "gloves", "rapier", "dagger",
	# Tier 2
	"shortsword", "hand_axe", "spear", "quarterstaff", "dirk",
	# Tier 3
	"sword", "mace", "scimitar", "round_shield", "sai",
	# Tier 4
	"longsword", "battle_axe", "flail", "runic_blade", "assassins_blade",
	# Tier 5
	"greatsword", "war_hammer", "glaive", "greataxe", "greatshield",
]

## Create a fully configured melee weapon by ID.
static func create(weapon_id: String) -> MeleeWeapon:
	var w: MeleeWeapon = MeleeWeapon.new()
	w.item_id = weapon_id

	match weapon_id:
		# ===== TIER 1 (str req 10, 1-10 base) =====
		"worn_shortsword":
			w.item_name = "Worn Shortsword"
			w.description = "A rusted, chipped blade. Better than nothing, but not by much."
			w.tier = 1
			# Standard: the tier baseline.
			w.icon_color = Color(0.6, 0.6, 0.6)  # grey
		"cudgel":
			w.item_name = "Cudgel"
			w.description = "A crude but heavy wooden club. Simple and brutally effective."
			w.tier = 1
			# Heavy: slower, harder-hitting, needs more strength.
			w.delay_factor = 1.15
			w.damage_multiplier = 1.15
			w.str_req_bonus = 1
			w.icon_color = Color(0.55, 0.35, 0.15)  # brown
		"gloves":
			w.item_name = "Gloves"
			w.description = "Reinforced leather gloves for hand-to-hand combat. Quick strikes."
			w.tier = 1
			# Very fast, low damage: rapid light strikes.
			w.delay_factor = 0.6
			w.damage_multiplier = 0.6
			w.str_req_bonus = -1
			w.icon_color = Color(0.8, 0.7, 0.5)  # tan
		"rapier":
			w.item_name = "Rapier"
			w.description = "A slender thrusting sword favored by duelists. Elegant and precise."
			w.tier = 1
			# Fast and precise: quicker with a small damage trade.
			w.delay_factor = 0.85
			w.damage_multiplier = 0.9
			w.icon_color = Color(0.75, 0.75, 0.85)  # silver-blue
		"dagger":
			w.item_name = "Dagger"
			w.description = "A small blade ideal for quick, precise strikes from the shadows."
			w.tier = 1
			# Light and fast: low strength, low damage, quick.
			w.delay_factor = 0.75
			w.damage_multiplier = 0.75
			w.str_req_bonus = -1
			w.icon_color = Color(0.5, 0.5, 0.55)  # dark grey

		# ===== TIER 2 (str req 12, 2-15 base) =====
		"shortsword":
			w.item_name = "Shortsword"
			w.description = "A reliable one-handed blade. Well-balanced for offense and defense."
			w.tier = 2
			# Standard: the tier baseline.
			w.icon_color = Color(0.7, 0.7, 0.75)  # light steel
		"hand_axe":
			w.item_name = "Hand Axe"
			w.description = "A small but vicious axe. Its weighted head delivers crushing blows."
			w.tier = 2
			# Heavy: slower, harder-hitting, needs more strength.
			w.delay_factor = 1.15
			w.damage_multiplier = 1.15
			w.str_req_bonus = 1
			w.icon_color = Color(0.5, 0.4, 0.3)  # bronze
		"spear":
			w.item_name = "Spear"
			w.description = "A long polearm that can strike enemies two cells away."
			w.tier = 2
			w.reach = 2
			w.icon_color = Color(0.65, 0.55, 0.35)  # wood
		"quarterstaff":
			w.item_name = "Quarterstaff"
			w.description = "A sturdy wooden staff. Defensive and versatile in skilled hands."
			w.tier = 2
			# Defensive/versatile: slightly lower damage.
			w.damage_multiplier = 0.9
			w.icon_color = Color(0.45, 0.35, 0.2)  # dark wood
		"dirk":
			w.item_name = "Dirk"
			w.description = "A long dagger with a reinforced blade. Deadly from stealth."
			w.tier = 2
			# Light and fast: low strength, low damage, quick.
			w.delay_factor = 0.75
			w.damage_multiplier = 0.75
			w.str_req_bonus = -1
			w.icon_color = Color(0.4, 0.4, 0.45)  # gunmetal

		# ===== TIER 3 (str req 14, 3-25 base) =====
		"sword":
			w.item_name = "Sword"
			w.description = "A standard longsword. The workhorse of any adventurer's arsenal."
			w.tier = 3
			# Standard: the tier baseline.
			w.icon_color = Color(0.8, 0.8, 0.85)  # bright steel
		"mace":
			w.item_name = "Mace"
			w.description = "A flanged metal head on a sturdy handle. Armor means nothing to it."
			w.tier = 3
			# Heavy: slow but crushing, needs more strength.
			w.delay_factor = 1.2
			w.damage_multiplier = 1.2
			w.str_req_bonus = 1
			w.icon_color = Color(0.55, 0.55, 0.6)  # iron
		"scimitar":
			w.item_name = "Scimitar"
			w.description = "A curved blade designed for swift, sweeping cuts."
			w.tier = 3
			# Fast sweeping cuts: quicker with a small damage trade.
			w.delay_factor = 0.85
			w.damage_multiplier = 0.9
			w.icon_color = Color(0.85, 0.8, 0.6)  # gold-steel
		"round_shield":
			w.item_name = "Round Shield"
			w.description = "An offensive shield with a reinforced boss for bashing."
			w.tier = 3
			# Defensive: a touch slower, needs more strength.
			w.delay_factor = 1.1
			w.str_req_bonus = 1
			w.icon_color = Color(0.6, 0.5, 0.3)  # bronze-brown
		"sai":
			w.item_name = "Sai"
			w.description = "A pronged weapon from the east. Excellent for trapping blades."
			w.tier = 3
			# Light and fast: low strength, low damage, quick.
			w.delay_factor = 0.7
			w.damage_multiplier = 0.7
			w.str_req_bonus = -1
			w.icon_color = Color(0.5, 0.5, 0.55)  # grey-steel

		# ===== TIER 4 (str req 16, 4-35 base) =====
		"longsword":
			w.item_name = "Longsword"
			w.description = "A large two-handed blade. Requires strength but deals heavy damage."
			w.tier = 4
			# Standard: the tier baseline.
			w.icon_color = Color(0.75, 0.75, 0.8)  # polished steel
		"battle_axe":
			w.item_name = "Battle Axe"
			w.description = "A massive double-headed axe that cleaves through anything."
			w.tier = 4
			# Heavy: slow, cleaving, needs more strength.
			w.delay_factor = 1.25
			w.damage_multiplier = 1.25
			w.str_req_bonus = 1
			w.icon_color = Color(0.45, 0.35, 0.25)  # dark bronze
		"flail":
			w.item_name = "Flail"
			w.description = "A spiked ball on a chain. Unpredictable but devastating."
			w.tier = 4
			# Unwieldy: slower with a modest damage boost.
			w.delay_factor = 1.15
			w.damage_multiplier = 1.1
			w.icon_color = Color(0.35, 0.35, 0.4)  # dark iron
		"runic_blade":
			w.item_name = "Runic Blade"
			w.description = "An ancient blade etched with glowing runes. Scales well with upgrades."
			w.tier = 4
			# Standard: scales with upgrades, no base trade-off.
			w.icon_color = Color(0.3, 0.5, 0.9)  # runic blue
		"assassins_blade":
			w.item_name = "Assassin's Blade"
			w.description = "A long, wickedly sharp blade designed for lethal surprise attacks."
			w.tier = 4
			# Light and fast: built for surprise strikes.
			w.delay_factor = 0.85
			w.damage_multiplier = 0.85
			w.str_req_bonus = -1
			w.icon_color = Color(0.2, 0.2, 0.25)  # near-black

		# ===== TIER 5 (str req 18, 5-50 base) =====
		"greatsword":
			w.item_name = "Greatsword"
			w.description = "An enormous two-handed sword. Only the strongest can wield it."
			w.tier = 5
			# Standard: the tier baseline.
			w.icon_color = Color(0.85, 0.85, 0.9)  # bright steel
		"war_hammer":
			w.item_name = "War Hammer"
			w.description = "A titanic hammer. Each blow lands like a siege weapon."
			w.tier = 5
			# Heaviest: very slow, devastating, needs the most strength.
			w.delay_factor = 1.4
			w.damage_multiplier = 1.4
			w.str_req_bonus = 1
			w.icon_color = Color(0.5, 0.45, 0.4)  # heavy iron
		"glaive":
			w.item_name = "Glaive"
			w.description = "A long polearm with a heavy blade. Strikes foes two cells away."
			w.tier = 5
			# Reach polearm: slightly slower, slightly harder.
			w.delay_factor = 1.1
			w.damage_multiplier = 1.05
			w.reach = 2
			w.icon_color = Color(0.6, 0.55, 0.4)  # aged steel
		"greataxe":
			w.item_name = "Greataxe"
			w.description = "A colossal axe that trades speed for raw destruction."
			w.tier = 5
			# Heavy: trades speed for raw destruction.
			w.delay_factor = 1.3
			w.damage_multiplier = 1.3
			w.str_req_bonus = 1
			w.icon_color = Color(0.4, 0.3, 0.2)  # dark iron
		"greatshield":
			w.item_name = "Greatshield"
			w.description = "A tower shield used as a weapon. Provides unmatched defense."
			w.tier = 5
			# Defensive tower shield: slow, needs more strength.
			w.delay_factor = 1.2
			w.str_req_bonus = 1
			w.icon_color = Color(0.65, 0.6, 0.45)  # gold-bronze
		_:
			push_warning("MeleeWeapon.create: unknown id '%s'" % weapon_id)
			w.item_name = weapon_id.capitalize()
			w.tier = 1

	# Set computed str requirement
	w.str_requirement = w.get_str_requirement()
	return w

# ---------------------------------------------------------------------------
# Duelist weapon abilities
# Original: MeleeWeapon AC_ABILITY plumbing + per-weapon duelistAbility
# overrides. Ported per ability family; weapons without an entry have no
# ability yet.
# ---------------------------------------------------------------------------

## Sword-family Cleave flat damage boost before level scaling (upstream
## WornShortsword 3+lvl, Shortsword 4+lvl, Sword 5+lvl, Longsword 6+lvl,
## Greatsword 7+lvl; boost is dmgBoost passed to Sword.cleaveAbility).
const CLEAVE_BASE_BOOST: Dictionary = {
	"worn_shortsword": 3, "shortsword": 4, "sword": 5,
	"longsword": 6, "greatsword": 7,
}

## Blunt/axe-family Heavy Blow flat damage boost before level scaling
## (upstream Cudgel 3, HandAxe 4, Mace 5, BattleAxe 5, WarHammer 6, each
## +1.5*lvl rounded; boost is dmgBoost passed to Mace.heavyBlowAbility).
## Greataxe has its own distinct ability upstream and is not in this family.
const HEAVY_BLOW_BASE_BOOST: Dictionary = {
	"cudgel": 3, "hand_axe": 4, "mace": 5,
	"battle_axe": 5, "war_hammer": 6,
}

## Dagger-family Sneak blink range (upstream Dagger.sneakAbility maxDist:
## Dagger 5, Dirk 4, AssassinsBlade 3).
const SNEAK_MAX_DIST: Dictionary = {
	"dagger": 5, "dirk": 4, "assassins_blade": 3,
}

## Polearm-family Spike flat damage boost [base, per-level factor] (upstream
## Spear.spikeAbility dmgBoost: Spear 9+round(2*lvl), Glaive 12+round(2.5*lvl)).
const SPIKE_BOOST: Dictionary = {
	"spear": [9, 2.0], "glaive": [12, 2.5],
}

## Lunge flat damage boost [base, per-level factor] (upstream
## Rapier.duelistAbility dmgBoost: 5 + round(1.5*lvl)).
const LUNGE_BOOST: Dictionary = {
	"rapier": [5, 1.5],
}

## Shield-family Guard stance base duration in turns (upstream
## RoundShield.duelistAbility 5+buffedLvl, Greatshield 3+buffedLvl).
const GUARD_DURATION: Dictionary = {
	"round_shield": 5, "greatshield": 3,
}

func has_duelist_ability() -> bool:
	return ability_kind() != ""

## Which ported ability family this weapon belongs to ("" = none yet).
func ability_kind() -> String:
	if CLEAVE_BASE_BOOST.has(item_id):
		return "cleave"
	if HEAVY_BLOW_BASE_BOOST.has(item_id):
		return "heavy_blow"
	if SNEAK_MAX_DIST.has(item_id):
		return "sneak"
	if SPIKE_BOOST.has(item_id):
		return "spike"
	if LUNGE_BOOST.has(item_id):
		return "lunge"
	if GUARD_DURATION.has(item_id):
		return "guard"
	return ""

func ability_name() -> String:
	match ability_kind():
		"cleave":
			return "Cleave"
		"heavy_blow":
			return "Heavy Blow"
		"sneak":
			return "Sneak"
		"spike":
			return "Spike"
		"lunge":
			return "Lunge"
		"guard":
			return "Guard"
	return ""

## Targeting range for the ability prompt: sneak blinks up to its family
## range; strike abilities target within weapon reach.
func ability_target_range() -> int:
	if ability_kind() == "sneak":
		return int(SNEAK_MAX_DIST.get(item_id, 0))
	if ability_kind() == "lunge":
		return get_reach() + 1
	return get_reach()

## Sneak invisibility duration (upstream Dagger.duelistAbility 2+buffedLvl;
## the ability is instant, so the buff itself is applied one turn shorter).
func sneak_invis_turns() -> int:
	return 2 + maxi(0, level)

## Guard stance duration (upstream RoundShield 5+buffedLvl, Greatshield
## 3+buffedLvl turns of GuardTracker).
func guard_duration() -> int:
	return int(GUARD_DURATION.get(item_id, 0)) + maxi(0, level)

## Charge cost (upstream baseChargeUse): cleave is free while the
## CleaveTracker window from an ability kill is open.
func ability_charge_use(hero: Variant) -> float:
	if CLEAVE_BASE_BOOST.has(item_id) and hero != null \
			and hero.has_method("has_buff") and hero.has_buff("CleaveTracker"):
		return 0.0
	return 1.0

## Flat ability damage bonus (cleave dmgBoost = family base + weapon level;
## heavy blow dmgBoost = family base + round(1.5 * weapon level)).
func ability_damage_boost() -> int:
	match ability_kind():
		"cleave":
			return int(CLEAVE_BASE_BOOST.get(item_id, 0)) + maxi(0, level)
		"heavy_blow":
			return int(HEAVY_BLOW_BASE_BOOST.get(item_id, 0)) \
					+ int(roundf(1.5 * float(maxi(0, level))))
		"spike":
			var spike: Array = SPIKE_BOOST.get(item_id, [0, 0.0])
			return int(spike[0]) \
					+ int(roundf(float(spike[1]) * float(maxi(0, level))))
		"lunge":
			var lunge: Array = LUNGE_BOOST.get(item_id, [0, 0.0])
			return int(lunge[0]) \
					+ int(roundf(float(lunge[1]) * float(maxi(0, level))))
	return 0

## Upstream MeleeWeapon.beforeAbilityUsed: spend charges from the charger
## pool, then the Aggressive Barrier talent shields 1+2*points when the
## ability is used at or below half HP.
func before_ability_used(hero: Variant, charge_use: float) -> void:
	if hero == null or not hero.has_method("get_buff"):
		return
	var charger: Variant = hero.get_buff("WeaponCharger")
	if charger is WeaponCharger:
		charger.partial_charge -= charge_use
		while charger.partial_charge < 0.0 and charger.charges > 0:
			charger.charges -= 1
			charger.partial_charge += 1.0
	var barrier_points: int = 0
	if hero.has_method("get_talent_level"):
		barrier_points = hero.get_talent_level("duelist_aggressive_barrier")
	if barrier_points > 0 and hero.hp * 2 <= hero.hp_max:
		var barrier: Barrier = hero.add_buff(Barrier.new()) as Barrier
		if barrier != null:
			barrier.set_shield(maxi(barrier.get_shielding(), 1 + 2 * barrier_points))

# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------


## Get the imbued wand (Mage's Staff only). Returns null for non-staff weapons.
func get_imbued_wand() -> Variant:
	return null

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	data["reach"] = reach
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	reach = data.get("reach", 1)
