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
			w.icon_color = Color(0.6, 0.6, 0.6)  # grey
		"cudgel":
			w.item_name = "Cudgel"
			w.description = "A crude but heavy wooden club. Simple and brutally effective."
			w.tier = 1
			w.icon_color = Color(0.55, 0.35, 0.15)  # brown
		"gloves":
			w.item_name = "Gloves"
			w.description = "Reinforced leather gloves for hand-to-hand combat. Quick strikes."
			w.tier = 1
			w.icon_color = Color(0.8, 0.7, 0.5)  # tan
		"rapier":
			w.item_name = "Rapier"
			w.description = "A slender thrusting sword favored by duelists. Elegant and precise."
			w.tier = 1
			w.icon_color = Color(0.75, 0.75, 0.85)  # silver-blue
		"dagger":
			w.item_name = "Dagger"
			w.description = "A small blade ideal for quick, precise strikes from the shadows."
			w.tier = 1
			w.icon_color = Color(0.5, 0.5, 0.55)  # dark grey

		# ===== TIER 2 (str req 12, 2-15 base) =====
		"shortsword":
			w.item_name = "Shortsword"
			w.description = "A reliable one-handed blade. Well-balanced for offense and defense."
			w.tier = 2
			w.icon_color = Color(0.7, 0.7, 0.75)  # light steel
		"hand_axe":
			w.item_name = "Hand Axe"
			w.description = "A small but vicious axe. Its weighted head delivers crushing blows."
			w.tier = 2
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
			w.icon_color = Color(0.45, 0.35, 0.2)  # dark wood
		"dirk":
			w.item_name = "Dirk"
			w.description = "A long dagger with a reinforced blade. Deadly from stealth."
			w.tier = 2
			w.icon_color = Color(0.4, 0.4, 0.45)  # gunmetal

		# ===== TIER 3 (str req 14, 3-25 base) =====
		"sword":
			w.item_name = "Sword"
			w.description = "A standard longsword. The workhorse of any adventurer's arsenal."
			w.tier = 3
			w.icon_color = Color(0.8, 0.8, 0.85)  # bright steel
		"mace":
			w.item_name = "Mace"
			w.description = "A flanged metal head on a sturdy handle. Armor means nothing to it."
			w.tier = 3
			w.icon_color = Color(0.55, 0.55, 0.6)  # iron
		"scimitar":
			w.item_name = "Scimitar"
			w.description = "A curved blade designed for swift, sweeping cuts."
			w.tier = 3
			w.icon_color = Color(0.85, 0.8, 0.6)  # gold-steel
		"round_shield":
			w.item_name = "Round Shield"
			w.description = "An offensive shield with a reinforced boss for bashing."
			w.tier = 3
			w.icon_color = Color(0.6, 0.5, 0.3)  # bronze-brown
		"sai":
			w.item_name = "Sai"
			w.description = "A pronged weapon from the east. Excellent for trapping blades."
			w.tier = 3
			w.icon_color = Color(0.5, 0.5, 0.55)  # grey-steel

		# ===== TIER 4 (str req 16, 4-35 base) =====
		"longsword":
			w.item_name = "Longsword"
			w.description = "A large two-handed blade. Requires strength but deals heavy damage."
			w.tier = 4
			w.icon_color = Color(0.75, 0.75, 0.8)  # polished steel
		"battle_axe":
			w.item_name = "Battle Axe"
			w.description = "A massive double-headed axe that cleaves through anything."
			w.tier = 4
			w.icon_color = Color(0.45, 0.35, 0.25)  # dark bronze
		"flail":
			w.item_name = "Flail"
			w.description = "A spiked ball on a chain. Unpredictable but devastating."
			w.tier = 4
			w.icon_color = Color(0.35, 0.35, 0.4)  # dark iron
		"runic_blade":
			w.item_name = "Runic Blade"
			w.description = "An ancient blade etched with glowing runes. Scales well with upgrades."
			w.tier = 4
			w.icon_color = Color(0.3, 0.5, 0.9)  # runic blue
		"assassins_blade":
			w.item_name = "Assassin's Blade"
			w.description = "A long, wickedly sharp blade designed for lethal surprise attacks."
			w.tier = 4
			w.icon_color = Color(0.2, 0.2, 0.25)  # near-black

		# ===== TIER 5 (str req 18, 5-50 base) =====
		"greatsword":
			w.item_name = "Greatsword"
			w.description = "An enormous two-handed sword. Only the strongest can wield it."
			w.tier = 5
			w.icon_color = Color(0.85, 0.85, 0.9)  # bright steel
		"war_hammer":
			w.item_name = "War Hammer"
			w.description = "A titanic hammer. Each blow lands like a siege weapon."
			w.tier = 5
			w.icon_color = Color(0.5, 0.45, 0.4)  # heavy iron
		"glaive":
			w.item_name = "Glaive"
			w.description = "A long polearm with a heavy blade. Strikes foes two cells away."
			w.tier = 5
			w.reach = 2
			w.icon_color = Color(0.6, 0.55, 0.4)  # aged steel
		"greataxe":
			w.item_name = "Greataxe"
			w.description = "A colossal axe that trades speed for raw destruction."
			w.tier = 5
			w.icon_color = Color(0.4, 0.3, 0.2)  # dark iron
		"greatshield":
			w.item_name = "Greatshield"
			w.description = "A tower shield used as a weapon. Provides unmatched defense."
			w.tier = 5
			w.icon_color = Color(0.65, 0.6, 0.45)  # gold-bronze
		_:
			push_warning("MeleeWeapon.create: unknown id '%s'" % weapon_id)
			w.item_name = weapon_id.capitalize()
			w.tier = 1

	# Set computed str requirement
	w.str_requirement = w.get_str_requirement()
	return w

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
